import AppKit
import Observation

/// Takes screenshots and records videos of the connected iPhone into the capture folder.
@Observable
final class CaptureController {
    private(set) var recordingStartDate: Date?
    private(set) var screenshotCount = 0
    var errorMessage: String?

    var isRecording: Bool { recordingStartDate != nil }

    private let deviceManager: DeviceManager
    private let library: CaptureLibrary

    init(deviceManager: DeviceManager, library: CaptureLibrary) {
        self.deviceManager = deviceManager
        self.library = library
    }

    func takeScreenshot() {
        let session = deviceManager.previewSession
        let format = Preferences.captureFormat, scale = Preferences.captureScale.value
        do {
            let url = try nextFileURL(extension: format.contentType.preferredFilenameExtension ?? "png", isVideo: false)
            deviceManager.isLocked = true
            Task.detached(priority: .userInitiated) {
                defer { Task { @MainActor in self.deviceManager.isLocked = self.isRecording } }
                do {
                    try session.writeScreenshot(to: url, format: format, scale: scale)
                    await MainActor.run {
                        self.screenshotCount += 1
                        self.library.reload()
                        NSSound(named: "Grab")?.play()
                    }
                } catch {
                    await MainActor.run { self.errorMessage = error.localizedDescription }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleRecording() {
        if isRecording {
            recordingStartDate = nil
            deviceManager.previewSession.stopRecording { error in
                Task { @MainActor in
                    self.deviceManager.isLocked = false
                    self.library.reload()
                    if let error { self.errorMessage = error.localizedDescription }
                }
            }
            return
        }
        do {
            try deviceManager.previewSession.startRecording(
                to: try nextFileURL(extension: "mov", isVideo: true),
                recordsSound: Preferences.recordsSound
            )
            recordingStartDate = .now
            deviceManager.isLocked = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openOutputFolder() {
        let folder = CaptureFolder.url
        try? CaptureFolder.prepare(folder)
        NSWorkspace.shared.open(folder)
    }

    /// Builds the file name from the naming template, in the subfolder chosen in Settings.
    private func nextFileURL(extension pathExtension: String, isVideo: Bool) throws -> URL {
        let now = Date.now
        let deviceName = deviceManager.device?.localizedName ?? "iPhone"
        let baseName = Preferences.fileName(
            template: Preferences.fileNameTemplate,
            device: deviceName,
            date: now,
            counter: Preferences.nextCounter(),
            isVideo: isVideo
        )

        var folder = CaptureFolder.url
        switch Preferences.folderOrganization {
        case .none: break
        case .date: folder.append(path: Preferences.fileName(template: "{date}", device: deviceName, date: now, counter: 0, isVideo: isVideo))
        case .device: folder.append(path: Preferences.fileName(template: "{device}", device: deviceName, date: now, counter: 0, isVideo: isVideo))
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var url = folder.appending(path: "\(baseName).\(pathExtension)")
        var index = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appending(path: "\(baseName) (\(index)).\(pathExtension)")
            index += 1
        }
        return url
    }
}
