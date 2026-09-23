import CoreGraphics
import SwiftUI

/// Background suggestions derived from the colors of a capture.
nonisolated struct SuggestedBackgrounds: Equatable {
    var colors: [Color] = []
    var gradients: [[Color]] = []

    static let empty = SuggestedBackgrounds()

    nonisolated static func make(from image: CGImage) -> SuggestedBackgrounds {
        let dominant = Palette.dominantColors(in: image, count: 4)
        guard !dominant.isEmpty else { return .empty }
        let colors = dominant.map { Color(.sRGB, red: $0.r, green: $0.g, blue: $0.b) }

        // Soft tones work better behind a device than the raw colors.
        let soft = colors.map { $0.adjusted(by: 0.45) }
        let suggestions = Array((soft.prefix(2) + colors.prefix(2)).prefix(4))

        let first = colors[0], second = colors.count > 1 ? colors[1] : colors[0].adjusted(by: -0.3)
        let third = colors.count > 2 ? colors[2] : second.adjusted(by: 0.3)
        let gradients: [[Color]] = [
            [first.adjusted(by: 0.55), second.adjusted(by: 0.35)],
            [first.adjusted(by: 0.2), first.adjusted(by: -0.35)],
            [second.adjusted(by: 0.4), third.adjusted(by: 0.1)],
            [third.adjusted(by: -0.2), first.adjusted(by: -0.55)],
        ]
        return SuggestedBackgrounds(colors: suggestions, gradients: gradients)
    }
}

nonisolated enum Palette {
    struct RGB { var r, g, b: Double }

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
