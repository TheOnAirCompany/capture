import AppKit
import UniformTypeIdentifiers

/// Copies images and videos from the Mac into the capture folder, so they can be edited
/// like captures. The originals are never modified: only the copies are marked.
enum CaptureImporter {
    static let enabledKey = "libraryImportEnabled"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// Asks for files, then copies them. Returns how many were imported.
    @discardableResult
    static func chooseAndImport(into library: CaptureLibrary) -> Int {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .movie]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = String(localized: "Import")
        guard panel.runModal() == .OK else { return 0 }

        let folder = CaptureFolder.url
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var count = 0
        for source in panel.urls {
            let destination = uniqueURL(for: source, in: folder)
            do {
                try FileManager.default.copyItem(at: source, to: destination)
                CaptureMarker.mark(destination)
                count += 1
            } catch {
                continue
            }
        }
        library.reload()
        return count
    }

    private static func uniqueURL(for source: URL, in folder: URL) -> URL {
        let name = source.deletingPathExtension().lastPathComponent
        let pathExtension = source.pathExtension
        var url = folder.appending(path: source.lastPathComponent)
        var index = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appending(path: "\(name) (\(index))").appendingPathExtension(pathExtension)
            index += 1
        }
        return url
    }
}
