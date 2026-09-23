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
        do {
            let url = try nextFileURL(extension: "png")
            Task.detached(priority: .userInitiated) {
                do {
                    try session.writeScreenshot(to: url)
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
                    self.library.reload()
                    if let error { self.errorMessage = error.localizedDescription }
                }
            }
            return
        }
        do {
            try deviceManager.previewSession.startRecording(to: try nextFileURL(extension: "mov"))
            recordingStartDate = .now
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openOutputFolder() {
        let folder = CaptureFolder.url
        try? CaptureFolder.prepare(folder)
        NSWorkspace.shared.open(folder)
    }

    /// Names files like macOS screenshots: "iPhone – 2026-09-23 at 10.24.31.png".
    private func nextFileURL(extension pathExtension: String) throws -> URL {
        let folder = CaptureFolder.url
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let deviceName = (deviceManager.device?.localizedName ?? "iPhone")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let baseName = "\(deviceName) – \(formatter.string(from: .now))"

        var url = folder.appending(path: "\(baseName).\(pathExtension)")
        var index = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appending(path: "\(baseName) (\(index)).\(pathExtension)")
            index += 1
        }
        return url
    }
}
