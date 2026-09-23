import AVFoundation

/// Writes the iPhone video and sound to a QuickTime movie.
///
/// A movie file output can't share the iPhone stream with the video data output
/// that feeds the preview, so recordings are written from the same frames instead.
nonisolated final class MovieRecorder: @unchecked Sendable {
    private let url: URL
    private let writer: AVAssetWriter
    private let audioFormat: CMAudioFormatDescription?
    private var videoInput: AVAssetWriterInput?
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
        if let videoInput, videoInput.isReadyForMoreMediaData {
            videoInput.append(sampleBuffer)
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

        if let audio = makeAudioInput(), writer.canAdd(audio) {
            writer.add(audio)
            audioInput = audio
        }

        guard writer.startWriting() else { return false }
        writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        hasStarted = true
        return true
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
