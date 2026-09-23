import AppKit
import SwiftUI

/// Shown until an iPhone is connected with a cable.
struct EmptyStateView: View {
    @State private var showsHelp = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                ConnectIllustration()

                VStack(spacing: 10) {
                    Text("Connect your iPhone")
                        .font(.largeTitle.bold())
                    Text("Plug your iPhone into this Mac with a USB cable to preview its screen, take screenshots and record videos.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 520)
                }

                HStack(spacing: 0) {
                    StepView(
                        systemImage: "cable.connector",
                        title: "Use a USB cable",
                        message: "Connect your iPhone to this Mac with a cable."
                    )
                    Divider().padding(.vertical, 20)
                    StepView(
                        systemImage: "sparkles",
                        title: "That's it!",
                        message: "Your iPhone will appear here automatically."
                    )
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 620)
                .background(.background.secondary, in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator))

                Button("Need Help?") { showsHelp.toggle() }
                    .buttonStyle(.link)
                    .popover(isPresented: $showsHelp, arrowEdge: .bottom) { HelpView() }
            }
            .padding(40)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(.center)
    }
}

/// Uses the `ConnectIllustration` image when the asset exists, SF Symbols otherwise.
private struct ConnectIllustration: View {
    var body: some View {
        if let image = NSImage(named: "ConnectIllustration") {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 420, maxHeight: 260)
        } else {
            Image(systemName: "laptopcomputer.and.iphone")
                .font(.system(size: 110, weight: .thin))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .frame(height: 160)
        }
    }
}

private struct StepView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .light))
                .frame(height: 36)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

private struct HelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your iPhone doesn't appear?")
                .font(.headline)
            tip("lock.open", "Unlock your iPhone and tap Trust when asked.")
            tip("cable.connector", "Use a data cable: some cables can only charge.")
            tip("arrow.triangle.2.circlepath", "Try unplugging your iPhone and plugging it back in.")
            tip("wifi.slash", "A cable is required: the clean status bar isn't available over Wi-Fi.")
        }
        .padding(20)
        .frame(width: 340)
    }

    private func tip(_ systemImage: String, _ text: LocalizedStringKey) -> some View {
        Label { Text(text).fixedSize(horizontal: false, vertical: true) } icon: {
            Image(systemName: systemImage).foregroundStyle(.secondary)
        }
    }
}
