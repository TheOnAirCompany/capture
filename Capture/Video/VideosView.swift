import AVKit
import SwiftUI

/// Videos tab: the video editor with its player, timeline, recent videos and inspector.
struct VideosView: View {
    @Environment(CaptureLibrary.self) private var library
    @Environment(ExportSettings.self) private var settings
    @State private var selection: CaptureItem?
    @State private var project: VideoProject?
    @State private var suggestions = SuggestedBackgrounds.empty
    @State private var showsInspector = true
    @State private var showsAll = false
    @State private var expandedTool: VideoTool?

    private struct PreviewInputs: Equatable {
        let edits: VideoEdits?
        let style: CompositionStyle?
        let isLoaded: Bool
    }

    var body: some View {
        Group {
            if library.videos.isEmpty {
                ContentUnavailableView {
                    Label("No Videos Yet", systemImage: "video")
                } description: {
                    Text("Screen recordings you make will appear here.")
                }
            } else {
                VStack(spacing: 0) {
                    player
                    Divider()
                    if let project, project.isLoaded {
                        VideoTimeline(project: project)
                    } else {
                        ProgressView().frame(height: 250)
                    }
                    Divider()
                    RecentStrip(title: "Recent Videos", items: library.videos, selection: $selection, showsAll: $showsAll)
                }
                .background(shortcuts)
            }
        }
        .inspector(isPresented: $showsInspector) {
            Group {
                if let project, project.isLoaded {
                    VideoInspector(project: project, suggestions: suggestions, expandedTool: $expandedTool)
                } else {
                    Color.clear
                }
            }
            .inspectorColumnWidth(min: 300, ideal: 330, max: 400)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Export Options", systemImage: "sidebar.right") { showsInspector.toggle() }
            }
        }
        .sheet(isPresented: $showsAll) {
            AllCapturesView(title: "Videos", items: library.videos, selection: $selection)
        }
        .onAppear(perform: selectLatestIfNeeded)
        .onChange(of: library.videos) { selectLatestIfNeeded() }
        .task(id: selection) { await open(selection) }
        .task(id: previewInputs) {
            // Wait for edits to settle, so dragging a slider doesn't rebuild on every step.
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, let project else { return }
            await project.updatePreview(style: settings.style(for: project.sourceSize))
        }
        .onDisappear { project?.tearDown() }
    }

    private var previewInputs: PreviewInputs {
        PreviewInputs(
            edits: project?.edits,
            style: project.map { settings.style(for: $0.sourceSize) },
            isLoaded: project?.isLoaded ?? false
        )
    }

    private var player: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.background.secondary)
            if let project {
                PlayerView(player: project.player)
                    .clipShape(.rect(cornerRadius: 12))
                    .padding(16)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Keyboard shortcuts for tools that live in the inspector.
    private var shortcuts: some View {
        Group {
            Button("Rotate") { project?.rotate() }
                .keyboardShortcut("r", modifiers: .command)
            Button("Crop") {
                showsInspector = true
                expandedTool = .crop
            }
            .keyboardShortcut("k", modifiers: .command)
        }
        .opacity(0)
        .allowsHitTesting(false)
    }

    private func open(_ item: CaptureItem?) async {
        project?.tearDown()
        guard let item else {
            project = nil
            return
        }
        let project = VideoProject(item: item)
        self.project = project
        suggestions = .empty
        await project.load()
        if let poster = project.posterFrame {
            suggestions = await Task.detached(priority: .utility) { SuggestedBackgrounds.make(from: poster) }.value
        }
    }

    private func selectLatestIfNeeded() {
        if selection == nil || !library.videos.contains(where: { $0.id == selection?.id }) {
            selection = library.videos.first
        }
    }
}

/// AppKit player view with floating controls, scaled to fit.
private struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        view.showsFullScreenToggleButton = true
        view.player = player
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player { view.player = player }
    }
}
