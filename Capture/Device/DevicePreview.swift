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

/// Display corner radii, from the device catalog, as a fraction of the screen's shorter side.
enum DisplayCorners {
    static let fallbackRatio: CGFloat = 55 * 3 / 1179
    private static let tabletFallbackRatio: CGFloat = 18 * 2 / 1640

    /// Home button models have square displays.
    static func hasRoundedDisplay(_ screenSize: CGSize) -> Bool {
        ratio(for: screenSize) > 0
    }

    static func ratio(for screenSize: CGSize?) -> CGFloat {
        guard let screenSize, screenSize.width > 0, screenSize.height > 0 else { return fallbackRatio }
        // The newest model with this screen: all-screen iPads share sizes with older ones.
        if let model = DeviceModel.matching(screenSize).first {
            return model.cornerRadius * model.scale / model.screen.width
        }
        let isTablet = max(screenSize.width, screenSize.height) / min(screenSize.width, screenSize.height) < 1.6
        return isTablet ? tabletFallbackRatio : fallbackRatio
    }
}
