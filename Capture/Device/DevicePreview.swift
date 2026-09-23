import AVFoundation
import SwiftUI

/// Live view of the iPhone screen, with the rounded corners of its display.
struct DevicePreview: NSViewRepresentable {
    let session: PreviewSession
    /// Native pixel size of the iPhone screen, used to match its corner radius.
    let screenSize: CGSize?

    func makeNSView(context: Context) -> PreviewView {
        PreviewView(session: session)
    }

    func updateNSView(_ view: PreviewView, context: Context) {
        view.cornerRatio = DisplayCorners.ratio(for: screenSize)
    }

    final class PreviewView: NSView {
        private let session: PreviewSession
        private let displayLayer = AVSampleBufferDisplayLayer()

        /// Corner radius as a fraction of the shorter side of the screen.
        var cornerRatio: CGFloat = DisplayCorners.fallbackRatio {
            didSet { updateLayerFrame() }
        }

        init(session: PreviewSession) {
            self.session = session
            super.init(frame: .zero)
            // A layer-hosting view: AppKit leaves the corner radius and mask alone.
            layer = CALayer()
            wantsLayer = true
            displayLayer.videoGravity = .resizeAspect
            displayLayer.cornerCurve = .continuous
            displayLayer.masksToBounds = true
            layer?.addSublayer(displayLayer)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            updateLayerFrame()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                session.addDisplay(displayLayer)
            } else {
                session.removeDisplay(displayLayer)
            }
        }

        private func updateLayerFrame() {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            displayLayer.frame = bounds
            displayLayer.cornerRadius = min(bounds.width, bounds.height) * cornerRatio
            CATransaction.commit()
        }
    }
}

/// Display corner radii of iPhone models, looked up by native screen width in pixels.
enum DisplayCorners {
    static let fallbackRatio: CGFloat = 55 * 3 / 1179

    /// Screen width in pixels → (corner radius in points, scale factor).
    /// Values from UIScreen's display corner radius on each model.
    private static let radii: [Int: (points: CGFloat, scale: CGFloat)] = [
        640: (0, 2),       // iPhone SE (1st generation)
        750: (0, 2),       // iPhone 6 to 8, SE (2nd and 3rd generation)
        828: (41.5, 2),    // iPhone XR, 11
        1080: (44, 3),     // iPhone 12 mini, 13 mini
        1125: (39, 3),     // iPhone X, XS, 11 Pro
        1242: (39, 3),     // iPhone XS Max, 11 Pro Max
        1170: (47.33, 3),  // iPhone 12, 12 Pro, 13, 13 Pro, 14, 16e
        1284: (53.33, 3),  // iPhone 12 Pro Max, 13 Pro Max, 14 Plus
        1179: (55, 3),     // iPhone 14 Pro, 15, 15 Pro, 16
        1290: (55, 3),     // iPhone 14 Pro Max, 15 Plus, 15 Pro Max, 16 Plus
        1206: (62, 3),     // iPhone 16 Pro, 17, 17 Pro, 18 Pro
        1260: (62, 3),     // iPhone Air
        1320: (62, 3),     // iPhone 16 Pro Max, 17 Pro Max, 18 Pro Max
    ]

    /// Screen widths of models with a Dynamic Island (iPhone 14 Pro and later).
    private static let dynamicIslandWidths: Set<Int> = [1179, 1206, 1260, 1290, 1320]

    /// Screenshots don't include the Dynamic Island, so device frames draw it.
    static func hasDynamicIsland(_ screenSize: CGSize) -> Bool {
        dynamicIslandWidths.contains(Int(min(screenSize.width, screenSize.height)))
    }

    /// Home button models have square displays and no device frame.
    static func hasRoundedDisplay(_ screenSize: CGSize) -> Bool {
        ratio(for: screenSize) > 0
    }

    static func ratio(for screenSize: CGSize?) -> CGFloat {
        guard let screenSize, screenSize.width > 0, screenSize.height > 0 else { return fallbackRatio }
        let width = min(screenSize.width, screenSize.height)
        guard let radius = radii[Int(width)] else { return fallbackRatio }
        return radius.points * radius.scale / width
    }
}
