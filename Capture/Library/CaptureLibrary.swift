import AVFoundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

struct CaptureItem: Identifiable, Hashable {
    let url: URL
    let date: Date

    var id: URL { url }
    var name: String { url.deletingPathExtension().lastPathComponent }
    var isVideo: Bool { UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) == true }
}

/// Screenshots and videos made by Capture in the capture folder and its subfolders, newest first.
/// Files added by hand are ignored: see `CaptureMarker`.
/// Exports are kept apart, in the `_Exports` folder.
@Observable
final class CaptureLibrary {
    private(set) var screenshots: [CaptureItem] = []
    private(set) var videos: [CaptureItem] = []
    private(set) var exports: [CaptureItem] = []

    var allItems: [CaptureItem] { screenshots + videos + exports }

    func reload() {
        (screenshots, videos) = Self.scan(CaptureFolder.url, skippingExports: true)
        let exports = Self.scan(CaptureFolder.url.appending(path: Preferences.exportsFolderName), skippingExports: false)
        self.exports = exports.screenshots + exports.videos
    }

    /// Moves every screenshot, video and export made by Capture to the Trash, then removes
    /// the subfolders left empty. Other files in the folder are left untouched.
    func moveAllToTrash() throws {
        for item in allItems {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
        }
        Self.removeEmptySubfolders(of: CaptureFolder.url)
        reload()
    }

    private static func scan(_ folder: URL, skippingExports: Bool) -> (screenshots: [CaptureItem], videos: [CaptureItem]) {
        let keys: [URLResourceKey] = [.creationDateKey, .contentTypeKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return ([], []) }

        var screenshots: [CaptureItem] = []
        var videos: [CaptureItem] = []
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isDirectory == true {
                if skippingExports, url.lastPathComponent == Preferences.exportsFolderName { enumerator.skipDescendants() }
                continue
            }
            guard let type = values.contentType, CaptureMarker.isMarked(url) else { continue }
            let item = CaptureItem(url: url, date: values.creationDate ?? .distantPast)
            if type.conforms(to: .image) {
                screenshots.append(item)
            } else if type.conforms(to: .movie) {
                videos.append(item)
            }
        }
        return (screenshots.sorted { $0.date > $1.date }, videos.sorted { $0.date > $1.date })
    }

    private static func removeEmptySubfolders(of folder: URL) {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(at: folder, includingPropertiesForKeys: [.isDirectoryKey]) else { return }
        let subfolders = enumerator.compactMap { $0 as? URL }
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.pathComponents.count > $1.pathComponents.count }
        for subfolder in subfolders where (try? manager.contentsOfDirectory(atPath: subfolder.path))?.allSatisfy({ $0 == ".DS_Store" }) == true {
            try? manager.removeItem(at: subfolder)
        }
    }

    func moveToTrash(_ item: CaptureItem) {
        try? FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
        reload()
    }
}

/// Small preview of an image or video file, decoded off the main thread.
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
                await Self.thumbnail(of: url, maxPixelSize: size)
            }.value
        }
    }

    nonisolated private static func thumbnail(of url: URL, maxPixelSize: CGFloat) async -> CGImage? {
        if UTType(filenameExtension: url.pathExtension)?.conforms(to: .movie) == true {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: maxPixelSize, height: maxPixelSize)
            return try? await generator.image(at: .zero).image
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary)
    }
}

