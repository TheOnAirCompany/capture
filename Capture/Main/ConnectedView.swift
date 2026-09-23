import SwiftUI

/// Live preview of the connected iPhone with the capture controls.
struct ConnectedView: View {
    @Environment(DeviceManager.self) private var deviceManager
    @Environment(CaptureController.self) private var captureController
    @State private var flashes = false

    var body: some View {
        @Bindable var captureController = captureController

        VStack(spacing: 20) {
            DevicePreview(session: deviceManager.previewSession, screenSize: deviceManager.screenSize)
                .aspectRatio(deviceManager.screenSize ?? CGSize(width: 1179, height: 2556), contentMode: .fit)
                .opacity(flashes ? 0.2 : 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            CaptureControls()
        }
        .padding(24)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Open Capture Folder", systemImage: "folder") { captureController.openOutputFolder() }
            }
        }
        .onChange(of: captureController.screenshotCount) {
            flashes = true
            withAnimation(.easeOut(duration: 0.35)) { flashes = false }
        }
        .alert(
            "Couldn't Save the Capture",
            isPresented: Binding(get: { captureController.errorMessage != nil }, set: { if !$0 { captureController.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: captureController.errorMessage ?? "")
        }
    }
}

private struct CaptureControls: View {
    @Environment(CaptureController.self) private var captureController

    var body: some View {
        HStack(spacing: 36) {
            ControlButton(action: captureController.takeScreenshot) {
                Image(systemName: "camera.fill")
            } label: {
                Text("Screenshot")
            }

            ControlButton(action: captureController.toggleRecording) {
                if captureController.isRecording {
                    Image(systemName: "stop.fill").foregroundStyle(.red)
                } else {
                    Image(systemName: "circle.fill").foregroundStyle(.red)
                }
            } label: {
                if let start = captureController.recordingStartDate {
                    Text(timerInterval: start...Date.distantFuture, countsDown: false)
                        .monospacedDigit()
                        .foregroundStyle(.red)
                } else {
                    Text("Record Video")
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 14)
        .glassEffect(in: .rect(cornerRadius: 24))
    }
}

private struct ControlButton<Icon: View, Label: View>: View {
    let action: () -> Void
    @ViewBuilder let icon: Icon
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                icon
                    .font(.system(size: 20))
                    .frame(width: 48, height: 48)
                    .background(.background, in: .circle)
                    .overlay(Circle().strokeBorder(.separator))
                label
                    .font(.callout)
                    .frame(minWidth: 96)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
