import AppKit
import SwiftUI

/// First-launch walkthrough: pitch, features, save location, then camera permission.
struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(DeviceManager.self) private var deviceManager
    @State private var page: Page = .welcome
    @State private var folder = CaptureFolder.url
    @State private var folderError: String?

    enum Page: Int, CaseIterable {
        case welcome, features, location, permission
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case .welcome: WelcomePage()
                case .features: FeaturesPage()
                case .location: LocationPage(folder: $folder, error: $folderError)
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
        if page == .location {
            Button("Continue", action: confirmFolder)
        } else if page != .permission {
            Button("Continue") { move(by: 1) }
        } else if deviceManager.cameraAuthorization == .notDetermined {
            Button("Allow Access") {
                Task { await deviceManager.requestCameraAccess() }
            }
        } else {
            Button("Get Started", action: onFinish)
        }
    }

    /// Creating the folder now triggers the macOS access prompt in context.
    private func confirmFolder() {
        do {
            try CaptureFolder.prepare(folder)
            CaptureFolder.url = folder
            folderError = nil
            move(by: 1)
        } catch {
            folderError = String(localized: "Capture can't access this folder. Choose another one, or allow access in System Settings > Privacy & Security > Files and Folders.")
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
                Text("Take pixel-perfect screenshots and screen recordings of your iPhone and iPad, with the clean 9:41 status bar Apple uses in its own product shots.")
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
            Text("Built for clean iPhone and iPad captures")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    systemImage: "camera.viewfinder",
                    title: "Screenshots",
                    message: "Capture your iPhone or iPad screen in one click, at full native resolution."
                )
                FeatureRow(
                    systemImage: "record.circle",
                    title: "Screen Recordings",
                    message: "Record videos with sound, straight from your iPhone or iPad."
                )
                FeatureRow(
                    systemImage: "clock.badge.checkmark",
                    title: "A Perfect Status Bar",
                    message: "9:41, full battery and full signal, automatically."
                )
                FeatureRow(
                    systemImage: "iphone.gen3",
                    title: "Device Frames",
                    message: "Add an iPhone or iPad frame to your captures when you edit them."
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

private struct LocationPage: View {
    @Binding var folder: URL
    @Binding var error: String?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "folder")
                .font(.system(size: 80, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .frame(height: 120)

            VStack(spacing: 12) {
                Text("Choose Where to Save")
                    .font(.largeTitle.bold())
                Text("Your screenshots and videos will be saved in this folder.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(for: .folder))
                    .resizable()
                    .frame(width: 32, height: 32)
                Text(verbatim: CaptureFolder.displayPath(of: folder))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Change…") {
                    if let url = CaptureFolder.choose(startingAt: folder) {
                        folder = url
                        error = nil
                    }
                }
            }
            .padding(12)
            .background(.background.secondary, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))

            if let error {
                Text(verbatim: error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 56)
        .padding(.top, 24)
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
                Text("macOS treats the screen of your iPhone or iPad like a camera. Capture needs this access to display and record it.")
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
