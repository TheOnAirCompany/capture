import SwiftUI
import UniformTypeIdentifiers

/// Playback controls and the timeline: ruler, video track with trim handles,
/// audio waveform and the optional music track.
struct VideoTimeline: View {
    @Bindable var project: VideoProject
    @State private var zoom = 1.0

    private let labelWidth: CGFloat = 96
    private let rulerHeight: CGFloat = 26
    private let videoHeight: CGFloat = 60
    private let audioHeight: CGFloat = 46

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            GeometryReader { proxy in
                let available = proxy.size.width - labelWidth - 32
                let pointsPerSecond = max(1, available / max(project.duration, 1)) * zoom
                HStack(alignment: .top, spacing: 0) {
                    trackLabels
                    ScrollView(.horizontal) {
                        tracks(pointsPerSecond: pointsPerSecond)
                            .padding(.horizontal, 12)
                    }
                    .scrollIndicators(.automatic)
                }
            }
        }
        .frame(height: 250)
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 14) {
            Button("Undo", systemImage: "arrow.uturn.backward", action: project.undo)
                .disabled(!project.canUndo)
                .keyboardShortcut("z", modifiers: .command)
            Button("Redo", systemImage: "arrow.uturn.forward", action: project.redo)
                .disabled(!project.canRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])

            Spacer()

            Button(project.isPlaying ? "Pause" : "Play", systemImage: project.isPlaying ? "pause.fill" : "play.fill",
                   action: project.togglePlayback)
                .font(.title3)
                .keyboardShortcut(.space, modifiers: [])
            HStack(spacing: 4) {
                Text(verbatim: Self.timecode(project.currentTime))
                Text(verbatim: "/ \(Self.timecode(project.duration))").foregroundStyle(.secondary)
            }
            .monospacedDigit()

            Button("Split at Playhead", systemImage: "scissors", action: project.splitAtPlayhead)
                .buttonStyle(.bordered)
                .keyboardShortcut("t", modifiers: .command)
            Button("Delete Segment", systemImage: "trash", action: project.deleteSelectedSegment)
                .buttonStyle(.bordered)
                .disabled(project.selectedSegmentID == nil || project.edits.segments.count < 2)
                .keyboardShortcut(.delete, modifiers: [])

            Spacer()

            Button("Zoom Out", systemImage: "minus") { zoom = max(1, zoom / 1.5) }
            Slider(value: $zoom, in: 1...12)
                .frame(width: 110)
            Button("Zoom In", systemImage: "plus") { zoom = min(12, zoom * 1.5) }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var trackLabels: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear.frame(height: rulerHeight)
            Label("Video", systemImage: "video").frame(height: videoHeight)
            Label("Audio", systemImage: "music.note").frame(height: audioHeight)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.leading, 16)
        .frame(width: labelWidth, alignment: .leading)
    }

    // MARK: Tracks

    private func tracks(pointsPerSecond: CGFloat) -> some View {
        let width = project.duration * pointsPerSecond
        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                Ruler(duration: project.duration, pointsPerSecond: pointsPerSecond)
                    .frame(width: width, height: rulerHeight)
                    .contentShape(.rect)
                    .gesture(scrubGesture(pointsPerSecond: pointsPerSecond))

                HStack(spacing: 0) {
                    ForEach(Array(project.edits.segments.enumerated()), id: \.element.id) { _, segment in
                        SegmentView(
                            project: project,
                            segment: segment,
                            pointsPerSecond: pointsPerSecond,
                            height: videoHeight
                        )
                    }
                }
                .frame(height: videoHeight)

                HStack(spacing: 0) {
                    ForEach(project.edits.segments) { segment in
                        Waveform(
                            peaks: project.waveform,
                            segment: segment,
                            isMuted: project.edits.isMuted || !project.hasAudio
                        )
                        .frame(width: segment.duration / project.edits.speed * pointsPerSecond, height: audioHeight)
                    }
                }
                .background(.blue.opacity(0.12), in: .rect(cornerRadius: 8))
                .clipShape(.rect(cornerRadius: 8))
                .frame(height: audioHeight)

                MusicTrack(project: project)
                    .frame(width: max(width, 320))
            }

            Playhead(height: rulerHeight + videoHeight + audioHeight + 20)
                .offset(x: project.currentTime * pointsPerSecond - 6)
                .gesture(scrubGesture(pointsPerSecond: pointsPerSecond))
        }
        .frame(width: max(width, 320), alignment: .leading)
        .coordinateSpace(.named("tracks"))
        .padding(.vertical, 10)
    }

    private func scrubGesture(pointsPerSecond: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("tracks"))
            .onChanged { value in project.seek(to: value.location.x / pointsPerSecond) }
    }

    static func timecode(_ seconds: Double) -> String {
        let total = max(0, seconds)
        let minutes = Int(total) / 60, secs = Int(total) % 60
        let hundredths = Int((total - total.rounded(.down)) * 100)
        return String(format: "%02d:%02d,%02d", minutes, secs, hundredths)
    }
}

private struct Ruler: View {
    let duration: Double
    let pointsPerSecond: CGFloat

