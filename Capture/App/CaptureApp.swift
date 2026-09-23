import SwiftUI

@main
struct CaptureApp: App {
    @State private var deviceManager: DeviceManager
    @State private var captureController: CaptureController
    @State private var library: CaptureLibrary
    @State private var exportSettings = ExportSettings()
    @State private var updater = AppUpdater()

    init() {
        LaunchArguments.apply()
        let deviceManager = DeviceManager()
        let library = CaptureLibrary()
        _deviceManager = State(initialValue: deviceManager)
        _library = State(initialValue: library)
        _captureController = State(initialValue: CaptureController(deviceManager: deviceManager, library: library))
    }

    var body: some Scene {
        Window("Capture", id: "main") {
            MainView()
                .onAppear { Preferences.appearance.apply() }
                .environment(deviceManager)
                .environment(captureController)
                .environment(library)
                .environment(exportSettings)
                .environment(updater)
                .frame(minWidth: 860, minHeight: 600)
        }
        .defaultSize(width: 1180, height: 780)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…", action: updater.checkForUpdates)
                    .disabled(!updater.canCheckForUpdates)
            }
            CaptureCommands(captureController: captureController, deviceManager: deviceManager, library: library)
        }
    }
}

private struct CaptureCommands: Commands {
    let captureController: CaptureController
    let deviceManager: DeviceManager
    let library: CaptureLibrary
    @AppStorage(CaptureImporter.enabledKey) private var importEnabled = false

    var body: some Commands {
        CommandMenu("Capture") {
            Group {
                Button("Take Screenshot") { captureController.takeScreenshot() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Button {
                    captureController.toggleRecording()
                } label: {
                    if captureController.isRecording { Text("Stop Recording") } else { Text("Record Video") }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            .disabled(deviceManager.device == nil || !deviceManager.isCameraAuthorized)
            Divider()
            Button("Open Capture Folder") { captureController.openOutputFolder() }
            if importEnabled {
                Button("Import…") { CaptureImporter.chooseAndImport(into: library) }
                    .keyboardShortcut("i", modifiers: .command)
            }
        }
    }
}
