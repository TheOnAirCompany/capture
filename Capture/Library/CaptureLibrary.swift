import Observation
import SwiftUI
import UniformTypeIdentifiers

struct CaptureItem: Identifiable, Hashable {
    let url: URL
    let date: Date

    var id: URL { url }
    var name: String { url.deletingPathExtension().lastPathComponent }
}

/// Screenshots and videos found in the capture folder, newest first.
@Observable
final class CaptureLibrary {
    private(set) var screenshots: [CaptureItem] = []
    private(set) var videos: [CaptureItem] = []

    func reload() {
        let keys: [URLResourceKey] = [.creationDateKey, .contentTypeKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: CaptureFolder.url, includingPropertiesForKeys: keys, options: .skipsHiddenFiles
        )) ?? []

        var screenshots: [CaptureItem] = []
        var videos: [CaptureItem] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), let type = values.contentType else { continue }
            let item = CaptureItem(url: url, date: values.creationDate ?? .distantPast)
            if type.conforms(to: .image) {
                screenshots.append(item)
            } else if type.conforms(to: .movie) {
                videos.append(item)
            }
        }
        self.screenshots = screenshots.sorted { $0.date > $1.date }
        self.videos = videos.sorted { $0.date > $1.date }
    }

    func moveToTrash(_ item: CaptureItem) {
        try? FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
        reload()
    }
}

/// Small preview of an image file, decoded off the main thread.
struct CaptureThumbnail: View {
    let url: URL
    var maxPixelSize: CGFloat = 320

    @State private var image: CGImage?

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipped()
        .task(id: url) {
            let url = url, size = maxPixelSize
            image = await Task.detached(priority: .utility) {
                Self.thumbnail(of: url, maxPixelSize: size)
            }.value
        }
    }

    nonisolated private static func thumbnail(of url: URL, maxPixelSize: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary)
    }
}

