import SwiftUI

struct SettingsView: View {
    @Environment(CaptureLibrary.self) private var library
    @State private var folder = CaptureFolder.url
    @State private var folderError: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Folder") {
                    HStack(spacing: 8) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: folder.path))
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text(verbatim: CaptureFolder.displayPath(of: folder))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                HStack {
                    Spacer()
                    Button("Show in Finder") { NSWorkspace.shared.open(folder) }
                    Button("Change…", action: changeFolder)
                }
                if let folderError {
                    Text(verbatim: folderError)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Save Location")
            } footer: {
                Text("Screenshots and videos are saved in this folder.")
            }

            Section {
                LabeledContent("Demo Mode") {
                    Label("Automatic", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("While Capture displays your iPhone, iOS switches its status bar to demo mode: 9:41, full battery and full signal.")
                    Text("Your screenshots and videos look clean and consistent, like Apple's own product shots, whatever the real time or battery level. No retouching needed, and nothing personal shows up in the status bar.")
                    Text("iOS controls this mode: it turns on when Capture starts displaying your iPhone and turns off when you disconnect it. It can't be turned off from the Mac.")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Status Bar")
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
    }

    /// Accessing the folder right away makes macOS ask for permission now.
    private func changeFolder() {
        guard let url = CaptureFolder.choose(startingAt: folder) else { return }
        do {
            try CaptureFolder.prepare(url)
            CaptureFolder.url = url
            folder = url
            folderError = nil
            library.reload()
        } catch {
            folderError = String(localized: "Capture can't access this folder. Choose another one, or allow access in System Settings > Privacy & Security > Files and Folders.")
        }
    }
}
