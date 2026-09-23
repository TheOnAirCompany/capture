import AppKit
import Observation

/// Takes screenshots and records videos of the connected iPhone into ~/Desktop/Capture.
@Observable
final class CaptureController {
    private(set) var recordingStartDate: Date?
    private(set) var screenshotCount = 0
    var errorMessage: String?

    var isRecording: Bool { recordingStartDate != nil }

    private let deviceManager: DeviceManager

    init(deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
    }

    static var outputFolder: URL {
        URL.desktopDirectory.appending(path: "Capture", directoryHint: .isDirectory)
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
            deviceManager.previewSession.stopRecording()
            return
        }
        do {
            let url = try nextFileURL(extension: "mov")
            recordingStartDate = .now
            deviceManager.previewSession.startRecording(to: url) { error in
                Task { @MainActor in
                    self.recordingStartDate = nil
                    if let error { self.errorMessage = error.localizedDescription }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openOutputFolder() {
        let folder = Self.outputFolder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    /// Names files like macOS screenshots: "iPhone – 2026-09-23 at 10.24.31.png".
    private func nextFileURL(extension pathExtension: String) throws -> URL {
        let folder = Self.outputFolder
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
