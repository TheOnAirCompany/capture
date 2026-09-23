import SwiftUI

struct CompositionStyle: Equatable {
    var showsBezel: Bool
    var finish: BezelFinish
    var background: CompositionBackground
    /// Space around the device, as a fraction of the device width.
    var margin: Double
    var showsShadow: Bool
}

/// Sizes of a composed screenshot, in pixels of the original capture.
struct CompositionLayout {
    let screen: CGSize
    let screenRadius: CGFloat
    let border: CGFloat
    let band: CGFloat
    let buttonDepth: CGFloat
    let device: CGSize
    let margin: CGFloat
    let canvas: CGSize

    init(screen: CGSize, style: CompositionStyle) {
        self.screen = screen
        let shortSide = min(screen.width, screen.height)
        screenRadius = shortSide * DisplayCorners.ratio(for: screen)

        let hasBezel = style.showsBezel && DisplayCorners.hasRoundedDisplay(screen)
        border = hasBezel ? shortSide * 0.030 : 0
        band = hasBezel ? shortSide * 0.021 : 0
        buttonDepth = hasBezel && screen.height > screen.width ? shortSide * 0.007 : 0

        let frame = border + band
        device = CGSize(width: screen.width + 2 * (frame + buttonDepth), height: screen.height + 2 * frame)
        margin = device.width * style.margin
        canvas = CGSize(width: device.width + 2 * margin, height: device.height + 2 * margin)
    }
}

/// A capture placed in an optional device frame, on an optional background.
/// Laid out in pixels, so rendering it at scale 1 gives the native resolution.
struct ScreenshotComposition: View {
    let image: CGImage
    let style: CompositionStyle
    /// Shows a checkerboard behind transparent areas, for on-screen previews only.
    var showsTransparency = false

    private var layout: CompositionLayout {
        CompositionLayout(screen: CGSize(width: image.width, height: image.height), style: style)
    }

    var body: some View {
        let layout = layout
        ZStack {
            background(layout)
            device(layout)
                .shadow(
                    color: .black.opacity(style.showsShadow && style.background != .none ? 0.28 : 0),
                    radius: layout.device.width * 0.035,
                    y: layout.device.width * 0.02
                )
        }
        .frame(width: layout.canvas.width, height: layout.canvas.height)
        .clipped()
    }

    @ViewBuilder
    private func background(_ layout: CompositionLayout) -> some View {
        switch style.background {
        case .none:
            if showsTransparency { Checkerboard(squareSize: layout.canvas.width / 40) }
        case .color(let color):
            color
        case .gradient(let colors):
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        case .image(let url):
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: layout.canvas.width, height: layout.canvas.height)
            }
        }
    }

    private func device(_ layout: CompositionLayout) -> some View {
        let frame = layout.border + layout.band
        return ZStack {
            if frame > 0 {
                SideButtons(layout: layout, finish: style.finish)
                RoundedRectangle(cornerRadius: layout.screenRadius + frame, style: .continuous)
                    .fill(LinearGradient(colors: style.finish.colors, startPoint: .leading, endPoint: .trailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: layout.screenRadius + frame, style: .continuous)
                            .strokeBorder(.black.opacity(0.25), lineWidth: layout.band * 0.12)
                    )
                    .padding(.horizontal, layout.buttonDepth)
                RoundedRectangle(cornerRadius: layout.screenRadius + layout.border, style: .continuous)
                    .fill(.black)
                    .padding(.horizontal, layout.buttonDepth + layout.band)
                    .padding(.vertical, layout.band)
            }
            Image(decorative: image, scale: 1)
                .resizable()
                .frame(width: layout.screen.width, height: layout.screen.height)
                .clipShape(RoundedRectangle(cornerRadius: layout.screenRadius, style: .continuous))
            if frame > 0, layout.screen.height > layout.screen.width, DisplayCorners.hasDynamicIsland(layout.screen) {
                // Same size on every model: 126 × 37 pt, 11 pt from the top, at 3x.
                Capsule()
                    .fill(.black)
                    .frame(width: 126 * 3, height: 37 * 3)
                    .offset(y: -layout.screen.height / 2 + (11 + 37 / 2) * 3)
            }
        }
        .frame(width: layout.device.width, height: layout.device.height)
    }
}

/// Action button and volume buttons on the left, side button on the right.
private struct SideButtons: View {
    let layout: CompositionLayout
    let finish: BezelFinish

    var body: some View {
        let height = layout.device.height
        let color = LinearGradient(colors: finish.colors, startPoint: .top, endPoint: .bottom)
        ZStack(alignment: .topLeading) {
            Color.clear
            if layout.buttonDepth > 0 {
                button(at: 0.185, length: 0.035, leading: true, fill: color)
                button(at: 0.245, length: 0.062, leading: true, fill: color)
                button(at: 0.325, length: 0.062, leading: true, fill: color)
                button(at: 0.27, length: 0.105, leading: false, fill: color)
            }
        }
        .frame(width: layout.device.width, height: height)
    }

    private func button(at position: CGFloat, length: CGFloat, leading: Bool, fill: LinearGradient) -> some View {
        let depth = layout.buttonDepth * 2
        return RoundedRectangle(cornerRadius: depth / 2, style: .continuous)
            .fill(fill)
            .frame(width: depth, height: layout.device.height * length)
            .offset(
                x: leading ? 0 : layout.device.width - depth,
                y: layout.device.height * position
            )
    }
}

private struct Checkerboard: View {
    let squareSize: CGFloat

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            let columns = Int(size.width / squareSize) + 1, rows = Int(size.height / squareSize) + 1
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(column) * squareSize, y: CGFloat(row) * squareSize,
                                      width: squareSize, height: squareSize)
                    context.fill(Path(rect), with: .color(Color(white: 0.9)))
                }
            }
        }
    }
}
