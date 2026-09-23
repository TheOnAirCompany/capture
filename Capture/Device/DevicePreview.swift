import AVFoundation
import SwiftUI

/// Live view of the iPhone screen, scaled to fit the available space.
struct DevicePreview: NSViewRepresentable {
    let session: PreviewSession

    func makeNSView(context: Context) -> PreviewView {
        PreviewView(session: session)
    }

    func updateNSView(_ view: PreviewView, context: Context) {}

    final class PreviewView: NSView {
        private let session: PreviewSession
        private let displayLayer = AVSampleBufferDisplayLayer()

        init(session: PreviewSession) {
            self.session = session
            super.init(frame: .zero)
            displayLayer.videoGravity = .resizeAspect
            displayLayer.cornerCurve = .continuous
            displayLayer.masksToBounds = true
            wantsLayer = true
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func makeBackingLayer() -> CALayer { displayLayer }

        override func layout() {
            super.layout()
            // Recent iPhones have rounded displays: about 55 pt for a 393 pt wide screen.
            displayLayer.cornerRadius = bounds.width * 0.14
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                session.addDisplay(displayLayer)
            } else {
                session.removeDisplay(displayLayer)
            }
        }
    }
}
