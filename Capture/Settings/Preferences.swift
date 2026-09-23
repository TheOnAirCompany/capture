import AppKit
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .system: "Match System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    func apply() {
        NSApp.appearance = switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

enum CaptureScale: String, CaseIterable, Identifiable {
    case original, half

    var id: Self { self }

    var value: Double { self == .original ? 1 : 0.5 }

    var title: LocalizedStringResource {
        switch self {
        case .original: "1x (Original Size)"
        case .half: "½x (Half Size)"
        }
    }
}

enum FileNaming: String, CaseIterable, Identifiable {
    case deviceAndDate, date, numbered, custom

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .deviceAndDate: "Device, Date and Time"
        case .date: "Date and Time"
        case .numbered: "Numbered"
        case .custom: "Custom"
        }
    }

    var template: String? {
        switch self {
        case .deviceAndDate: "{device} – {date} {time}"
        case .date: "{date} {time}"
        case .numbered: "{type} {counter}"
        case .custom: nil
        }
    }
}

enum FolderOrganization: String, CaseIterable, Identifiable {
    case none, date, device

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .none: "None"
        case .date: "Date"
        case .device: "Device"
        }
    }
}

/// Variables available in file name templates.
enum FileNameToken: String, CaseIterable, Identifiable {
    case device, date, time, counter, type

    var id: Self { self }
    var placeholder: String { "{\(rawValue)}" }

    var title: LocalizedStringResource {
        switch self {
        case .device: "Device"
        case .date: "Date"
        case .time: "Time"
        case .counter: "Counter"
        case .type: "Type"
        }
    }
}

/// App preferences stored in UserDefaults, shared by the settings screen and the capture code.
enum Preferences {
    enum Key {
        static let appearance = "appearance"
        static let captureFormat = "captureFormat"
        static let captureScale = "captureScale"
        static let recordsSound = "recordsSound"
        static let fileNaming = "fileNaming"
        static let fileNameTemplate = "fileNameTemplate"
        static let folderOrganization = "folderOrganization"
        static let exportsToCaptureFolder = "exportsToCaptureFolder"
        static let captureCounter = "captureCounter"
    }

    static let exportsFolderName = "_Exports"
    static let defaultCustomTemplate = "{device} {date} {counter}"

    private static var defaults: UserDefaults { .standard }

    static var captureFormat: ExportFormat {
        ExportFormat(rawValue: defaults.string(forKey: Key.captureFormat) ?? "") ?? .png
    }

    static var captureScale: CaptureScale {
        CaptureScale(rawValue: defaults.string(forKey: Key.captureScale) ?? "") ?? .original
    }

    static var recordsSound: Bool {
        defaults.object(forKey: Key.recordsSound) as? Bool ?? true
    }

    static var folderOrganization: FolderOrganization {
        FolderOrganization(rawValue: defaults.string(forKey: Key.folderOrganization) ?? "") ?? .none
    }

    static var exportsToCaptureFolder: Bool {
        defaults.bool(forKey: Key.exportsToCaptureFolder)
    }

    static var appearance: AppAppearance {
        AppAppearance(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
    }

    static var fileNameTemplate: String {
        let naming = FileNaming(rawValue: defaults.string(forKey: Key.fileNaming) ?? "") ?? .deviceAndDate
        return naming.template ?? defaults.string(forKey: Key.fileNameTemplate) ?? defaultCustomTemplate
    }

    /// Returns the next value of the counter used by `{counter}`.
    static func nextCounter() -> Int {
        let value = defaults.integer(forKey: Key.captureCounter) + 1
        defaults.set(value, forKey: Key.captureCounter)
        return value
    }

    /// Fills a template such as "{device} – {date} {time}".
    static func fileName(template: String, device: String, date: Date, counter: Int, isVideo: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let dateText = formatter.string(from: date)
        formatter.dateFormat = "HH.mm.ss"

        let values: [FileNameToken: String] = [
            .device: device,
            .date: dateText,
            .time: formatter.string(from: date),
            .counter: String(format: "%03d", counter),
            .type: isVideo ? String(localized: "Video") : String(localized: "Screenshot"),
        ]
        var name = template
        for (token, value) in values {
            name = name.replacingOccurrences(of: token.placeholder, with: value)
        }
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? values[.date]! + " " + values[.time]! : cleaned
    }
}
