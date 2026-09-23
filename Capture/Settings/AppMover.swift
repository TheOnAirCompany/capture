import AppKit
import Security

/// Moves Capture into the Applications folder when it runs from somewhere else,
/// such as the disk image it was downloaded in, where it can't be updated.
enum AppMover {
    static var isInstalled: Bool {
        let path = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        let folders = ["/Applications/", URL.applicationDirectory.path + "/", URL.homeDirectory.path + "/Applications/"]
        return folders.contains { path.hasPrefix($0) }
    }

    /// Asks to move, then copies, verifies and relaunches. Returns false if the user declined.
    @discardableResult
    static func offerToMove(reason: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = String(localized: "Move Capture to the Applications Folder?")
        alert.informativeText = reason + "\n\n" + String(localized: "Capture will copy itself to the Applications folder and restart from there.")
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: String(localized: "Move to Applications"))
        alert.addButton(withTitle: String(localized: "Not Now"))
        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        do {
            try move()
        } catch {
            let failure = NSAlert(error: error)
            failure.messageText = String(localized: "Capture Couldn't Be Moved")
            failure.informativeText = String(localized: "Drag Capture to the Applications folder yourself, then open it from there.")
                + "\n\n" + error.localizedDescription
            failure.runModal()
        }
        return true
    }

    private static func move() throws {
        let source = Bundle.main.bundleURL
        let destination = URL(filePath: "/Applications").appending(path: source.lastPathComponent)

        // Replace an older copy, unless it is running.
        if FileManager.default.fileExists(atPath: destination.path) {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
                .contains { $0.bundleURL?.resolvingSymlinksInPath() == destination.resolvingSymlinksInPath() }
            if running { throw MoveError.copyRunning }
        }

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.trashItem(at: destination, resultingItemURL: nil)
            }
            try FileManager.default.copyItem(at: source, to: destination)
        } catch let error as CocoaError where error.code == .fileWriteNoPermission {
            try copyAsAdministrator(from: source, to: destination)
        }

        // Only launch the copy if it is signed like the running app.
        try verify(destination)
        relaunch(from: destination, leaving: source)
    }

    /// Standard accounts can't write to /Applications: macOS asks for an administrator.
    private static func copyAsAdministrator(from source: URL, to destination: URL) throws {
        func quoted(_ path: String) -> String { "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let command = "/bin/rm -rf \(quoted(destination.path)) && /usr/bin/ditto \(quoted(source.path)) \(quoted(destination.path))"
        let script = "do shell script \"\(command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if error != nil { throw MoveError.notAuthorized }
    }

    /// Checks that the copy is intact and matches the running app's designated requirement.
    private static func verify(_ url: URL) throws {
        var running: SecCode?
        var staticRunning: SecStaticCode?
        var requirement: SecRequirement?
        var copy: SecStaticCode?
        guard SecCodeCopySelf([], &running) == errSecSuccess, let running,
              SecCodeCopyStaticCode(running, [], &staticRunning) == errSecSuccess, let staticRunning,
              SecCodeCopyDesignatedRequirement(staticRunning, [], &requirement) == errSecSuccess,
              SecStaticCodeCreateWithPath(url as CFURL, [], &copy) == errSecSuccess, let copy,
              SecStaticCodeCheckValidity(copy, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), requirement) == errSecSuccess
        else { throw MoveError.invalidSignature }
    }

    private static func relaunch(from destination: URL, leaving source: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: destination, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                // Eject the disk image Capture ran from, once this copy has quit.
                if let volume = try? source.resourceValues(forKeys: [.volumeURLKey]).volume,
                   (try? volume.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly) == true {
                    let eject = Process()
                    eject.executableURL = URL(filePath: "/bin/sh")
                    eject.arguments = ["-c", "sleep 2; /usr/bin/hdiutil detach \"$0\" -quiet", volume.path]
                    try? eject.run()
                }
                NSApp.terminate(nil)
            }
        }
    }

    enum MoveError: LocalizedError {
        case copyRunning, notAuthorized, invalidSignature

        var errorDescription: String? {
            switch self {
            case .copyRunning: String(localized: "Another copy of Capture is running from the Applications folder. Quit it and try again.")
            case .notAuthorized: String(localized: "Administrator permission is needed to write to the Applications folder.")
            case .invalidSignature: String(localized: "The copied app couldn't be verified.")
            }
        }
    }
}
