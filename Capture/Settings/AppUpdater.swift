import Observation
import Sparkle

/// Checks for, downloads and installs new versions published as GitHub releases.
/// The feed and public key are set in Info.plist (`SUFeedURL`, `SUPublicEDKey`).
@Observable
final class AppUpdater: NSObject, SPUUpdaterDelegate {
    private(set) var canCheckForUpdates = false

    var checksAutomatically: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var lastCheck: Date? { controller.updater.lastUpdateCheckDate }

    @ObservationIgnored private var controller: SPUStandardUpdaterController!
    @ObservationIgnored private var observation: NSKeyValueObservation?

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        canCheckForUpdates = controller.updater.canCheckForUpdates
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] updater, _ in
            let value = updater.canCheckForUpdates
            Task { @MainActor in self?.canCheckForUpdates = value }
        }
    }

    /// Updates need a writable copy: from a disk image, offer to move to Applications first.
    func checkForUpdates() {
        guard AppMover.isInstalled || Self.isDevelopmentBuild else {
            AppMover.offerToMove(reason: String(localized: "Capture can only update itself from the Applications folder."))
            return
        }
        controller.checkForUpdates(nil)
    }

    /// Skips background checks outside the Applications folder, where installing would fail.
    nonisolated func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        let allowed = MainActor.assumeIsolated { AppMover.isInstalled || Self.isDevelopmentBuild }
        guard allowed || updateCheck == .updateInformation else {
            throw CocoaError(.featureUnsupported)
        }
    }

    private static var isDevelopmentBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}
