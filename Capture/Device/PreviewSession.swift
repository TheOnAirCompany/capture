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
    private let movieOutput = AVCaptureMovieFileOutput()
    private let imageContext = CIContext()

    // Guarded by `lock`: touched from the main thread and the capture queues.
    private let lock = NSLock()
    private var displays: [ObjectIdentifier: AVSampleBufferDisplayLayer] = [:]
    private var latestFrame: CMSampleBuffer?
    private var screenSize: CGSize = .zero
    private var recordingCompletion: (@Sendable (Error?) -> Void)?

    override init() {
        super.init()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
    }

    func start(with device: AVCaptureDevice) {
        nonisolated(unsafe) let device = device
        queue.async { [self] in
            session.beginConfiguration()
            session.inputs.forEach(session.removeInput)
            if let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
                session.addInput(input)
            }
            for output in [videoOutput, movieOutput] as [AVCaptureOutput]
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

    /// Writes the latest frame as a PNG at the native resolution of the iPhone.
    func writeScreenshot(to url: URL) throws {
        guard let frame = lock.withLock({ latestFrame }),
              let pixelBuffer = CMSampleBufferGetImageBuffer(frame) else {
            throw CaptureError.noFrame
        }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let cgImage = imageContext.createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: colorSpace),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CaptureError.writeFailed
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { throw CaptureError.writeFailed }
    }

    // MARK: Recordings

    /// Records the screen and sound of the iPhone to a QuickTime movie.
    func startRecording(to url: URL, completion: @escaping @Sendable (Error?) -> Void) {
        queue.async { [self] in
            lock.withLock { recordingCompletion = completion }
            movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopRecording() {
        queue.async { [self] in movieOutput.stopRecording() }
    }
}

nonisolated extension PreviewSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
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

        var size = CGSize.zero
        if let format = CMSampleBufferGetFormatDescription(sampleBuffer) {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format)
            size = CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
        }

        let (targets, sizeChanged) = lock.withLock {
            latestFrame = sampleBuffer
            let changed = size != .zero && size != screenSize
            if changed { screenSize = size }
            return (Array(displays.values), changed)
        }
        for layer in targets { Self.enqueue(sampleBuffer, on: layer) }

        if sizeChanged {
            DispatchQueue.main.async { [self] in
                MainActor.assumeIsolated { onScreenSizeChange?(size) }
            }
        }
    }
}

nonisolated extension PreviewSession: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        // A recording stopped on purpose can still report an error flagged as successful.
        let succeeded = (error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? (error == nil)
        let completion = lock.withLock {
            defer { recordingCompletion = nil }
            return recordingCompletion
        }
        completion?(succeeded ? nil : error)
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
