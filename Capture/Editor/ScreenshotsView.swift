import SwiftUI

/// Screenshots tab: the selected capture with its frame and background,
/// recent captures below, and export options in the inspector.
struct ScreenshotsView: View {
    @Environment(CaptureLibrary.self) private var library
    @Environment(ExportSettings.self) private var settings
    @State private var selection: CaptureItem?
    @State private var image: CGImage?
    @State private var suggestions = SuggestedBackgrounds.empty
    @State private var showsInspector = true
    @State private var showsAll = false

    var body: some View {
        Group {
            if library.screenshots.isEmpty {
                ContentUnavailableView {
                    Label("No Screenshots Yet", systemImage: "camera")
                } description: {
                    Text("Screenshots you take will appear here.")
                }
            } else {
                VStack(spacing: 0) {
                    canvas
                    Divider()
                    RecentStrip(title: "Recent Captures", items: library.screenshots, selection: $selection, showsAll: $showsAll)
                }
            }
        }
        .inspector(isPresented: $showsInspector) {
            ExportInspector(image: image, item: selection, suggestions: suggestions)
                .inspectorColumnWidth(min: 290, ideal: 320, max: 380)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Export Options", systemImage: "sidebar.right") { showsInspector.toggle() }
            }
        }
        .sheet(isPresented: $showsAll) {
            AllCapturesView(title: "Screenshots", items: library.screenshots, selection: $selection)
        }
        .onAppear(perform: selectLatestIfNeeded)
        .onChange(of: library.screenshots) { selectLatestIfNeeded() }
        .task(id: selection) {
            guard let url = selection?.url else { image = nil; return }
            let loaded = await Task.detached(priority: .userInitiated) { ScreenshotExporter.loadImage(at: url) }.value
            image = loaded
            guard let loaded else { suggestions = .empty; return }
            suggestions = await Task.detached(priority: .utility) { SuggestedBackgrounds.make(from: loaded) }.value
        }
    }

    private var canvas: some View {
        GeometryReader { proxy in
            if let image {
                let size = CGSize(width: image.width, height: image.height)
                let style = settings.style(for: size)
                let layout = CompositionLayout(image: size, style: style)
                let available = CGSize(width: proxy.size.width - 64, height: proxy.size.height - 64)
                let scale = max(0.01, min(available.width / layout.canvas.width, available.height / layout.canvas.height))
                ScreenshotComposition(image: image, style: style, showsTransparency: true)
                    .scaleEffect(scale)
                    .frame(width: layout.canvas.width * scale, height: layout.canvas.height * scale)
                    .clipShape(.rect(cornerRadius: style.background == .none ? 0 : 20))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.smooth, value: style)
            }
        }
    }

    private func selectLatestIfNeeded() {
        if selection == nil || !library.screenshots.contains(where: { $0.id == selection?.id }) {
            selection = library.screenshots.first
        }
    }
}

struct RecentStrip: View {
    let title: LocalizedStringKey
    let items: [CaptureItem]
    @Binding var selection: CaptureItem?
    @Binding var showsAll: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button("See All") { showsAll = true }
                    .buttonStyle(.link)
            }
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(items.prefix(30)) { item in
                        CaptureTile(item: item, isSelected: item == selection)
                            .frame(width: 64, height: 96)
                            .onTapGesture { selection = item }
                    }
                }
                .padding(4)
            }
            .scrollIndicators(.never)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(height: 158)
    }
}

struct CaptureTile: View {
    @Environment(CaptureLibrary.self) private var library
    let item: CaptureItem
    let isSelected: Bool

    var body: some View {
        CaptureThumbnail(url: item.url)
            .overlay {
                if item.isVideo {
                    Image(systemName: "play.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .shadow(radius: 3)
                }
            }
            .clipShape(.rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator), lineWidth: isSelected ? 3 : 1)
            )
            .contentShape(.rect)
            .help(item.name)
            .contextMenu {
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                Divider()
                Button("Move to Trash", role: .destructive) { library.moveToTrash(item) }
            }
    }
}

struct AllCapturesView: View {
    let title: LocalizedStringKey
    let items: [CaptureItem]
    @Binding var selection: CaptureItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 16)], spacing: 16) {
                    ForEach(items) { item in
                        VStack(spacing: 6) {
                            CaptureTile(item: item, isSelected: item == selection)
                                .aspectRatio(9 / 19.5, contentMode: .fit)
                            Text(item.date, format: .dateTime.day().month().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .onTapGesture {
                            selection = item
                            dismiss()
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(Text(title))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 520)
    }
}
