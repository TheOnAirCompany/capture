import AVFoundation
import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem

    var body: some View {
        List(selection: $selection) {
            DeviceHeader()
                .selectionDisabled()
                .padding(.bottom, 12)

            ForEach(SidebarItem.allCases) { item in
                Label { Text(item.title) } icon: { Image(systemName: item.systemImage) }
                    .tag(item)
            }
        }
    }
}

private struct DeviceHeader: View {
    @Environment(DeviceManager.self) private var deviceManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(deviceManager.device == nil ? .tertiary : .primary)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                if let device = deviceManager.device {
                    if deviceManager.devices.count > 1 {
                        DevicePicker(current: device)
                    } else {
                        Text(verbatim: device.localizedName)
                            .font(.headline)
                    }
                    HStack(spacing: 5) {
                        Circle().fill(.green).frame(width: 7, height: 7)
                        Text("Connected")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } else {
                    Text("No Device")
                        .font(.headline)
                    Text("Connect an iPhone to get started.")
                        .font(.subheadline)
                        .lineLimit(2, reservesSpace: true)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

/// Chooses between several connected iPhones. Locked during a capture or recording.
private struct DevicePicker: View {
    @Environment(DeviceManager.self) private var deviceManager
    let current: AVCaptureDevice

    var body: some View {
        Menu {
            ForEach(deviceManager.devices, id: \.uniqueID) { device in
                Button {
                    deviceManager.select(device)
                } label: {
                    if device.uniqueID == current.uniqueID {
                        Label { Text(verbatim: device.localizedName) } icon: { Image(systemName: "checkmark") }
                    } else {
                        Text(verbatim: device.localizedName)
                    }
                }
            }
        } label: {
            Text(verbatim: current.localizedName)
                .font(.headline)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(deviceManager.isLocked)
        .help(deviceManager.isLocked
              ? Text("You can't switch iPhones during a capture or a recording.")
              : Text("Choose which iPhone to show."))
    }
}
