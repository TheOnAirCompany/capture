import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Export options and editing tools for the open video.
struct VideoInspector: View {
    @Bindable var project: VideoProject
    let suggestions: SuggestedBackgrounds
    @Binding var expandedTool: VideoTool?

    @Environment(ExportSettings.self) private var settings
    @Environment(CaptureLibrary.self) private var library

    @AppStorage("videoExport.format") private var format: VideoExportFormat = .mp4
    @AppStorage("videoExport.resolution") private var resolution: VideoResolution = .source
    @AppStorage("videoExport.frameRate") private var frameRate: VideoFrameRate = .source
    @AppStorage("videoExport.includesAudio") private var includesAudio = true
    @AppStorage("videoExport.optimizesForNetwork") private var optimizesForNetwork = true
    @State private var showsAdvanced = false
    @State private var exported = false
    @State private var errorMessage: String?

    private var style: CompositionStyle { settings.style(for: project.sourceSize) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                exportSection
                Divider()
                toolsSection
                Divider()
                BezelSection(size: project.sourceSize)
                BackgroundSection(suggestions: suggestions)
                MarginSection()
                Button("Reset", action: project.reset)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(!project.canUndo && project.edits == VideoEdits(duration: project.sourceDuration))
            }
            .padding(20)
        }
        .alert("Couldn't Export the Video", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: errorMessage ?? "")
        }
    }

    // MARK: Export

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export").font(.title3.bold())

            field("Format") {
                Picker("Format", selection: $format) {
                    ForEach(VideoExportFormat.allCases) { Text($0.title).tag($0) }
                }
            }
            field("Resolution") {
                Picker("Resolution", selection: $resolution) {
                    ForEach(VideoResolution.allCases) { option in
                        Text(resolutionTitle(option)).tag(option)
                    }
                }
            }
            field("Frame Rate") {
                Picker("Frame Rate", selection: $frameRate) {
                    ForEach(VideoFrameRate.allCases) { option in
                        Text(frameRateTitle(option)).tag(option)
                    }
                }
            }

            DisclosureGroup("Advanced Options", isExpanded: $showsAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Include Sound", isOn: $includesAudio)
                    Toggle("Optimize for Web Sharing", isOn: $optimizesForNetwork)
                }
                .padding(.top, 6)
            }
            .foregroundStyle(.tint)

            if let progress = project.exportProgress {
                ProgressView(value: progress) {
                    Text("Exporting…")
                }
            } else {
                Button(action: export) {
                    Label(exported ? "Exported" : "Export Video…", systemImage: exported ? "checkmark" : "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("e", modifiers: .command)
            }
        }
    }

    private func field<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            content().labelsHidden()
        }
    }

    private func resolutionTitle(_ option: VideoResolution) -> LocalizedStringKey {
        let size = project.outputSize(style: style, resolution: option)
        let dimensions = "\(Int(size.width)) × \(Int(size.height))"
        switch option {
        case .source: return "Same as Source (\(dimensions))"
        case .p1080: return "1080p (\(dimensions))"
        case .p720: return "720p (\(dimensions))"
        }
    }

    private func frameRateTitle(_ option: VideoFrameRate) -> LocalizedStringKey {
        switch option {
        case .source: return "Same as Source (\(Int(project.sourceFrameRate.rounded())) fps)"
        case .fps60: return "60 fps"
        case .fps30: return "30 fps"
        case .fps24: return "24 fps"
        }
    }

    private func export() {
        let name = "\(project.item.name) (\(String(localized: "edited")))"
        let url: URL
        if Preferences.exportsToCaptureFolder {
            let folder = CaptureFolder.url.appending(path: Preferences.exportsFolderName, directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var candidate = folder.appending(path: "\(name).\(format.pathExtension)")
            var index = 2
            while FileManager.default.fileExists(atPath: candidate.path) {
                candidate = folder.appending(path: "\(name) (\(index)).\(format.pathExtension)")
                index += 1
            }
            url = candidate
        } else {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [format == .mp4 ? .mpeg4Movie : .quickTimeMovie]
            panel.directoryURL = CaptureFolder.url
            panel.nameFieldStringValue = name
            guard panel.runModal() == .OK, let chosen = panel.url else { return }
            url = chosen
        }

        let style = style, format = format, resolution = resolution, frameRate = frameRate
        let includesAudio = includesAudio, optimizes = optimizesForNetwork
        Task {
            do {
                try await project.export(
                    to: url, style: style, format: format, resolution: resolution, frameRate: frameRate,
                    includesAudio: includesAudio, optimizesForNetwork: optimizes
                )
                library.reload()
                if Preferences.exportsToCaptureFolder {
                    exported = true
                    try? await Task.sleep(for: .seconds(2))
                    exported = false
                } else {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: Tools

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tools").font(.title3.bold())

            ToolRow(tool: .cut, expanded: $expandedTool, action: project.splitAtPlayhead)
            ToolRow(tool: .crop, expanded: $expandedTool) {
                Picker("Aspect Ratio", selection: binding(\.crop)) {
                    ForEach(CropAspect.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            ToolRow(tool: .rotate, expanded: $expandedTool, action: project.rotate)
            ToolRow(tool: .speed, expanded: $expandedTool) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Speed", selection: binding(\.speed)) {
                        ForEach([0.25, 0.5, 1, 1.5, 2, 4], id: \.self) { value in
                            Text(verbatim: "\(value.formatted())x").tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Text("Sound keeps its pitch when the speed changes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ToolRow(tool: .volume, expanded: $expandedTool) {
                VStack(alignment: .leading, spacing: 8) {
                    slider("iPhone Sound", value: binding(\.volume, coalescing: true), range: 0...2, format: .percent)
                        .disabled(project.edits.isMuted || !project.hasAudio)
                    Toggle("Mute", isOn: binding(\.isMuted))
                        .disabled(!project.hasAudio)
                    if project.edits.musicURL != nil {
                        slider("Added Track", value: binding(\.musicVolume, coalescing: true), range: 0...2, format: .percent)
                    }
                }
            }
            ToolRow(tool: .filters, expanded: $expandedTool) {
                FilterPicker(poster: project.posterFrame, selection: binding(\.filter))
            }
            ToolRow(tool: .adjustments, expanded: $expandedTool) {
                VStack(alignment: .leading, spacing: 8) {
                    slider("Brightness", value: binding(\.brightness, coalescing: true), range: -0.5...0.5, format: .signed)
                    slider("Contrast", value: binding(\.contrast, coalescing: true), range: 0.5...1.5, format: .relative)
                    slider("Saturation", value: binding(\.saturation, coalescing: true), range: 0...2, format: .relative)
                }
            }
        }
    }

    private enum ValueFormat { case percent, signed, relative }

    private func slider(_ title: LocalizedStringKey, value: Binding<Double>, range: ClosedRange<Double>, format: ValueFormat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Group {
                    switch format {
                    case .percent: Text(value.wrappedValue, format: .percent.precision(.fractionLength(0)))
                    case .signed: Text(value.wrappedValue * 200, format: .number.precision(.fractionLength(0)).sign(strategy: .always()))
                    case .relative: Text((value.wrappedValue - 1) * 100, format: .number.precision(.fractionLength(0)).sign(strategy: .always()))
                    }
                }
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
            .font(.callout)
            Slider(value: value, in: range)
        }
    }

    private func binding<Value: Equatable>(_ keyPath: WritableKeyPath<VideoEdits, Value>, coalescing: Bool = false) -> Binding<Value> {
        Binding(
            get: { project.edits[keyPath: keyPath] },
            set: { newValue in project.apply(coalescing: coalescing) { $0[keyPath: keyPath] = newValue } }
        )
    }
}

enum VideoTool: String, CaseIterable, Identifiable {
    case cut, crop, rotate, speed, volume, filters, adjustments

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .cut: "Cut"
        case .crop: "Crop"
        case .rotate: "Rotate"
        case .speed: "Speed"
        case .volume: "Volume"
        case .filters: "Filters"
        case .adjustments: "Adjustments"
        }
    }

    var systemImage: String {
        switch self {
        case .cut: "scissors"
        case .crop: "crop"
        case .rotate: "rotate.right"
        case .speed: "gauge.with.dots.needle.33percent"
        case .volume: "speaker.wave.2"
        case .filters: "camera.filters"
        case .adjustments: "slider.horizontal.3"
        }
    }

    var shortcut: String? {
        switch self {
        case .cut: "⌘T"
        case .crop: "⌘K"
        case .rotate: "⌘R"
        default: nil
        }
    }
}

/// A tool button: runs an action, or expands to show its options.
private struct ToolRow<Options: View>: View {
    let tool: VideoTool
    @Binding var expanded: VideoTool?
    var action: (() -> Void)?
    @ViewBuilder var options: Options

    init(tool: VideoTool, expanded: Binding<VideoTool?>, action: @escaping () -> Void) where Options == EmptyView {
        self.tool = tool
        _expanded = expanded
        self.action = action
        options = EmptyView()
    }

    init(tool: VideoTool, expanded: Binding<VideoTool?>, @ViewBuilder options: () -> Options) {
        self.tool = tool
        _expanded = expanded
        self.options = options()
    }

    private var isExpanded: Bool { expanded == tool }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                if let action {
                    action()
                } else {
                    withAnimation(.snappy) { expanded = isExpanded ? nil : tool }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: tool.systemImage)
                        .frame(width: 22)
                    Text(tool.title)
                    Spacer()
                    if let shortcut = tool.shortcut {
                        Text(verbatim: shortcut).foregroundStyle(.secondary).font(.callout)
                    }
                    if action == nil {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isExpanded {
                options
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .background(.background.secondary, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
    }
}

/// Filter thumbnails rendered from the first frame of the video.
private struct FilterPicker: View {
    let poster: CGImage?
    @Binding var selection: VideoFilter
    @State private var previews: [VideoFilter: CGImage] = [:]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
            ForEach(VideoFilter.allCases) { filter in
                Button { selection = filter } label: {
                    VStack(spacing: 4) {
                        Group {
                            if let image = previews[filter] ?? poster {
                                Image(decorative: image, scale: 1).resizable().scaledToFill()
                            } else {
                                Rectangle().fill(.quaternary)
                            }
                        }
                        .frame(height: 64)
                        .frame(maxWidth: .infinity)
                        .clipShape(.rect(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(selection == filter ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
                        )
                        Text(filter.title).font(.caption)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: poster.map(ObjectIdentifier.init)) {
            guard let poster else { return }
            let context = CIContext()
            for filter in VideoFilter.allCases {
                var edits = VideoEdits(duration: 0)
                edits.filter = filter
                let image = VideoRenderer.process(CIImage(cgImage: poster), edits: edits)
                previews[filter] = context.createCGImage(image, from: image.extent)
            }
        }
    }
}