    var body: some View {
        Canvas { context, size in
            // Keep labels at least 60 points apart.
            let steps: [Double] = [0.5, 1, 2, 5, 10, 15, 30, 60, 120]
            let step = steps.first { $0 * pointsPerSecond >= 60 } ?? 300
            var time = 0.0
            while time <= duration + 0.001 {
                let x = time * pointsPerSecond
                context.fill(Path(CGRect(x: x, y: size.height - 8, width: 1, height: 8)), with: .color(.secondary))
                let minutes = Int(time) / 60, seconds = Int(time) % 60
                context.draw(
                    Text(verbatim: String(format: "%02d:%02d", minutes, seconds)).font(.caption2).foregroundStyle(.secondary),
                    at: CGPoint(x: x + 3, y: 2), anchor: .topLeading
                )
                time += step
            }
        }
    }
}

private struct Playhead: View {
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Circle().fill(.tint).frame(width: 12, height: 12)
            Rectangle().fill(.tint).frame(width: 2, height: height)
        }
        .frame(width: 12)
        .contentShape(.rect)
    }
}

/// One kept piece of the video, with a filmstrip and trim handles when selected.
private struct SegmentView: View {
    @Bindable var project: VideoProject
    let segment: VideoSegment
    let pointsPerSecond: CGFloat
    let height: CGFloat

    @State private var dragOrigin: (start: Double, end: Double)?

    private var isSelected: Bool { project.selectedSegmentID == segment.id }
    private var width: CGFloat { segment.duration / project.edits.speed * pointsPerSecond }

    var body: some View {
        filmstrip
            .frame(width: width, height: height)
            .clipShape(.rect(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? AnyShapeStyle(.yellow) : AnyShapeStyle(.separator), lineWidth: isSelected ? 3 : 1)
            }
            .overlay(alignment: .leading) { if isSelected { handle(isStart: true) } }
            .overlay(alignment: .trailing) { if isSelected { handle(isStart: false) } }
            .padding(.trailing, 2)
            .contentShape(.rect)
            .onTapGesture { location in
                project.selectedSegmentID = segment.id
                let starts = project.edits.segmentStarts
                if let index = project.edits.segments.firstIndex(of: segment) {
                    project.seek(to: starts[index] + location.x / pointsPerSecond)
                }
            }
    }

    private var filmstrip: some View {
        Canvas { context, size in
            let tileWidth = height * 9 / 16
            var x: CGFloat = 0
            while x < size.width {
                let sourceTime = segment.start + x / pointsPerSecond * project.edits.speed
                let second = min(Int(sourceTime), max(0, Int(project.sourceDuration)))
                if let image = project.thumbnails[second] ?? project.thumbnails[second - 1] {
                    context.draw(Image(decorative: image, scale: 1).resizable(),
                                 in: CGRect(x: x, y: 0, width: tileWidth, height: size.height))
                } else {
                    context.fill(Path(CGRect(x: x, y: 0, width: tileWidth - 1, height: size.height)), with: .color(.gray.opacity(0.3)))
                }
                x += tileWidth
            }
        }
    }

    private func handle(isStart: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(.yellow)
            .frame(width: 10)
            .overlay {
                Image(systemName: isStart ? "chevron.compact.left" : "chevron.compact.right")
                    .font(.caption.bold())
                    .foregroundStyle(.black.opacity(0.6))
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let origin = dragOrigin ?? (segment.start, segment.end)
                        dragOrigin = origin
                        let delta = value.translation.width / pointsPerSecond * project.edits.speed
                        if isStart {
                            project.trim(segment.id, start: origin.start + delta)
                        } else {
                            project.trim(segment.id, end: origin.end + delta)
                        }
                    }
                    .onEnded { _ in dragOrigin = nil }
            )
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
    }
}

private struct Waveform: View {
    let peaks: [Float]
    let segment: VideoSegment
    let isMuted: Bool

    var body: some View {
        Canvas { context, size in
            let first = Int(segment.start * VideoProject.waveformRate)
            let last = min(peaks.count, Int(segment.end * VideoProject.waveformRate))
            guard last > first else {
                // Silent recording: a flat line.
                context.fill(Path(CGRect(x: 0, y: size.height / 2 - 0.5, width: size.width, height: 1)), with: .color(.gray.opacity(0.5)))
                return
            }
            let slice = peaks[first..<last]
            let barWidth: CGFloat = 2
            let bars = Int(size.width / (barWidth + 1))
            guard bars > 0 else { return }
            for bar in 0..<bars {
                let index = first + (bar * slice.count) / bars
                let peak = CGFloat(peaks[min(index, last - 1)])
                let barHeight = max(1, peak * (size.height - 8))
                let rect = CGRect(x: CGFloat(bar) * (barWidth + 1), y: (size.height - barHeight) / 2, width: barWidth, height: barHeight)
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(isMuted ? .gray.opacity(0.5) : .blue.opacity(0.7)))
            }
        }
    }
}

/// The added music or voice-over, or a button to add one.
private struct MusicTrack: View {
    @Bindable var project: VideoProject

    var body: some View {
        if let url = project.edits.musicURL {
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                Text(verbatim: url.deletingPathExtension().lastPathComponent)
                    .lineLimit(1)
                Spacer()
                Button("Remove Track", systemImage: "xmark.circle.fill") {
                    project.apply { $0.musicURL = nil }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            }
            .font(.callout)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(.purple.opacity(0.15), in: .rect(cornerRadius: 8))
        } else {
            Button(action: chooseTrack) {
                Label("Add a Track (Music, Voice-Over…)", systemImage: "plus")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            .foregroundStyle(.tertiary)
                    )
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    private func chooseTrack() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        project.apply { $0.musicURL = url }
    }
}
