import AVFoundation

/// Owns the capture session that streams the iPhone screen.
/// Session changes run on a dedicated queue because `startRunning()` blocks.
nonisolated final class PreviewSession: @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.theonaircompany.capture.session")

    func start(with device: AVCaptureDevice) {
        nonisolated(unsafe) let device = device
        queue.async { [self] in
            session.beginConfiguration()
            session.inputs.forEach(session.removeInput)
            if let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
                session.addInput(input)
            }
            session.commitConfiguration()
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            session.stopRunning()
            session.beginConfiguration()
            session.inputs.forEach(session.removeInput)
            session.commitConfiguration()
        }
    }
}
