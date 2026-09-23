import SwiftUI

struct CompositionStyle: Equatable {
    var model: DeviceModel?
    var showsBezel: Bool
    var finish: DeviceFinish?
    var showsDynamicIsland = true
    var background: CompositionBackground
    /// Space around the device, as a fraction of the device width.
    var margin: Double
    var showsShadow: Bool
}

/// Sizes of a composed screenshot, in pixels of the device screen.
struct CompositionLayout {
    let screen: CGSize
    let isPortrait: Bool
    let screenRadius: CGFloat
    /// Pixels per point of the device, to size the notch or Dynamic Island.
    let pixelsPerPoint: CGFloat
    let border: CGFloat
    let band: CGFloat
    let buttonDepth: CGFloat
    let device: CGSize
    let margin: CGFloat
    let canvas: CGSize

    init(image: CGSize, style: CompositionStyle) {
        isPortrait = image.height >= image.width
        let hasBezel = style.showsBezel && style.model != nil

        // With a frame, the screen takes the size of the chosen model.
        if hasBezel, let model = style.model {
            screen = isPortrait ? model.screen : CGSize(width: model.screen.height, height: model.screen.width)
        } else {
            screen = image
        }
        let shortSide = min(screen.width, screen.height)
        if let model = style.model {
            screenRadius = shortSide * model.cornerRadius * model.scale / model.screen.width
            pixelsPerPoint = shortSide / (model.screen.width / model.scale)
        } else {
            screenRadius = shortSide * DisplayCorners.ratio(for: image)
            pixelsPerPoint = 3
        }

        border = hasBezel ? shortSide * 0.030 : 0
        band = hasBezel ? shortSide * 0.021 : 0
        buttonDepth = hasBezel && isPortrait ? shortSide * 0.007 : 0

        let frame = border + band
        device = CGSize(width: screen.width + 2 * (frame + buttonDepth), height: screen.height + 2 * frame)
        margin = device.width * style.margin
        canvas = CGSize(width: device.width + 2 * margin, height: device.height + 2 * margin)
    }

    /// Top-left corner of the screen in the canvas (the layout is symmetric).
    var screenOrigin: CGPoint {
        CGPoint(x: margin + buttonDepth + border + band, y: margin + border + band)
    }
}

/// Which part of a composition to draw. Videos are composed frame by frame between
/// a still layer below the screen and one above it.
enum CompositionPart {
    case all
    /// Background and device, with a black screen.
    case belowScreen
    /// Only what covers the screen: the notch or Dynamic Island.
    case aboveScreen
}

/// A capture placed in an optional device frame, on an optional background.
/// Laid out in pixels, so rendering it at scale 1 gives the native resolution.
struct ScreenshotComposition: View {
    let image: CGImage?
    let imageSize: CGSize
    let style: CompositionStyle
    var part = CompositionPart.all
    /// Shows a checkerboard behind transparent areas, for on-screen previews only.
    var showsTransparency = false

    init(image: CGImage, style: CompositionStyle, showsTransparency: Bool = false) {
        self.image = image
        imageSize = CGSize(width: image.width, height: image.height)
        self.style = style
        self.showsTransparency = showsTransparency
    }

    init(imageSize: CGSize, style: CompositionStyle, part: CompositionPart) {
        image = nil
        self.imageSize = imageSize
        self.style = style
        self.part = part
    }

    private var layout: CompositionLayout {
        CompositionLayout(image: imageSize, style: style)
    }

    var body: some View {
        let layout = layout
        ZStack {
            if part != .aboveScreen { background(layout) }
            device(layout)
                // One shadow for the whole device, not one per part (such as the Dynamic Island).
                .compositingGroup()
                .shadow(
                    color: .black.opacity(style.showsShadow && style.background != .none && part != .aboveScreen ? 0.28 : 0),
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
        let bandColors = style.finish?.bandColors ?? [.gray]
        return ZStack {
            if frame > 0, part != .aboveScreen {
                SideButtons(layout: layout, colors: bandColors)
                RoundedRectangle(cornerRadius: layout.screenRadius + frame, style: .continuous)
                    .fill(LinearGradient(colors: bandColors, startPoint: .leading, endPoint: .trailing))
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
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .frame(width: layout.screen.width, height: layout.screen.height)
                    .clipShape(RoundedRectangle(cornerRadius: layout.screenRadius, style: .continuous))
            } else if part == .belowScreen {
                RoundedRectangle(cornerRadius: layout.screenRadius, style: .continuous)
                    .fill(.black)
                    .frame(width: layout.screen.width, height: layout.screen.height)
            }
            if frame > 0, part != .belowScreen, layout.isPortrait, let cutout = style.model?.cutout,
               cutout != .dynamicIsland || style.showsDynamicIsland {
                Cutout(kind: cutout, pixelsPerPoint: layout.pixelsPerPoint)
                    .frame(width: layout.screen.width, height: layout.screen.height, alignment: .top)
            }
        }
        .frame(width: layout.device.width, height: layout.device.height)
    }
}

/// Screenshots don't include the notch or the Dynamic Island, so frames draw them.
private struct Cutout: View {
    let kind: DeviceModel.Cutout
    let pixelsPerPoint: CGFloat

    var body: some View {
        switch kind {
        case .dynamicIsland:
            // Same size on every model: 126 × 37 pt, 11 pt from the top.
            Capsule()
                .fill(.black)
                .frame(width: 126 * pixelsPerPoint, height: 37 * pixelsPerPoint)
                .padding(.top, 11 * pixelsPerPoint)
        case .notch(let width, let height):
            UnevenRoundedRectangle(
                bottomLeadingRadius: height * 0.65 * pixelsPerPoint,
                bottomTrailingRadius: height * 0.65 * pixelsPerPoint,
                style: .continuous
            )
            .fill(.black)
            .frame(width: width * pixelsPerPoint, height: height * pixelsPerPoint)
        }
    }
}

/// Action button and volume buttons on the left, side button on the right.
private struct SideButtons: View {
    let layout: CompositionLayout
    let colors: [Color]

    var body: some View {
        let height = layout.device.height
        let color = LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
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
