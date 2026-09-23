import SwiftUI

@main
struct CaptureApp: App {
    @State private var deviceManager = DeviceManager()

    var body: some Scene {
        Window("Capture", id: "main") {
            MainView()
                .environment(deviceManager)
                .frame(minWidth: 860, minHeight: 600)
        }
        .defaultSize(width: 1180, height: 780)
        .windowToolbarStyle(.unified)
    }
}
