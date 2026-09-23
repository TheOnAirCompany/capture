import AppKit
import SwiftUI

enum SidebarItem: Hashable, CaseIterable, Identifiable {
    case preview, screenshots, videos, settings

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .preview: "Preview"
        case .screenshots: "Screenshots"
        case .videos: "Videos"
        case .settings: "Settings"
        }
    }

    /// Window title, when it differs from the sidebar.
    var windowTitle: LocalizedStringResource {
        self == .videos ? "Video Editor" : title
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .preview: "See your iPhone screen live, then capture it."
        case .screenshots: "Frame, style and export your screenshots."
        case .videos: "Trim, adjust and export your videos."
        case .settings: "Customize your experience with Capture."
        }
    }

    var systemImage: String {
        switch self {
        case .preview: "display"
        case .screenshots: "camera"
        case .videos: "video"
        case .settings: "gearshape"
        }
    }
}

struct MainView: View {
    @Environment(DeviceManager.self) private var deviceManager
    @Environment(CaptureLibrary.self) private var library
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selection: SidebarItem = .preview

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            detail
                .navigationTitle(Text(selection.windowTitle))
                .navigationSubtitle(Text(selection.subtitle))
        }
        .sheet(isPresented: showsOnboarding) {
            OnboardingView { hasCompletedOnboarding = true }
                .interactiveDismissDisabled()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            deviceManager.refreshCameraAuthorization()
            library.reload()
        }
        .onAppear { library.reload() }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .preview:
            if !deviceManager.isCameraAuthorized {
                CameraAccessView()
            } else if deviceManager.isUnsupportedDevice {
                UnsupportedDeviceView()
            } else if deviceManager.device != nil {
                ConnectedView()
            } else {
                EmptyStateView()
            }
        case .screenshots:
            ScreenshotsView()
        case .videos:
            VideosView()
        case .settings:
            SettingsView()
        }
    }

    private var showsOnboarding: Binding<Bool> {
        Binding(get: { !hasCompletedOnboarding }, set: { hasCompletedOnboarding = !$0 })
    }
}

/// Shown when an iPad is connected: only iPhone is supported for now.
struct UnsupportedDeviceView: View {
    @Environment(DeviceManager.self) private var deviceManager

    var body: some View {
        ContentUnavailableView {
            Label("iPad Isn't Supported Yet", systemImage: "ipad.landscape")
        } description: {
            Text("Capture works with iPhone for now. Connect an iPhone with a USB cable to preview and capture its screen.")
        } actions: {
            if deviceManager.devices.count > 1 {
                Text("Choose an iPhone from the menu in the sidebar.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct CameraAccessView: View {
    @Environment(DeviceManager.self) private var deviceManager

    var body: some View {
        ContentUnavailableView {
            Label("Camera Access Required", systemImage: "video.slash")
        } description: {
            Text("Capture needs camera access to display your iPhone's screen.")
        } actions: {
            if deviceManager.cameraAuthorization == .notDetermined {
                Button("Allow Access") {
                    Task { await deviceManager.requestCameraAccess() }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Open System Settings") { SystemSettings.openCameraPrivacy() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

enum SystemSettings {
    static func openCameraPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
}
