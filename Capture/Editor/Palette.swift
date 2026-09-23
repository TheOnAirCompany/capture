import CoreGraphics
import SwiftUI

/// Background suggestions derived from the colors of a capture.
nonisolated struct SuggestedBackgrounds: Equatable {
    var colors: [Color] = []
    var gradients: [[Color]] = []

    static let empty = SuggestedBackgrounds()

    /// Builds pastel, vivid and deep tones from the two main hues of the capture,
    /// which make better backgrounds than its raw, often muted, colors.
    nonisolated static func make(from image: CGImage) -> SuggestedBackgrounds {
        let hues = Palette.mainHues(in: image)
        guard let first = hues.first else { return .empty }
        let second = hues.dropFirst().first ?? (first + 0.08).truncatingRemainder(dividingBy: 1)

        func tone(_ hue: Double, _ saturation: Double, _ brightness: Double) -> Color {
            Color(hue: hue, saturation: saturation, brightness: brightness)
        }
        return SuggestedBackgrounds(
            colors: [
                tone(first, 0.28, 0.99),
                tone(second, 0.22, 0.97),
                tone(first, 0.55, 0.95),
                tone(second, 0.45, 0.32),
            ],
            gradients: [
                [tone(first, 0.30, 1), tone(second, 0.25, 0.97)],
                [tone(first, 0.60, 0.98), tone(second, 0.55, 0.85)],
                [tone(second, 0.16, 1), tone(first, 0.45, 0.97)],
                [tone(second, 0.50, 0.28), tone(first, 0.55, 0.62)],
            ]
        )
    }
}

nonisolated enum Palette {
    struct RGB { var r, g, b: Double }

    /// Up to two distinct hues: the most common vivid ones, or the dominant tones' hues.
    static func mainHues(in image: CGImage) -> [Double] {
        var hues: [Double] = []
        for color in dominantColors(in: image, count: 6) where saturation(color) > 0.12 {
            let candidate = hue(color)
            let isDistinct = hues.allSatisfy { min(abs($0 - candidate), 1 - abs($0 - candidate)) > 0.06 }
            if isDistinct { hues.append(candidate) }
            if hues.count == 2 { break }
        }
        return hues
    }

    /// Accent colors first (the most common vivid hues), then the dominant neutral tones.
    static func dominantColors(in image: CGImage, count: Int) -> [RGB] {
        let samples = pixels(of: image)
        guard !samples.isEmpty else { return [] }

        var result: [RGB] = []
        for color in vividHues(in: samples) + clusters(of: samples, count: count + 3)
        where result.allSatisfy({ distance($0, color) > 0.03 }) {
            result.append(color)
            if result.count == count { break }
        }
        return result
    }

    private static func pixels(of image: CGImage) -> [RGB] {
        let side = 64
        var data = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &data, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        return stride(from: 0, to: data.count, by: 4).map {
            RGB(r: Double(data[$0]) / 255, g: Double(data[$0 + 1]) / 255, b: Double(data[$0 + 2]) / 255)
        }
    }

    /// Averages saturated pixels by hue, keeping hues that cover at least 1% of the image.
    private static func vividHues(in samples: [RGB]) -> [RGB] {
        var bins = [[RGB]](repeating: [], count: 12)
        for sample in samples where saturation(sample) > 0.3 && max(sample.r, sample.g, sample.b) > 0.3 {
            bins[Int(hue(sample) * 12) % 12].append(sample)
        }
        return bins
            .filter { Double($0.count) >= Double(samples.count) * 0.01 }
            .sorted { $0.count > $1.count }
            .map(average)
    }

    /// K-means clusters, largest first.
    private static func clusters(of samples: [RGB], count k: Int) -> [RGB] {
        var centers = (0..<k).map { samples[$0 * samples.count / k] }
        var assignments = [Int](repeating: 0, count: samples.count)
        for _ in 0..<10 {
            for (index, sample) in samples.enumerated() {
                assignments[index] = centers.indices.min { distance(sample, centers[$0]) < distance(sample, centers[$1]) }!
            }
            for center in centers.indices {
                let members = samples.indices.filter { assignments[$0] == center }.map { samples[$0] }
                if !members.isEmpty { centers[center] = average(members) }
            }
        }
        let sizes = centers.indices.map { center in assignments.filter { $0 == center }.count }
        return centers.indices.sorted { sizes[$0] > sizes[$1] }.filter { sizes[$0] > 0 }.map { centers[$0] }
    }

    private static func average(_ colors: [RGB]) -> RGB {
        let n = Double(colors.count)
        return RGB(r: colors.reduce(0) { $0 + $1.r } / n, g: colors.reduce(0) { $0 + $1.g } / n, b: colors.reduce(0) { $0 + $1.b } / n)
    }

    private static func hue(_ color: RGB) -> Double {
        let high = max(color.r, color.g, color.b), low = min(color.r, color.g, color.b), delta = high - low
        guard delta > 0 else { return 0 }
        var hue: Double
        if high == color.r {
            hue = (color.g - color.b) / delta
        } else if high == color.g {
            hue = (color.b - color.r) / delta + 2
        } else {
            hue = (color.r - color.g) / delta + 4
        }
        hue /= 6
        return hue < 0 ? hue + 1 : hue
    }

    private static func saturation(_ color: RGB) -> Double {
        let high = max(color.r, color.g, color.b), low = min(color.r, color.g, color.b)
        return high == 0 ? 0 : (high - low) / high
    }

    private static func distance(_ a: RGB, _ b: RGB) -> Double {
        let dr = a.r - b.r, dg = a.g - b.g, db = a.b - b.b
        return dr * dr + dg * dg + db * db
    }
}
