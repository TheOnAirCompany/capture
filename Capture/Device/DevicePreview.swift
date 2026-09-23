import AVFoundation
import SwiftUI

/// Live view of the iPhone screen, scaled to fit the available space.
struct DevicePreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        return view
    }

    func updateNSView(_ view: PreviewView, context: Context) {
        view.previewLayer.session = session
    }

    final class PreviewView: NSView {
        let previewLayer = AVCaptureVideoPreviewLayer()

        init() {
            super.init(frame: .zero)
            previewLayer.videoGravity = .resizeAspect
            wantsLayer = true
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func makeBackingLayer() -> CALayer { previewLayer }
    }
}
