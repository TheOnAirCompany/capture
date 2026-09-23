import AVFoundation
import CoreImage
import UniformTypeIdentifiers

/// Owns the capture session that streams the iPhone screen.
///
/// Frames are fanned out to every preview on screen, and the latest one is kept
/// so a preview can show an image right away and screenshots can be saved.
nonisolated final class PreviewSession: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()

    /// Called on the main thread when the size of the iPhone screen changes.
    var onScreenSizeChange: (@MainActor (CGSize) -> Void)?

    private let queue = DispatchQueue(label: "com.theonaircompany.capture.session")
    private let outputQueue = DispatchQueue(label: "com.theonaircompany.capture.frames")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let imageContext = CIContext()

    // Guarded by `lock`: touched from the main thread and the capture queues.
    private let lock = NSLock()
    private var displays: [ObjectIdentifier: AVSampleBufferDisplayLayer] = [:]
    private var latestFrame: CMSampleBuffer?
    private var screenSize: CGSize = .zero
    private var recorder: MovieRecorder?
    private var audioFormat: CMAudioFormatDescription?

    override init() {
        super.init()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        audioOutput.setSampleBufferDelegate(self, queue: outputQueue)
    }

    func start(with device: AVCaptureDevice) {
        nonisolated(unsafe) let device = device
        queue.async { [self] in
            session.beginConfiguration()
            session.inputs.forEach(session.removeInput)
            if let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
                session.addInput(input)
            }
            for output in [videoOutput, audioOutput] as [AVCaptureOutput]
            where !session.outputs.contains(output) && session.canAddOutput(output) {
                session.addOutput(output)
            }
            session.commitConfiguration()
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            session.stopRunning()
            session.beginConfiguration()
            session.inputs.forEach(session.removeInput)
            session.commitConfiguration()
            lock.withLock { latestFrame = nil }
        }
    }

    // MARK: Previews

    func addDisplay(_ layer: AVSampleBufferDisplayLayer) {
        let latest = lock.withLock {
            displays[ObjectIdentifier(layer)] = layer
            return latestFrame
        }
        if let latest { Self.enqueue(latest, on: layer) }
    }

    func removeDisplay(_ layer: AVSampleBufferDisplayLayer) {
        _ = lock.withLock { displays.removeValue(forKey: ObjectIdentifier(layer)) }
    }

    private static func enqueue(_ frame: CMSampleBuffer, on layer: AVSampleBufferDisplayLayer) {
        let renderer = layer.sampleBufferRenderer
        if renderer.status == .failed { renderer.flush() }
        renderer.enqueue(frame)
    }

    // MARK: Screenshots

    /// Writes the latest frame, at the native resolution of the iPhone times `scale`.
    func writeScreenshot(to url: URL, format: ExportFormat, scale: Double) throws {
        guard let frame = lock.withLock({ latestFrame }),
              let pixelBuffer = CMSampleBufferGetImageBuffer(frame) else {
            throw CaptureError.noFrame
        }
        var image = CIImage(cvPixelBuffer: pixelBuffer)
        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        if scale != 1 {
            image = image.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scale])
        }
        guard let cgImage = imageContext.createCGImage(image, from: image.extent.integral, format: .RGBA8, colorSpace: colorSpace),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, format.contentType.identifier as CFString, 1, nil) else {
            throw CaptureError.writeFailed
        }
        let options: [CFString: Any] = format == .png ? [:] : [kCGImageDestinationLossyCompressionQuality: 0.95]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CaptureError.writeFailed }
    }

    // MARK: Recordings

    /// Records the screen and sound of the iPhone to a QuickTime movie.
    func startRecording(to url: URL, recordsSound: Bool) throws {
        try lock.withLock {
            recorder = try MovieRecorder(url: url, audioFormat: recordsSound ? audioFormat : nil, queue: outputQueue)
        }
    }

    func stopRecording(completion: @escaping @Sendable (Error?) -> Void) {
        guard let recorder = lock.withLock({ () -> MovieRecorder? in
            defer { self.recorder = nil }
            return self.recorder
        }) else {
            completion(nil)
            return
        }
        recorder.finish(completion: completion)
    }
}

nonisolated extension PreviewSession: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output === audioOutput {
            let recorder = lock.withLock {
                audioFormat = CMSampleBufferGetFormatDescription(sampleBuffer)
                return self.recorder
            }
            recorder?.appendAudio(sampleBuffer)
            return
        }

        // Live frames: show them as soon as they arrive instead of scheduling them.
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true),
           CFArrayGetCount(attachments) > 0 {
            let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(
                dictionary,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }

        let size = CMSampleBufferGetFormatDescription(sampleBuffer).map { format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format)
            return CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
        } ?? .zero

        let (targets, sizeChanged, recorder) = lock.withLock {
            latestFrame = sampleBuffer
            let changed = size != .zero && size != screenSize
            if changed { screenSize = size }
            return (Array(displays.values), changed, self.recorder)
        }
        for layer in targets { Self.enqueue(sampleBuffer, on: layer) }
        recorder?.appendVideo(sampleBuffer)

        if sizeChanged {
            DispatchQueue.main.async { [self] in
                MainActor.assumeIsolated { onScreenSizeChange?(size) }
            }
        }
    }
}

enum CaptureError: LocalizedError {
    case noFrame, writeFailed

    var errorDescription: String? {
        switch self {
        case .noFrame: String(localized: "No image has been received from the iPhone yet.")
        case .writeFailed: String(localized: "The file could not be written.")
        }
    }
}
