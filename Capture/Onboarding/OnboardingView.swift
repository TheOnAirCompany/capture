import AppKit
import SwiftUI

/// First-launch walkthrough: pitch, features, then camera permission.
struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(DeviceManager.self) private var deviceManager
    @State private var page: Page = .welcome

    enum Page: Int, CaseIterable {
        case welcome, features, permission
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case .welcome: WelcomePage()
                case .features: FeaturesPage()
                case .permission: PermissionPage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.blurReplace)

            footer
        }
        .frame(width: 580, height: 640)
    }

    private var footer: some View {
        ZStack {
            PageIndicator(count: Page.allCases.count, current: page.rawValue)

            HStack {
                if page != .welcome {
                    Button("Back") { move(by: -1) }
                        .controlSize(.large)
                }
                Spacer()
                primaryButton
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }

    @ViewBuilder
    private var primaryButton: some View {
        if page != .permission {
            Button("Continue") { move(by: 1) }
        } else if deviceManager.cameraAuthorization == .notDetermined {
            Button("Allow Access") {
                Task { await deviceManager.requestCameraAccess() }
            }
        } else {
            Button("Get Started", action: onFinish)
        }
    }

    private func move(by offset: Int) {
        guard let next = Page(rawValue: page.rawValue + offset) else { return }
        withAnimation(.smooth) { page = next }
    }
}

private struct PageIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary))
                    .frame(width: 7, height: 7)
            }
        }
        .animation(.smooth, value: current)
        .accessibilityHidden(true)
    }
}

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 160, height: 160)

            VStack(spacing: 12) {
                Text("Welcome to Capture")
                    .font(.largeTitle.bold())
                Text("Take pixel-perfect screenshots and screen recordings of your iPhone, with the clean 9:41 status bar Apple uses in its own product shots.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Everything QuickTime does, only faster and more powerful.")
                    .font(.title3)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 56)
        .padding(.top, 24)
    }
}

private struct FeaturesPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Built for clean iPhone captures")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    systemImage: "camera.viewfinder",
                    title: "Screenshots",
                    message: "Capture your iPhone screen in one click, at full native resolution."
                )
                FeatureRow(
                    systemImage: "record.circle",
                    title: "Screen Recordings",
                    message: "Record videos with sound, straight from your iPhone."
                )
                FeatureRow(
                    systemImage: "clock.badge.checkmark",
                    title: "A Perfect Status Bar",
                    message: "9:41, full battery and full signal. Automatically, with no notifications."
                )
                FeatureRow(
                    systemImage: "iphone.gen3",
                    title: "Device Frames",
                    message: "Add an iPhone frame to your captures when you edit them."
                )
                FeatureRow(
                    systemImage: "clock.arrow.circlepath",
                    title: "Recents",
                    message: "Find all your captures in one place."
                )
            }
        }
        .padding(.horizontal, 56)
        .padding(.top, 32)
    }
}

private struct FeatureRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 26))
                .foregroundStyle(.tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PermissionPage: View {
    @Environment(DeviceManager.self) private var deviceManager

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "video.badge.checkmark")
                .font(.system(size: 80, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .frame(height: 120)

            VStack(spacing: 12) {
                Text("Allow Camera Access")
                    .font(.largeTitle.bold())
                Text("macOS treats your iPhone's screen like a camera. Capture needs this access to display and record it.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Your captures never leave your Mac.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.center)

            status
        }
        .padding(.horizontal, 56)
        .padding(.top, 24)
    }

    @ViewBuilder
    private var status: some View {
        switch deviceManager.cameraAuthorization {
        case .authorized:
            Label("Access granted", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
        case .denied, .restricted:
            VStack(spacing: 8) {
                Text("Access was denied. You can turn it on in System Settings > Privacy & Security > Camera.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Open System Settings") { SystemSettings.openCameraPrivacy() }
                    .buttonStyle(.link)
            }
        default:
            EmptyView()
        }
    }
}
