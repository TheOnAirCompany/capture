import AVFoundation
import CoreMediaIO
import Observation

/// Discovers iPhones connected over USB and exposes them as capture devices.
///
/// When a Mac opens the screen stream of a connected iPhone, iOS switches its
/// status bar to demo mode (9:41, full battery, full signal).
///
/// With several iPhones connected, the one chosen last is shown, and it is picked
/// again automatically when it is plugged back in.
@Observable
final class DeviceManager {
    /// The iPhone being shown.
    private(set) var device: AVCaptureDevice?
    /// Every connected iPhone.
    private(set) var devices: [AVCaptureDevice] = []
    /// True while a screenshot or a recording is in progress: the iPhone can't change.
    var isLocked = false {
        didSet { if !isLocked { refreshDevices() } }
    }
    private(set) var cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
    /// Native pixel size of the iPhone screen, known once the first frame arrives.
    private(set) var screenSize: CGSize?

    let previewSession = PreviewSession()

    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var isStreaming = false
    @ObservationIgnored private var preferredDeviceID = UserDefaults.standard.string(forKey: "preferredDeviceID") {
        didSet { UserDefaults.standard.set(preferredDeviceID, forKey: "preferredDeviceID") }
    }

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

    /// Shows another iPhone, and remembers it for next time.
    func select(_ newDevice: AVCaptureDevice) {
        guard !isLocked else { return }
        preferredDeviceID = newDevice.uniqueID
        show(newDevice)
    }

    private func refreshDevices() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external],
            mediaType: .muxed,
            position: .unspecified
        )
        let connected = discovery.devices.filter(\.isConnected)
        devices = connected

        let target: AVCaptureDevice?
        if isLocked, let device, let current = connected.first(where: { $0.uniqueID == device.uniqueID }) {
            // Keep the iPhone being captured, even if the preferred one comes back.
            target = current
        } else {
            target = connected.first { $0.uniqueID == preferredDeviceID }
                ?? connected.first { $0.uniqueID == device?.uniqueID }
                ?? connected.first
        }
        show(target)
    }

    private func show(_ target: AVCaptureDevice?) {
        let shouldStream = target != nil && isCameraAuthorized
        // Camera access can be granted while the iPhone is already connected.
        guard target?.uniqueID != device?.uniqueID || shouldStream != isStreaming else { return }

        device = target
        isStreaming = shouldStream
        screenSize = nil
        if let target, shouldStream {
            previewSession.start(with: target)
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
