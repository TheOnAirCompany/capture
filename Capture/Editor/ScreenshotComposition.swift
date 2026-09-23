import SwiftUI

/// How the device is held. The frame is drawn in portrait, then turned.
nonisolated enum DeviceOrientation: String, CaseIterable, Identifiable, Sendable {
    case automatic, portrait, landscapeLeft, landscapeRight, upsideDown

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .automatic: "Automatic"
        case .portrait: "Portrait"
        case .landscapeLeft: "Landscape Left"
        case .landscapeRight: "Landscape Right"
        case .upsideDown: "Upside Down"
        }
    }

    /// Picks portrait or landscape from the shape of the capture.
    func resolved(for image: CGSize) -> DeviceOrientation {
        guard self == .automatic else { return self }
        return image.width > image.height ? .landscapeLeft : .portrait
    }

    /// Clockwise rotation of the device, in quarter turns. Landscape left puts the top on the left.
    var quarterTurns: Int {
        switch self {
        case .automatic, .portrait: 0
        case .landscapeRight: 1
        case .upsideDown: 2
        case .landscapeLeft: 3
        }
    }

    var isLandscape: Bool { quarterTurns % 2 == 1 }
}

/// Shape of the exported image or video.
nonisolated enum CanvasRatio: String, CaseIterable, Identifiable, Sendable {
    case automatic, square, portrait, landscape

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .automatic: "Auto"
        case .square: "1:1"
        case .portrait: "9:16"
        case .landscape: "16:9"
        }
    }

    /// Width divided by height, or nil to fit the device.
    var value: CGFloat? {
        switch self {
        case .automatic: nil
        case .square: 1
        case .portrait: 9.0 / 16
        case .landscape: 16.0 / 9
        }
    }
}

struct CompositionStyle: Equatable {
    var model: DeviceModel?
    var showsBezel: Bool
    var finish: DeviceFinish?
    var showsDynamicIsland = true
    var orientation = DeviceOrientation.automatic
    var ratio = CanvasRatio.automatic
    var background: CompositionBackground
    /// Space around the device, as a fraction of the device's longer side.
    var margin: Double
    var showsShadow: Bool
}

/// Sizes of a composed capture, in pixels of the device screen.
/// The device is laid out in portrait, then turned by `orientation`.
struct CompositionLayout {
    let orientation: DeviceOrientation
    /// Portrait screen size.
    let screen: CGSize
    let screenRadius: CGFloat
    /// Pixels per point of the device, to size the notch or Dynamic Island.
    let pixelsPerPoint: CGFloat
    /// Black border on the long sides, and on the short sides (thicker on iPads with a Home button).
    let border: CGFloat
    let endBorder: CGFloat
    let band: CGFloat
    let buttonDepth: CGFloat
    /// Outer corner radius of the device.
    let bodyRadius: CGFloat
    /// Portrait device size.
    let device: CGSize
    let canvas: CGSize
    /// Clockwise quarter turns that show the capture upright on the turned device.
    let contentTurns: Int
    let isCaptureLandscape: Bool

    init(image: CGSize, style: CompositionStyle) {
        orientation = style.orientation.resolved(for: image)
        isCaptureLandscape = image.width > image.height
        let hasBezel = style.showsBezel && style.model != nil
        let portraitImage = isCaptureLandscape ? CGSize(width: image.height, height: image.width) : image

        // With a frame, the screen takes the size of the chosen model.
        if hasBezel, let model = style.model {
            screen = model.screen
        } else {
            screen = portraitImage
        }
        let shortSide = screen.width
        if let model = style.model {
            screenRadius = shortSide * model.cornerRadius * model.scale / model.screen.width
            pixelsPerPoint = shortSide / (model.screen.width / model.scale)
        } else {
            screenRadius = shortSide * DisplayCorners.ratio(for: image)
            pixelsPerPoint = 3
        }

        let isIPad = style.model?.family == .iPad
        let hasHomeButton = style.model?.hasHomeButton == true
        switch (hasBezel, isIPad, hasHomeButton) {
        case (false, _, _):
            (border, endBorder, band, buttonDepth) = (0, 0, 0, 0)
        case (true, true, true):
            (border, endBorder, band, buttonDepth) = (shortSide * 0.075, shortSide * 0.14, shortSide * 0.008, shortSide * 0.004)
        case (true, true, false):
            (border, endBorder, band, buttonDepth) = (shortSide * 0.045, shortSide * 0.045, shortSide * 0.009, shortSide * 0.004)
        case (true, false, _):
            (border, endBorder, band, buttonDepth) = (shortSide * 0.030, shortSide * 0.030, shortSide * 0.021, shortSide * 0.007)
        }
        bodyRadius = hasHomeButton ? shortSide * 0.075 : screenRadius + border + band

        device = CGSize(width: screen.width + 2 * (border + band + buttonDepth), height: screen.height + 2 * (endBorder + band))

        // A capture that matches the device orientation stays upright. Otherwise it is
        // shown as it would be on the turned device: sideways.
        let netTurns = isCaptureLandscape == orientation.isLandscape ? 0 : (orientation.isLandscape ? orientation.quarterTurns : 1)
        contentTurns = ((netTurns - orientation.quarterTurns) % 4 + 4) % 4

        let bounds = orientation.isLandscape ? CGSize(width: device.height, height: device.width) : device
        let margin = max(bounds.width, bounds.height) * style.margin
        var canvas = CGSize(width: bounds.width + 2 * margin, height: bounds.height + 2 * margin)
        if let ratio = style.ratio.value {
            if canvas.width / canvas.height < ratio {
                canvas.width = canvas.height * ratio
            } else {
                canvas.height = canvas.width / ratio
            }
        }
        self.canvas = canvas
    }

