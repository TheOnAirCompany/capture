import SwiftUI

/// Settings laid out as cards: storage, data, default quality, appearance, advanced options and help.
struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                    GridRow {
                        StorageCard()
                        EraseCard()
                    }
                    GridRow {
                        QualityCard()
                        VStack(spacing: 16) {
                            AppearanceCard()
                            UpdatesCard()
                        }
                    }
                    GridRow {
                        AdvancedCard()
                            .gridCellColumns(2)
                    }
                    GridRow {
                        HelpCard()
                            .gridCellColumns(2)
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Cards

private struct SettingsCard<Content: View, Accessory: View>: View {
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .light))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                accessory
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background.secondary, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator))
    }
}

extension SettingsCard where Accessory == EmptyView {
    init(systemImage: String, title: LocalizedStringKey, subtitle: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(systemImage: systemImage, title: title, subtitle: subtitle, accessory: { EmptyView() }, content: content)
    }
}

/// A label on the left and its control on the right, like System Settings.
private struct SettingRow<Control: View>: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?
    @ViewBuilder var control: Control

    init(_ title: LocalizedStringKey, detail: LocalizedStringKey? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.detail = detail
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            control
                .labelsHidden()
                .toggleStyle(.switch)
                .frame(maxWidth: 240, alignment: .trailing)
        }
    }
}

private struct StorageCard: View {
    @Environment(CaptureLibrary.self) private var library
    @AppStorage(CaptureImporter.enabledKey) private var importEnabled = false
    @State private var folder = CaptureFolder.url
    @State private var folderError: String?
    @State private var folderClicks: [Date] = []
    @State private var showsImportNotice = false

