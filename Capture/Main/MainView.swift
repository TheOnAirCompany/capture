import AppKit
import SwiftUI

enum SidebarItem: Hashable, CaseIterable, Identifiable {
    case preview, screenshots, videos

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .preview: "Preview"
        case .screenshots: "Screenshots"
        case .videos: "Videos"
        }
    }

    var systemImage: String {
        switch self {
        case .preview: "display"
        case .screenshots: "camera"
        case .videos: "video"
        }
    }
}

struct MainView: View {
    @Environment(DeviceManager.self) private var deviceManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selection: SidebarItem = .preview

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            detail
                .navigationTitle(Text(selection.title))
        }
        .sheet(isPresented: showsOnboarding) {
            OnboardingView { hasCompletedOnboarding = true }
                .interactiveDismissDisabled()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            deviceManager.refreshCameraAuthorization()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .preview:
            if !deviceManager.isCameraAuthorized {
                CameraAccessView()
            } else if deviceManager.device != nil {
                ConnectedView()
            } else {
                EmptyStateView()
            }
        case .screenshots:
            ContentUnavailableView {
                Label("No Screenshots Yet", systemImage: "camera")
            } description: {
                Text("Screenshots you take will appear here.")
            }
        case .videos:
            ContentUnavailableView {
                Label("No Videos Yet", systemImage: "video")
            } description: {
                Text("Screen recordings you make will appear here.")
            }
        }
    }

    private var showsOnboarding: Binding<Bool> {
        Binding(get: { !hasCompletedOnboarding }, set: { hasCompletedOnboarding = !$0 })
    }
}

/// Live preview of the connected iPhone.
struct ConnectedView: View {
    @Environment(DeviceManager.self) private var deviceManager

    var body: some View {
        DevicePreview(session: deviceManager.previewSession.session)
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
