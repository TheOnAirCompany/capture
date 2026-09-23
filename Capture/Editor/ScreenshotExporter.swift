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

    /// Asks where to save, next to the original capture by default.
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
