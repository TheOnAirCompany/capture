import AVFoundation
import Observation
import SwiftUI

nonisolated enum VideoExportFormat: String, CaseIterable, Identifiable {
    case mp4, mov

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .mp4: "MP4 (Recommended)"
        case .mov: "MOV (HEVC)"
        }
    }

    var fileType: AVFileType { self == .mp4 ? .mp4 : .mov }
    var preset: String { self == .mp4 ? AVAssetExportPresetHighestQuality : AVAssetExportPresetHEVCHighestQuality }
    var pathExtension: String { rawValue }
}

enum VideoResolution: String, CaseIterable, Identifiable {
    case source, p1080, p720

    var id: Self { self }

    /// Length of the shorter side, or nil to keep the source size.
    var shortSide: Double? {
        switch self {
        case .source: nil
        case .p1080: 1080
        case .p720: 720
        }
    }
}

enum VideoFrameRate: String, CaseIterable, Identifiable {
    case source, fps60, fps30, fps24

    var id: Self { self }

    var value: Double? {
        switch self {
        case .source: nil
        case .fps60: 60
        case .fps30: 30
        case .fps24: 24
        }
    }
}

/// A video opened in the editor: its edits with undo history, the preview player,
/// and the thumbnails and waveform shown in the timeline.
@Observable
final class VideoProject {
    let item: CaptureItem
    let asset: AVURLAsset
    let player = AVPlayer()

    private(set) var isLoaded = false
    private(set) var sourceDuration = 0.0
    private(set) var sourceSize = CGSize(width: 1179, height: 2556)
    private(set) var sourceFrameRate = 30.0
    private(set) var hasAudio = false
    private(set) var posterFrame: CGImage?
    /// One thumbnail per second of source video.
    private(set) var thumbnails: [Int: CGImage] = [:]
    /// Audio peaks, `waveformRate` values per second of source video.
    private(set) var waveform: [Float] = []
    nonisolated static let waveformRate = 20.0

    private(set) var edits = VideoEdits(duration: 0)
    var selectedSegmentID: UUID?
    private(set) var currentTime = 0.0
    private(set) var isPlaying = false

    private(set) var exportProgress: Double?

    @ObservationIgnored private var undoStack: [VideoEdits] = []
    @ObservationIgnored private var redoStack: [VideoEdits] = []
    @ObservationIgnored private var lastCoalescedChange = Date.distantPast
    @ObservationIgnored private var timeObserver: Any?

    init(item: CaptureItem) {
        self.item = item
        asset = AVURLAsset(url: item.url)
    }

    // MARK: Loading

