import AppKit
import SwiftUI

nonisolated extension Color {
    /// Parses "#RRGGBB", "RRGGBB" or "#RGB".
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") { value.removeFirst() }
        if value.count == 3 { value = value.map { "\($0)\($0)" }.joined() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255
        )
    }

    var hex: String {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    /// Mixes with white (positive amount) or black (negative amount).
    func adjusted(by amount: Double) -> Color {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return self }
        let target: CGFloat = amount > 0 ? 1 : 0
        let t = CGFloat(abs(amount))
        return Color(
            .sRGB,
            red: color.redComponent + (target - color.redComponent) * t,
            green: color.greenComponent + (target - color.greenComponent) * t,
            blue: color.blueComponent + (target - color.blueComponent) * t
        )
    }

    /// Every hex code found in pasted text, such as "#FFAA00, 0af #123456".
    static func hexCodes(in text: String) -> [String] {
        text.split(whereSeparator: { " ,;\n\t".contains($0) })
            .compactMap { Color(hex: String($0))?.hex }
    }
}
