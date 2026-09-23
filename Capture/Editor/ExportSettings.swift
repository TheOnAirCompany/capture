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
    static let all: [[String]] = [
        ["#FDE8D9", "#DEE0F7"],
        ["#A1C4FD", "#FBC2EB"],
        ["#232529", "#454A57"],
        ["#F093FB", "#5B6EE1"],
        ["#FDCC87", "#FA7D73"],
        ["#84FAB0", "#8FD3F4"],
        ["#FAD0C4", "#FFD1FF"],
        ["#0F2027", "#2C5364"],
        ["#FFECD2", "#FCB69F"],
        ["#C2E9FB", "#A1C4FD"],
        ["#D4FC79", "#96E6A1"],
        ["#434343", "#000000"],
    ]
}

/// Export options, remembered between launches.
@Observable
final class ExportSettings {
    var format: ExportFormat { didSet { save(format.rawValue, "format") } }
    var scale: Double { didSet { save(scale, "scale") } }
    var showsBezel: Bool { didSet { save(showsBezel, "showsBezel") } }
    /// Chosen device model, or nil to pick one matching the capture.
    var modelID: String? { didSet { save(modelID, "modelID") } }
    var finishHex: String? { didSet { save(finishHex, "finishHex") } }
    var showsDynamicIsland: Bool { didSet { save(showsDynamicIsland, "showsDynamicIsland") } }
    var orientation: DeviceOrientation { didSet { save(orientation.rawValue, "orientation") } }
    var ratio: CanvasRatio { didSet { save(ratio.rawValue, "ratio") } }
    var backgroundKind: BackgroundKind { didSet { save(backgroundKind.rawValue, "backgroundKind") } }
    var hasBackground: Bool { didSet { save(hasBackground, "hasBackground") } }
    var colorHex: String { didSet { save(colorHex, "colorHex") } }
    var gradientHexes: [String] { didSet { save(gradientHexes, "gradientHexes") } }
    var backgroundImage: URL? { didSet { save(backgroundImage?.path, "backgroundImage") } }
    var margin: Double { didSet { save(margin, "margin") } }
    var showsShadow: Bool { didSet { save(showsShadow, "showsShadow") } }
    /// The user's own palette, editable by pasting hex codes.
    var customColors: [String] { didSet { save(customColors, "customColors") } }
    var customGradients: [[String]] { didSet { save(customGradients, "customGradients") } }

    private static let prefix = "export."
    static let defaultColors = ["#FFFFFF", "#F2F2F7", "#1C1C1E", "#007AFF", "#FFD60A"]

    init() {
        let d = UserDefaults.standard, p = Self.prefix
        format = ExportFormat(rawValue: d.string(forKey: p + "format") ?? "") ?? .png
        scale = d.object(forKey: p + "scale") as? Double ?? 1
        showsBezel = d.object(forKey: p + "showsBezel") as? Bool ?? true
        modelID = d.string(forKey: p + "modelID")
        finishHex = d.string(forKey: p + "finishHex")
        showsDynamicIsland = d.object(forKey: p + "showsDynamicIsland") as? Bool ?? true
        orientation = DeviceOrientation(rawValue: d.string(forKey: p + "orientation") ?? "") ?? .automatic
        ratio = CanvasRatio(rawValue: d.string(forKey: p + "ratio") ?? "") ?? .automatic
        backgroundKind = BackgroundKind(rawValue: d.string(forKey: p + "backgroundKind") ?? "") ?? .gradient
        hasBackground = d.object(forKey: p + "hasBackground") as? Bool ?? true
        colorHex = d.string(forKey: p + "colorHex") ?? Self.defaultColors[0]
        gradientHexes = d.stringArray(forKey: p + "gradientHexes") ?? GradientPresets.all[0]
        backgroundImage = d.string(forKey: p + "backgroundImage").map { URL(filePath: $0) }
        margin = d.object(forKey: p + "margin") as? Double ?? 0.08
        showsShadow = d.object(forKey: p + "showsShadow") as? Bool ?? true
        customColors = d.stringArray(forKey: p + "customColors") ?? Self.defaultColors
        customGradients = d.array(forKey: p + "customGradients") as? [[String]] ?? []
    }

    var background: CompositionBackground {
        guard hasBackground else { return .none }
        switch backgroundKind {
        case .color: return .color(Color(hex: colorHex) ?? .white)
        case .gradient: return .gradient(gradientHexes.compactMap { Color(hex: $0) })
        case .image: return backgroundImage.map(CompositionBackground.image) ?? .none
        }
    }

    /// The chosen model when it is the same kind of device as the capture (an iPhone frame
    /// for an iPhone capture, an iPad frame for an iPad one), otherwise the newest matching one.
    func model(for size: CGSize) -> DeviceModel? {
        if let chosen = DeviceModel.model(id: modelID), chosen.family == DeviceModel.Family(screen: size) {
            return chosen
        }
        return DeviceModel.matching(size).first
    }

    func finish(for model: DeviceModel) -> DeviceFinish {
        model.finishes.first { $0.hex == finishHex } ?? model.finishes[0]
    }

    func style(for size: CGSize, format: ExportFormat? = nil) -> CompositionStyle {
        var background = background
        // JPEG has no transparency: fall back to white.
        if background == .none, let format, !format.supportsTransparency {
            background = .color(.white)
        }
        let model = model(for: size)
        return CompositionStyle(
            model: model,
            showsBezel: showsBezel && model != nil,
            finish: model.map(finish(for:)),
            showsDynamicIsland: showsDynamicIsland,
            orientation: orientation,
            ratio: ratio,
            background: background,
            margin: background == .none && ratio == .automatic ? 0 : margin,
            showsShadow: showsShadow
        )
    }

    func addColors(from text: String) -> Bool {
        let codes = Color.hexCodes(in: text).filter { !customColors.contains($0) }
        customColors.append(contentsOf: codes)
        if let last = codes.last { selectColor(last) }
        return !codes.isEmpty
    }

    func selectColor(_ hex: String) {
        colorHex = hex
        hasBackground = true
    }

    func selectGradient(_ hexes: [String]) {
        gradientHexes = hexes
        hasBackground = true
    }

    private func save(_ value: Any?, _ key: String) {
        UserDefaults.standard.set(value, forKey: Self.prefix + key)
    }
}