    var body: some View {
        SettingsCard(
            systemImage: "folder",
            title: "Storage",
            subtitle: "Choose where your screenshots and recordings are saved."
        ) {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: folder.path))
                    .resizable()
                    .frame(width: 36, height: 36)
                    .onTapGesture(perform: countFolderClick)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: FileManager.default.displayName(atPath: folder.path))
                    Text(verbatim: (folder.path as NSString).abbreviatingWithTildeInPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 8)
                Button("Change…", action: changeFolder)
            }
            .padding(12)
            .background(.background, in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
            .contextMenu {
                Button("Show in Finder") { NSWorkspace.shared.open(folder) }
            }

            if let folderError {
                Text(verbatim: folderError)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .alert(importEnabled ? "Import Enabled" : "Import Disabled", isPresented: $showsImportNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            if importEnabled {
                Text("You can now import images and videos from your Mac, from the Screenshots and Videos tabs or the Capture menu. Your original files are copied, never modified.")
            } else {
                Text("Import is turned off.")
            }
        }
    }

    /// Five quick clicks on the folder icon turn import on or off.
    private func countFolderClick() {
        let now = Date.now
        folderClicks = folderClicks.filter { now.timeIntervalSince($0) < 2 } + [now]
        guard folderClicks.count >= 5 else { return }
        folderClicks = []
        importEnabled.toggle()
        showsImportNotice = true
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

private struct EraseCard: View {
    @Environment(CaptureLibrary.self) private var library
    @State private var confirms = false
    @State private var errorMessage: String?

    var body: some View {
        SettingsCard(
            systemImage: "trash",
            title: "Erase Data",
            subtitle: "Remove all the screenshots, recordings and exports made with Capture."
        ) {
            Button(role: .destructive) {
                confirms = true
            } label: {
                Label("Erase All…", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .controlSize(.large)
            .disabled(library.allItems.isEmpty)

            Text("Files are moved to the Trash. Other files in the folder are left untouched.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .confirmationDialog("Move all captures to the Trash?", isPresented: $confirms) {
            Button("Move to Trash", role: .destructive) {
                do {
                    try library.moveAllToTrash()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } message: {
            Text("\(library.allItems.count) files will be moved to the Trash.")
        }
        .alert("Couldn't Erase the Captures", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: errorMessage ?? "")
        }
    }
}

private struct QualityCard: View {
    @AppStorage(Preferences.Key.captureFormat) private var format: ExportFormat = .png
    @AppStorage(Preferences.Key.captureScale) private var scale: CaptureScale = .original
    @AppStorage(Preferences.Key.recordsSound) private var recordsSound = true

    var body: some View {
        SettingsCard(
            systemImage: "camera.viewfinder",
            title: "Default Quality",
            subtitle: "Settings applied to your next captures."
        ) {
            VStack(spacing: 12) {
                SettingRow("Format") {
                    Picker("Format", selection: $format) {
                        ForEach(ExportFormat.allCases) { Text($0.title).tag($0) }
                    }
                }
                SettingRow("Resolution") {
                    Picker("Resolution", selection: $scale) {
                        ForEach(CaptureScale.allCases) { Text($0.title).tag($0) }
                    }
                }
                SettingRow("Include Sound (Video)") {
                    Toggle("Include Sound (Video)", isOn: $recordsSound)
                }
            }
        }
    }
}

private struct AppearanceCard: View {
    @AppStorage(Preferences.Key.appearance) private var appearance: AppAppearance = .system

    var body: some View {
        SettingsCard(
            systemImage: "sun.max",
            title: "Appearance",
            subtitle: "Adapt the interface to your preferences."
        ) {
            SettingRow("Theme") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
            }
        }
        .onChange(of: appearance) { appearance.apply() }
    }
}

private struct AdvancedCard: View {
    @AppStorage(Preferences.Key.fileNaming) private var naming: FileNaming = .deviceAndDate
    @AppStorage(Preferences.Key.fileNameTemplate) private var template = Preferences.defaultCustomTemplate
    @AppStorage(Preferences.Key.folderOrganization) private var organization: FolderOrganization = .none
    @AppStorage(Preferences.Key.exportsToCaptureFolder) private var exportsToCaptureFolder = false

    var body: some View {
        SettingsCard(
            systemImage: "gearshape",
            title: "Advanced Options",
            subtitle: "Extra features for advanced users."
        ) {
            VStack(spacing: 12) {
                SettingRow("File Names", detail: "Example: \(example)") {
                    Picker("File Names", selection: $naming) {
                        ForEach(FileNaming.allCases) { Text($0.title).tag($0) }
                    }
                }
                if naming == .custom {
                    TemplateEditor(template: $template)
                }
                SettingRow("Organize By") {
                    Picker("Organize By", selection: $organization) {
                        ForEach(FolderOrganization.allCases) { Text($0.title).tag($0) }
                    }
                }
                SettingRow("Export to the Capture Folder", detail: "Exports are saved in the _Exports folder, without a dialog.") {
                    Toggle("Export to the Capture Folder", isOn: $exportsToCaptureFolder)
                }
            }
        }
    }

    private var example: String {
        let name = Preferences.fileName(
            template: naming.template ?? template, device: "iPhone", date: .now, counter: 1, isVideo: false
        )
        switch organization {
        case .none: return "\(name).png"
        case .date: return "\(Preferences.fileName(template: "{date}", device: "", date: .now, counter: 0, isVideo: false))/\(name).png"
        case .device: return "iPhone/\(name).png"
        }
    }
}

/// Text field for a custom file name, with buttons that insert variables.
private struct TemplateEditor: View {
    @Binding var template: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("File Name", text: $template)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
            HStack(spacing: 6) {
                ForEach(FileNameToken.allCases) { token in
                    Button {
                        template += (template.hasSuffix(" ") || template.isEmpty ? "" : " ") + token.placeholder
                    } label: {
                        Text(token.title)
                    }
                    .controlSize(.small)
                    .help(token.placeholder)
                }
            }
        }
    }
}

private struct UpdatesCard: View {
    @Environment(AppUpdater.self) private var updater

    var body: some View {
        @Bindable var updater = updater

        SettingsCard(
            systemImage: "arrow.triangle.2.circlepath",
            title: "Updates",
            subtitle: "Version \(AppUpdater.currentVersion) (\(AppUpdater.currentBuild))"
        ) {
            VStack(spacing: 12) {
                SettingRow("Check Automatically") {
                    Toggle("Check Automatically", isOn: $updater.checksAutomatically)
                }
                HStack {
                    if let lastCheck = updater.lastCheck {
                        Text("Last checked \(lastCheck, format: .relative(presentation: .named))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Check for Updates…", action: updater.checkForUpdates)
                        .disabled(!updater.canCheckForUpdates)
                }
            }
        }
    }
}

private struct HelpCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 22, weight: .light))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text("Help").font(.headline)
                Text("Need help? Read the documentation or contact us.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("View Documentation") { open("https://github.com/TheOnAirCompany/capture#readme") }
            Button("Contact Us") { open("mailto:contact+capture@theonair.company?subject=Capture") }
        }
        .padding(20)
        .background(.background.secondary, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator))
    }

    private func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}
