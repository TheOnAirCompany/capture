import SwiftUI
import UniformTypeIdentifiers

nonisolated enum ExportFormat: String, CaseIterable, Identifiable {
    case png, jpeg, heic

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .png: "PNG (High Quality)"
        case .jpeg: "JPEG"
        case .heic: "HEIC"
        }
    }

    var contentType: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .heic: .heic
        }
    }

    var supportsTransparency: Bool { self != .jpeg }
}

enum BezelFinish: String, CaseIterable, Identifiable {
    case black, silver, natural, blue

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .black: "Black"
        case .silver: "Silver"
        case .natural: "Natural"
        case .blue: "Blue"
        }
    }

    /// Metal band gradient, from the lit edge to the shaded edge.
    var colors: [Color] {
        switch self {
        case .black: [Color(white: 0.36), Color(white: 0.16), Color(white: 0.28)]
        case .silver: [Color(white: 0.93), Color(white: 0.76), Color(white: 0.88)]
        case .natural: [Color(red: 0.78, green: 0.75, blue: 0.70), Color(red: 0.55, green: 0.53, blue: 0.49), Color(red: 0.70, green: 0.67, blue: 0.62)]
        case .blue: [Color(red: 0.36, green: 0.42, blue: 0.53), Color(red: 0.20, green: 0.24, blue: 0.32), Color(red: 0.30, green: 0.35, blue: 0.45)]
        }
    }
}

enum BackgroundKind: String, CaseIterable, Identifiable {
    case color, gradient, image

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .color: "Color"
        case .gradient: "Gradient"
        case .image: "Image"
        }
    }
}

/// What the device sits on in an exported screenshot.
enum CompositionBackground: Equatable {
    case none
    case color(Color)
    case gradient([Color])
    case image(URL)
}

enum GradientPresets {
    static let all: [[Color]] = [
        [Color(red: 0.99, green: 0.91, blue: 0.85), Color(red: 0.87, green: 0.88, blue: 0.97)],
        [Color(red: 0.63, green: 0.77, blue: 0.99), Color(red: 0.98, green: 0.76, blue: 0.92)],
        [Color(red: 0.14, green: 0.15, blue: 0.18), Color(red: 0.27, green: 0.29, blue: 0.34)],
        [Color(red: 0.94, green: 0.58, blue: 0.98), Color(red: 0.36, green: 0.43, blue: 0.88)],
        [Color(red: 0.99, green: 0.80, blue: 0.53), Color(red: 0.98, green: 0.49, blue: 0.45)],
    ]
}

enum ColorPresets {
    static let all: [Color] = [
        .white,
        Color(red: 0.95, green: 0.95, blue: 0.97),
        Color(red: 0.11, green: 0.11, blue: 0.12),
        Color(red: 0.0, green: 0.48, blue: 1.0),
        Color(red: 1.0, green: 0.84, blue: 0.04),
    ]
}

/// Export options, remembered between launches.
@Observable
final class ExportSettings {
    var format: ExportFormat { didSet { save(format.rawValue, "format") } }
    var scale: Double { didSet { save(scale, "scale") } }
    var showsBezel: Bool { didSet { save(showsBezel, "showsBezel") } }
    var finish: BezelFinish { didSet { save(finish.rawValue, "finish") } }
    var backgroundKind: BackgroundKind { didSet { save(backgroundKind.rawValue, "backgroundKind") } }
    var hasBackground: Bool { didSet { save(hasBackground, "hasBackground") } }
    var color: Color = ColorPresets.all[0]
    var gradientIndex: Int { didSet { save(gradientIndex, "gradientIndex") } }
    var backgroundImage: URL? { didSet { save(backgroundImage?.path, "backgroundImage") } }
    var margin: Double { didSet { save(margin, "margin") } }
    var showsShadow: Bool { didSet { save(showsShadow, "showsShadow") } }

    private let defaults = UserDefaults.standard
    private static let prefix = "export."

    init() {
        let d = UserDefaults.standard, p = Self.prefix
        format = ExportFormat(rawValue: d.string(forKey: p + "format") ?? "") ?? .png
        scale = d.object(forKey: p + "scale") as? Double ?? 1
        showsBezel = d.object(forKey: p + "showsBezel") as? Bool ?? true
        finish = BezelFinish(rawValue: d.string(forKey: p + "finish") ?? "") ?? .natural
        backgroundKind = BackgroundKind(rawValue: d.string(forKey: p + "backgroundKind") ?? "") ?? .gradient
        hasBackground = d.object(forKey: p + "hasBackground") as? Bool ?? true
        gradientIndex = min(d.integer(forKey: p + "gradientIndex"), GradientPresets.all.count - 1)
        backgroundImage = d.string(forKey: p + "backgroundImage").map { URL(filePath: $0) }
        margin = d.object(forKey: p + "margin") as? Double ?? 0.08
        showsShadow = d.object(forKey: p + "showsShadow") as? Bool ?? true
    }

    var background: CompositionBackground {
        guard hasBackground else { return .none }
        switch backgroundKind {
        case .color: return .color(color)
        case .gradient: return .gradient(GradientPresets.all[gradientIndex])
        case .image: return backgroundImage.map(CompositionBackground.image) ?? .none
        }
    }

    func style(for format: ExportFormat? = nil) -> CompositionStyle {
        var background = background
        // JPEG has no transparency: fall back to white.
        if background == .none, let format, !format.supportsTransparency {
            background = .color(.white)
        }
        return CompositionStyle(
            showsBezel: showsBezel,
            finish: finish,
            background: background,
            margin: background == .none ? 0 : margin,
            showsShadow: showsShadow
        )
    }

    private func save(_ value: Any?, _ key: String) {
        defaults.set(value, forKey: Self.prefix + key)
    }
}
