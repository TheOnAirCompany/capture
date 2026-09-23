import AppKit

/// The folder where screenshots and videos are saved, chosen during onboarding.
enum CaptureFolder {
    static let defaultsKey = "captureFolderPath"

    static var defaultURL: URL {
        URL.documentsDirectory.appending(path: "Capture", directoryHint: .isDirectory)
    }

    static var url: URL {
        get {
            UserDefaults.standard.string(forKey: defaultsKey)
                .map { URL(filePath: $0, directoryHint: .isDirectory) } ?? defaultURL
        }
        set { UserDefaults.standard.set(newValue.path, forKey: defaultsKey) }
    }

    /// Localized path for display, such as "Documents › Capture".
    static func displayPath(of url: URL) -> String {
        let components = FileManager.default.componentsToDisplay(forPath: url.path) ?? [url.lastPathComponent]
        let home = FileManager.default.componentsToDisplay(forPath: URL.homeDirectory.path) ?? []
        return components.dropFirst(components.starts(with: home) ? home.count : 0).joined(separator: " › ")
    }

    /// Creates the folder and reads it, so macOS asks for access now
    /// (for example to Documents) rather than during the first capture.
    static func prepare(_ url: URL = url) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = try FileManager.default.contentsOfDirectory(atPath: url.path)
    }

    /// Asks the user for a folder, starting from `current`.
    @MainActor
    static func choose(startingAt current: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = current
        panel.prompt = String(localized: "Choose")
        panel.message = String(localized: "Choose where to save your screenshots and videos.")
        return panel.runModal() == .OK ? panel.url : nil
    }
}
