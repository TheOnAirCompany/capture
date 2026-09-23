import AVFoundation
import CoreImage

/// Writes the iPhone video and sound to a QuickTime movie.
///
/// A movie file output can't share the iPhone stream with the video data output
/// that feeds the preview, so recordings are written from the same frames instead.
nonisolated final class MovieRecorder: @unchecked Sendable {
    private let url: URL
    private let writer: AVAssetWriter
    private let audioFormat: CMAudioFormatDescription?
    private var videoInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var videoSize = CGSize.zero
    private let imageContext = CIContext()
    private var audioInput: AVAssetWriterInput?
    private var hasStarted = false
    private var isFinishing = false

    // Called only from the capture output queue, except `finish`, which hops onto it.
    private let queue: DispatchQueue

    /// `audioFormat` describes the iPhone sound, when it has been received already.
    init(url: URL, audioFormat: CMAudioFormatDescription?, queue: DispatchQueue) throws {
        self.url = url
        self.audioFormat = audioFormat
        self.queue = queue
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    }

    func appendVideo(_ sampleBuffer: CMSampleBuffer) {
        guard !isFinishing else { return }
        if !hasStarted {
            guard start(with: sampleBuffer) else { return }
        }
        guard let videoInput, videoInput.isReadyForMoreMediaData, let adaptor,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        if size == videoSize {
            adaptor.append(pixelBuffer, withPresentationTime: time)
        } else if let fitted = fitted(pixelBuffer, pool: adaptor.pixelBufferPool) {
            // The iPhone was turned during the recording: keep the movie size, add black bars.
            adaptor.append(fitted, withPresentationTime: time)
        }
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        guard hasStarted, !isFinishing, let audioInput, audioInput.isReadyForMoreMediaData else { return }
        audioInput.append(sampleBuffer)
    }

    func finish(completion: @escaping @Sendable (Error?) -> Void) {
        queue.async { [self] in
            isFinishing = true
            guard hasStarted, writer.status == .writing else {
                completion(writer.error ?? CaptureError.writeFailed)
                return
            }
            videoInput?.markAsFinished()
            audioInput?.markAsFinished()
            writer.finishWriting { [self] in
                completion(writer.status == .completed ? nil : writer.error)
            }
        }
    }

    /// The first video frame gives the size of the movie and its start time.
    private func start(with sampleBuffer: CMSampleBuffer) -> Bool {
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer) else { return false }
        let dimensions = CMVideoFormatDescriptionGetDimensions(format)

        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(dimensions.width),
            AVVideoHeightKey: Int(dimensions.height),
        ])
        video.expectsMediaDataInRealTime = true

        guard writer.canAdd(video) else { return false }
        writer.add(video)
        videoInput = video
        videoSize = CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(dimensions.width),
            kCVPixelBufferHeightKey as String: Int(dimensions.height),
        ])

        if let audio = makeAudioInput(), writer.canAdd(audio) {
            writer.add(audio)
            audioInput = audio
        }

        guard writer.startWriting() else { return false }
        writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        hasStarted = true
        return true
    }

    /// Scales a frame of another size to fit the movie, centered on black.
    private func fitted(_ pixelBuffer: CVPixelBuffer, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        guard let pool else { return nil }
        var output: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &output)
        guard let output else { return nil }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let scale = min(videoSize.width / image.extent.width, videoSize.height / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let centered = scaled.transformed(by: CGAffineTransform(
            translationX: (videoSize.width - scaled.extent.width) / 2,
            y: (videoSize.height - scaled.extent.height) / 2
        ))
        let background = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: videoSize))
        imageContext.render(centered.composited(over: background), to: output)
        return output
    }

    /// AAC with the sample rate and channel count of the iPhone sound.
    private func makeAudioInput() -> AVAssetWriterInput? {
        guard let audioFormat,
              let description = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormat)?.pointee else {
            return nil
        }
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: description.mSampleRate,
            AVNumberOfChannelsKey: min(Int(description.mChannelsPerFrame), 2),
            AVEncoderBitRateKey: 192_000,
        ], sourceFormatHint: audioFormat)
        input.expectsMediaDataInRealTime = true
        return input
    }
}