    func load() async {
        guard !isLoaded else { return }
        do {
            let duration = try await asset.load(.duration).seconds
            if let track = try await asset.loadTracks(withMediaType: .video).first {
                let (naturalSize, transform, rate) = try await track.load(.naturalSize, .preferredTransform, .nominalFrameRate)
                sourceSize = CGRect(origin: .zero, size: naturalSize).applying(transform).size
                sourceFrameRate = rate > 0 ? Double(rate) : 30
            }
            hasAudio = !(try await asset.loadTracks(withMediaType: .audio)).isEmpty
            sourceDuration = duration
            edits = VideoEdits(duration: duration)
            isLoaded = true
        } catch {
            return
        }

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
                self.isPlaying = self.player.rate != 0
            }
        }

        let asset = asset, duration = sourceDuration
        Task {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 240, height: 240)
            posterFrame = try? await generator.image(at: .zero).image
            let times = stride(from: 0.0, to: max(duration, 0.1), by: 1).map { CMTime(seconds: $0, preferredTimescale: 600) }
            for await result in generator.images(for: times) {
                if let image = try? result.image {
                    thumbnails[Int(result.requestedTime.seconds.rounded())] = image
                }
            }
        }
        if hasAudio {
            waveform = await Task.detached(priority: .utility) { await Self.readWaveform(of: asset) }.value
        }
    }

    func tearDown() {
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
    }

    // MARK: Edits and history

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var duration: Double { edits.duration }

    /// Applies a change that can be undone. Continuous changes (sliders, trimming)
    /// pass `coalescing` so a drag is undone in one step.
    func apply(coalescing: Bool = false, _ change: (inout VideoEdits) -> Void) {
        var next = edits
        change(&next)
        guard next != edits else { return }
        let now = Date.now
        if !coalescing || now.timeIntervalSince(lastCoalescedChange) > 0.8 {
            undoStack.append(edits)
            redoStack.removeAll()
        }
        lastCoalescedChange = coalescing ? now : .distantPast
        edits = next
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(edits)
        edits = previous
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(edits)
        edits = next
    }

    func reset() {
        apply { $0 = VideoEdits(duration: sourceDuration) }
        selectedSegmentID = nil
    }

    func splitAtPlayhead() {
        apply { $0.split(at: currentTime) }
    }

    func deleteSelectedSegment() {
        guard let id = selectedSegmentID, edits.segments.count > 1 else { return }
        apply { $0.segments.removeAll { $0.id == id } }
        selectedSegmentID = nil
    }

    func rotate() {
        apply { $0.rotation = ($0.rotation + 1) % 4 }
    }

    /// Moves the start or end of a segment, in source time, within the source video.
    func trim(_ id: UUID, start: Double? = nil, end: Double? = nil) {
        apply(coalescing: true) { edits in
            guard let index = edits.segments.firstIndex(where: { $0.id == id }) else { return }
            var segment = edits.segments[index]
            if let start { segment.start = min(max(0, start), segment.end - 0.2) }
            if let end { segment.end = max(min(sourceDuration, end), segment.start + 0.2) }
            edits.segments[index] = segment
        }
    }

    // MARK: Playback

    func togglePlayback() {
        if player.rate != 0 {
            player.pause()
        } else {
            if currentTime >= duration - 0.05 { seek(to: 0) }
            player.play()
        }
    }

    func seek(to time: Double) {
        let clamped = min(max(0, time), duration)
        currentTime = clamped
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Size of the edited frame, before any device frame or background.
    var editedSize: CGSize {
        VideoRenderer.editedSize(source: sourceSize, edits: edits)
    }

    /// Rebuilds the player item after the edits or the frame style changed.
    func updatePreview(style: CompositionStyle) async {
        guard isLoaded else { return }
        let layers = FrameLayers.make(style: style, videoSize: editedSize)
        let canvas = layers?.canvas ?? editedSize
        // Preview at up to 1600 pixels on the long side, which is plenty on screen.
        let scale = min(1, 1600 / max(canvas.width, canvas.height))
        guard let output = try? await VideoRenderer.build(
            asset: asset, edits: edits, layers: layers, renderScale: scale, frameRate: nil
        ) else { return }

        let wasPlaying = player.rate != 0
        let time = min(currentTime, edits.duration)
        let playerItem = AVPlayerItem(asset: output.composition)
        playerItem.videoComposition = output.videoComposition
        playerItem.audioMix = output.audioMix
        playerItem.audioTimePitchAlgorithm = .spectral
        // Show a paused frame only once it has been composed, not the frame layers alone.
        playerItem.seekingWaitsForVideoCompositionRendering = true
        player.replaceCurrentItem(with: playerItem)

        // Seeking before the item is ready is ignored, which left the screen black while paused.
        for _ in 0..<40 where playerItem.status == .unknown {
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard player.currentItem === playerItem else { return }
        currentTime = time
        await player.seek(to: CMTime(seconds: time, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        if wasPlaying { player.play() }
    }

    // MARK: Export

    func outputSize(style: CompositionStyle, resolution: VideoResolution) -> CGSize {
        let canvas = (style.showsBezel || style.background != .none)
            ? CompositionLayout(image: editedSize, style: style).canvas
            : editedSize
        let scale = Self.scale(for: resolution, canvas: canvas)
        let width = (canvas.width * scale / 2).rounded() * 2
        let height = (canvas.height * scale / 2).rounded() * 2
        return CGSize(width: width, height: height)
    }

    private static func scale(for resolution: VideoResolution, canvas: CGSize) -> CGFloat {
        guard let shortSide = resolution.shortSide else { return 1 }
        return CGFloat(shortSide) / min(canvas.width, canvas.height)
    }

    func export(
        to url: URL,
        style: CompositionStyle,
        format: VideoExportFormat,
        resolution: VideoResolution,
        frameRate: VideoFrameRate,
        includesAudio: Bool,
        optimizesForNetwork: Bool
    ) async throws {
        player.pause()
        exportProgress = 0
        defer { exportProgress = nil }

        let layers = FrameLayers.make(style: style, videoSize: editedSize)
        let canvas = layers?.canvas ?? editedSize
        let scale = Self.scale(for: resolution, canvas: canvas)
        let output = try await VideoRenderer.build(
            asset: asset, edits: edits, layers: layers, renderScale: scale,
            frameRate: frameRate.value, includesAudio: includesAudio
        )
        guard let session = AVAssetExportSession(asset: output.composition, presetName: format.preset) else {
            throw CaptureError.writeFailed
        }
        session.videoComposition = output.videoComposition
        session.audioMix = output.audioMix
        session.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithm.spectral
        session.shouldOptimizeForNetworkUse = optimizesForNetwork

        try? FileManager.default.removeItem(at: url)
        let progressTask = Task { [weak self] in
            for await state in session.states(updateInterval: 0.2) {
                if case .exporting(let progress) = state {
                    self?.exportProgress = progress.fractionCompleted
                }
            }
        }
        defer { progressTask.cancel() }
        try await session.export(to: url, as: format.fileType)
    }

    // MARK: Waveform

    /// Reads the loudest sample of each slice of the audio track.
    nonisolated private static func readWaveform(of asset: AVURLAsset) async -> [Float] {
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first,
              let reader = try? AVAssetReader(asset: asset) else { return [] }

        let sampleRate = 8_000.0
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ])
        guard reader.canAdd(output) else { return [] }
        reader.add(output)
        reader.startReading()

        let samplesPerPeak = Int(sampleRate / waveformRate)
        var peaks: [Float] = []
        var currentPeak: Int16 = 0
        var count = 0
        while let buffer = output.copyNextSampleBuffer(), let block = CMSampleBufferGetDataBuffer(buffer) {
            var length = 0
            var pointer: UnsafeMutablePointer<CChar>?
            CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer)
            guard let pointer else { continue }
            pointer.withMemoryRebound(to: Int16.self, capacity: length / 2) { samples in
                for index in 0..<(length / 2) {
                    let value = samples[index] == .min ? .max : abs(samples[index])
                    currentPeak = max(currentPeak, value)
                    count += 1
                    if count == samplesPerPeak {
                        peaks.append(Float(currentPeak) / Float(Int16.max))
                        currentPeak = 0
                        count = 0
                    }
                }
            }
        }
        return peaks
    }
}
