import AppKit
import SwiftUI

/// Shown until an iPhone is connected with a cable.
struct EmptyStateView: View {
    @State private var showsHelp = false

    var body: some View {
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

            Button("Need Help?") { showsHelp = true }
                .buttonStyle(.link)
                .popover(isPresented: $showsHelp, arrowEdge: .bottom) { HelpView() }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

private struct HelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your iPhone doesn't appear?")
                .font(.headline)
            tip("lock.open", "Unlock your iPhone and tap Trust when asked.")
            tip("cable.connector", "Use a data cable: some cables can only charge.")
            tip("arrow.triangle.2.circlepath", "Try unplugging your iPhone and plugging it back in.")
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