    /// Size of the turned device.
    var deviceBounds: CGSize {
        orientation.isLandscape ? CGSize(width: device.height, height: device.width) : device
    }

    /// The screen in the canvas, top-left origin. The device is centered and symmetric.
    var screenRect: CGRect {
        let size = orientation.isLandscape ? CGSize(width: screen.height, height: screen.width) : screen
        return CGRect(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    /// Clockwise quarter turns of the capture as seen in the canvas.
    var netContentTurns: Int { (contentTurns + orientation.quarterTurns) % 4 }
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
                    radius: layout.screen.width * 0.035,
                    y: layout.screen.width * 0.02
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
        let front = style.finish?.hasWhiteFront == true ? Color(white: 0.95) : Color.black
        return ZStack {
            if frame > 0, part != .aboveScreen {
                SideButtons(layout: layout, colors: bandColors, family: style.model?.family ?? .iPhone)
                RoundedRectangle(cornerRadius: layout.bodyRadius, style: .continuous)
                    .fill(LinearGradient(colors: bandColors, startPoint: .leading, endPoint: .trailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: layout.bodyRadius, style: .continuous)
                            .strokeBorder(.black.opacity(0.25), lineWidth: layout.band * 0.12)
                    )
                    .padding(.horizontal, layout.buttonDepth)
                RoundedRectangle(cornerRadius: layout.bodyRadius - layout.band, style: .continuous)
                    .fill(front)
                    .padding(.horizontal, layout.buttonDepth + layout.band)
                    .padding(.vertical, layout.band)
                if let model = style.model, model.family == .iPad {
                    TabletDetails(layout: layout, model: model, front: front)
                }
            }
            if let image {
                screenContent(image, layout: layout)
                    .clipShape(RoundedRectangle(cornerRadius: layout.screenRadius, style: .continuous))
            } else if part == .belowScreen {
                RoundedRectangle(cornerRadius: layout.screenRadius, style: .continuous)
                    .fill(.black)
                    .frame(width: layout.screen.width, height: layout.screen.height)
            }
            if frame > 0, part != .belowScreen, let cutout = style.model?.cutout,
               !cutout.isDynamicIsland || style.showsDynamicIsland {
                Cutout(kind: cutout, pixelsPerPoint: layout.pixelsPerPoint)
                    .frame(width: layout.screen.width, height: layout.screen.height, alignment: .top)
            }
        }
        .frame(width: layout.device.width, height: layout.device.height)
        .rotationEffect(.degrees(Double(layout.orientation.quarterTurns) * 90))
        .frame(width: layout.deviceBounds.width, height: layout.deviceBounds.height)
    }

    /// The capture filling the portrait screen, turned to read correctly on the turned device.
    private func screenContent(_ image: CGImage, layout: CompositionLayout) -> some View {
        let turned = layout.contentTurns % 2 == 1
        let size = turned ? CGSize(width: layout.screen.height, height: layout.screen.width) : layout.screen
        return Image(decorative: image, scale: 1)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
            .rotationEffect(.degrees(Double(layout.contentTurns) * 90))
            .frame(width: layout.screen.width, height: layout.screen.height)
    }
}

/// Screenshots don't include the notch or the Dynamic Island, so frames draw them.
private struct Cutout: View {
    let kind: DeviceModel.Cutout
    let pixelsPerPoint: CGFloat

    var body: some View {
        switch kind {
        case .dynamicIsland(let top, let height):
            Capsule()
                .fill(.black)
                .frame(width: 126 * pixelsPerPoint, height: height * pixelsPerPoint)
                .padding(.top, top * pixelsPerPoint)
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

/// The front camera, and the Home button on older iPads, drawn in the border.
private struct TabletDetails: View {
    let layout: CompositionLayout
    let model: DeviceModel
    let front: Color

    var body: some View {
        let short = layout.screen.width
        ZStack {
            Circle()
                .fill(Color(white: 0.18))
                .frame(width: short * 0.012, height: short * 0.012)
                // Landscape cameras sit on the long edge that is on top in landscape left.
                .offset(model.hasLandscapeCamera
                        ? CGSize(width: (layout.screen.width + layout.border) / 2, height: 0)
                        : CGSize(width: 0, height: -(layout.screen.height + layout.endBorder) / 2))
            if model.hasHomeButton {
                Circle()
                    .fill(front)
                    .overlay(Circle().strokeBorder(Color.gray.opacity(0.45), lineWidth: short * 0.003))
                    .frame(width: short * 0.075, height: short * 0.075)
                    .offset(y: (layout.screen.height + layout.endBorder) / 2)
            }
        }
    }
}

/// iPhone: Action button and volume buttons on the left, side button on the right.
/// iPad: volume buttons on the right, near the top.
private struct SideButtons: View {
    let layout: CompositionLayout
    let colors: [Color]
    let family: DeviceModel.Family

    var body: some View {
        let height = layout.device.height
        let color = LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
        ZStack(alignment: .topLeading) {
            Color.clear
            if layout.buttonDepth > 0 {
                switch family {
                case .iPhone:
                    button(at: 0.185, length: 0.035, leading: true, fill: color)
                    button(at: 0.245, length: 0.062, leading: true, fill: color)
                    button(at: 0.325, length: 0.062, leading: true, fill: color)
                    button(at: 0.27, length: 0.105, leading: false, fill: color)
                case .iPad:
                    button(at: 0.07, length: 0.04, leading: false, fill: color)
                    button(at: 0.12, length: 0.04, leading: false, fill: color)
                }
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
