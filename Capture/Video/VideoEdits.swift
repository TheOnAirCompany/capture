import AVFoundation
import SwiftUI

/// A piece of the source video kept in the edit, in source time.
nonisolated struct VideoSegment: Identifiable, Equatable, Sendable {
    let id: UUID
    var start: Double
    var end: Double

    init(id: UUID = UUID(), start: Double, end: Double) {
        self.id = id
        self.start = start
        self.end = end
    }

    var duration: Double { end - start }
}

/// Everything the user changed on a video. Kept as a value so edits can be undone.
nonisolated struct VideoEdits: Equatable, Sendable {
    var segments: [VideoSegment]
    var speed = 1.0
    var volume = 1.0
    var isMuted = false
    /// Clockwise quarter turns.
    var rotation = 0
    var musicURL: URL?
    var musicVolume = 1.0

    init(duration: Double) {
        segments = [VideoSegment(start: 0, end: duration)]
    }

    /// Length of the edited video, in seconds.
    var duration: Double {
        segments.reduce(0) { $0 + $1.duration } / speed
    }

    /// Where each segment starts in the edited video.
    var segmentStarts: [Double] {
        var starts: [Double] = []
        var cursor = 0.0
        for segment in segments {
            starts.append(cursor)
            cursor += segment.duration / speed
        }
        return starts
    }

    /// The segment playing at `time` in the edited video, with its index.
    func segment(at time: Double) -> (index: Int, start: Double)? {
        for (index, start) in segmentStarts.enumerated() {
            let end = start + segments[index].duration / speed
            if time >= start && time < end { return (index, start) }
        }
        return segments.isEmpty ? nil : (segments.count - 1, segmentStarts.last ?? 0)
    }

    /// Splits the segment under `time` in two.
    @discardableResult
    mutating func split(at time: Double) -> Bool {
        guard let (index, start) = segment(at: time) else { return false }
        let segment = segments[index]
        let sourceTime = segment.start + (time - start) * speed
        // Avoid slivers shorter than a tenth of a second.
        guard sourceTime - segment.start > 0.1, segment.end - sourceTime > 0.1 else { return false }
        segments[index].end = sourceTime
        segments.insert(VideoSegment(start: sourceTime, end: segment.end), at: index + 1)
        return true
    }

    var hasVideoAdjustments: Bool { rotation % 4 != 0 }
}
