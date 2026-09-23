import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Renders compositions to image files or the pasteboard.
enum ScreenshotExporter {
    nonisolated static func loadImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func render(_ image: CGImage, style: CompositionStyle, scale: Double) -> CGImage? {
        let renderer = ImageRenderer(content: ScreenshotComposition(image: image, style: style))
        renderer.scale = scale
        return renderer.cgImage
    }

    static func encode(_ image: CGImage, as format: ExportFormat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, format.contentType.identifier as CFString, 1, nil) else {
            return nil
        }
        let options: [CFString: Any] = format == .png ? [:] : [kCGImageDestinationLossyCompressionQuality: 0.92]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    static func copy(_ image: CGImage) -> Bool {
        guard let data = encode(image, as: .png) else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setData(data, forType: .png)
    }

    /// Saves into the `_Exports` folder of the capture folder, without asking.
    static func saveToExportsFolder(_ image: CGImage, as format: ExportFormat, name: String) throws -> URL {
        let folder = CaptureFolder.url.appending(path: Preferences.exportsFolderName, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let pathExtension = format.contentType.preferredFilenameExtension ?? "png"
        var url = folder.appending(path: "\(name).\(pathExtension)")
        var index = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appending(path: "\(name) (\(index)).\(pathExtension)")
            index += 1
        }
        guard let data = encode(image, as: format) else { throw CaptureError.writeFailed }
        try data.write(to: url)
        return url
    }

    /// Asks where to save, in the capture folder by default.
    static func save(_ image: CGImage, as format: ExportFormat, suggestedName: String) throws -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.directoryURL = CaptureFolder.url
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let data = encode(image, as: format) else { throw CaptureError.writeFailed }
        try data.write(to: url)
        return url
    }
}
