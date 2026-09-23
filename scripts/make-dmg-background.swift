// Draws the DMG window background at 1x and 2x, then merges them into dmg/background.tiff.
// Icon centers must match `icon_locations` in dmg/settings.py.
// Usage: swift scripts/make-dmg-background.swift
import AppKit
import SwiftUI

let size = CGSize(width: 660, height: 400)
let appCenter = CGPoint(x: 180, y: 165)
let applicationsCenter = CGPoint(x: 480, y: 165)

struct Background: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.98), Color(white: 0.93)], startPoint: .top, endPoint: .bottom)
            // Soft glow in the colors of the app icon.
            Ellipse()
                .fill(LinearGradient(
                    colors: [Color(red: 0.55, green: 0.70, blue: 1.0), Color(red: 0.96, green: 0.66, blue: 0.86), Color(red: 1.0, green: 0.84, blue: 0.66)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(width: 520, height: 180)
                .blur(radius: 70)
                .opacity(0.45)
                .position(x: size.width / 2, y: appCenter.y)

            ZStack {
                Arrow(part: .line)
                    .stroke(Color(white: 0.55), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 9]))
                Arrow(part: .head)
                    .stroke(Color(white: 0.55), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            .frame(width: 150, height: 28)
            .position(x: (appCenter.x + applicationsCenter.x) / 2, y: appCenter.y)

            VStack(spacing: 6) {
                Text("Drag Capture to your Applications folder")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(white: 0.2))
                Text("Glissez Capture dans le dossier Applications")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.45))
            }
            .position(x: size.width / 2, y: 300)
        }
        .frame(width: size.width, height: size.height)
    }
}

struct Arrow: Shape {
    enum Part { case line, head }
    let part: Part

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch part {
        case .line:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.midY))
        case .head:
            path.move(to: CGPoint(x: rect.maxX - 12, y: rect.minY + 2))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX - 12, y: rect.maxY - 2))
        }
        return path
    }
}

@MainActor
func write(scale: CGFloat, to path: String) throws {
    let renderer = ImageRenderer(content: Background())
    renderer.scale = scale
    guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = size  // 72 dpi at 1x, 144 dpi at 2x
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

try MainActor.assumeIsolated {
    try write(scale: 1, to: "dmg/background.png")
    try write(scale: 2, to: "dmg/background@2x.png")
}
let merge = Process()
merge.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
merge.arguments = ["-cathidpicheck", "dmg/background.png", "dmg/background@2x.png", "-out", "dmg/background.tiff"]
try merge.run()
merge.waitUntilExit()
print("Wrote dmg/background.tiff")
