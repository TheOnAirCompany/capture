// Generates the macOS AppIcon set from a single source image.
// Usage: swift scripts/make-icons.swift <source.png> <AppIcon.appiconset>
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let source = NSImage(contentsOfFile: args[1]),
      let cgSource = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("Usage: swift make-icons.swift <source.png> <AppIcon.appiconset>")
    exit(1)
}
let output = URL(fileURLWithPath: args[2])

// macOS icon grid: the artwork occupies 824×824 of a 1024×1024 canvas.
let sizes = [16, 32, 64, 128, 256, 512, 1024]
for size in sizes {
    let canvas = CGFloat(size)
    let body = canvas * 824 / 1024
    let scale = min(body / CGFloat(cgSource.width), body / CGFloat(cgSource.height))
    let w = CGFloat(cgSource.width) * scale, h = CGFloat(cgSource.height) * scale
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(cgSource, in: CGRect(x: (canvas - w) / 2, y: (canvas - h) / 2, width: w, height: h))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try rep.representation(using: .png, properties: [:])!
        .write(to: output.appendingPathComponent("icon_\(size).png"))
}

let entries = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
let images = entries.map { size, scale in
    ["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": "icon_\(size * scale).png"]
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("Contents.json"))
print("Generated \(sizes.count) icons in \(output.path)")
