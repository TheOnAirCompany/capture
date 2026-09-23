import SwiftUI

@main
struct CaptureApp: App {
    @State private var deviceManager: DeviceManager
    @State private var captureController: CaptureController

    init() {
        let deviceManager = DeviceManager()
        _deviceManager = State(initialValue: deviceManager)
        _captureController = State(initialValue: CaptureController(deviceManager: deviceManager))
    }

    var body: some Scene {
        Window("Capture", id: "main") {
            MainView()
                .environment(deviceManager)
                .environment(captureController)
                .frame(minWidth: 860, minHeight: 600)
        }
        .defaultSize(width: 1180, height: 780)
        .windowToolbarStyle(.unified)
        .commands { CaptureCommands(captureController: captureController, deviceManager: deviceManager) }
    }
}

private struct CaptureCommands: Commands {
    let captureController: CaptureController
    let deviceManager: DeviceManager

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
        }
    }
}
