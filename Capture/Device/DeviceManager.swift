import AVFoundation
import CoreMediaIO
import Observation

/// Discovers iPhones connected over USB and exposes them as capture devices.
///
/// When a Mac opens the screen stream of a connected iPhone, iOS switches its
/// status bar to demo mode (9:41, full battery, full signal, no notifications).
@Observable
final class DeviceManager {
    private(set) var device: AVCaptureDevice?
    private(set) var cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
    /// Native pixel size of the iPhone screen, known once the first frame arrives.
    private(set) var screenSize: CGSize?

    let previewSession = PreviewSession()

    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var isStreaming = false

    init() {
        Self.allowScreenCaptureDevices()
        previewSession.onScreenSizeChange = { [weak self] size in self?.screenSize = size }

        let center = NotificationCenter.default
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshDevices() }
            })
        }
        refreshDevices()
    }

    var isCameraAuthorized: Bool { cameraAuthorization == .authorized }

    func requestCameraAccess() async {
        _ = await AVCaptureDevice.requestAccess(for: .video)
        cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
        refreshDevices()
    }

    func refreshCameraAuthorization() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status != cameraAuthorization else { return }
        cameraAuthorization = status
        refreshDevices()
    }

    private func refreshDevices() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external],
            mediaType: .muxed,
            position: .unspecified
        )
        let connected = discovery.devices.first { $0.isConnected }
        let shouldStream = connected != nil && isCameraAuthorized
        // Camera access can be granted while the iPhone is already connected.
        guard connected?.uniqueID != device?.uniqueID || shouldStream != isStreaming else { return }

        device = connected
        isStreaming = shouldStream
        screenSize = nil
        if let connected, shouldStream {
            previewSession.start(with: connected)
        } else {
            previewSession.stop()
        }
    }

    /// iOS devices are hidden from AVFoundation until the process opts in,
    /// which is what QuickTime Player does under the hood.
    private static func allowScreenCaptureDevices() {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var allow: UInt32 = 1
        CMIOObjectSetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil,
            UInt32(MemoryLayout.size(ofValue: allow)), &allow
        )
    }
}
