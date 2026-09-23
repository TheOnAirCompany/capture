import SwiftUI

struct DeviceFinish: Identifiable, Hashable {
    let name: LocalizedStringResource
    let hex: String
    /// Older iPads in light colors have a white front instead of a black one.
    var hasWhiteFront = false

    var id: String { hex }
    var color: Color { Color(hex: hex) ?? .gray }

    /// Metal band gradient, from the lit edge to the shaded edge.
    var bandColors: [Color] { [color.adjusted(by: 0.25), color.adjusted(by: -0.3), color.adjusted(by: 0.1)] }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.hex == rhs.hex }
    func hash(into hasher: inout Hasher) { hasher.combine(hex) }
}

/// An iPhone with a rounded display (iPhone X onwards), or an iPad from 2015 onwards.
/// Finish names are Apple's color names, without the material.
struct DeviceModel: Identifiable, Hashable {
    enum Family: Hashable {
        case iPhone, iPad

        /// iPads are close to 4:3 (at most 1.6:1), iPhones are 16:9 or longer.
        init(screen size: CGSize) {
            let ratio = max(size.width, size.height) / max(1, min(size.width, size.height))
            self = ratio < 1.6 ? .iPad : .iPhone
        }
    }

    enum Cutout: Hashable {
        /// Width and height in points.
        case notch(width: CGFloat, height: CGFloat)
        /// Distance from the top of the screen and height, in points. The width is 126 pt.
        case dynamicIsland(top: CGFloat, height: CGFloat)

        var isDynamicIsland: Bool {
            if case .dynamicIsland = self { true } else { false }
        }
    }

    let id: String
    let name: String
    /// Portrait screen size in pixels.
    let screen: CGSize
    let scale: CGFloat
    let cornerRadius: CGFloat
    /// The notch or Dynamic Island of iPhones. iPads have none.
    let cutout: Cutout?
    let finishes: [DeviceFinish]
    var family = Family.iPhone
    /// iPads before the all-screen design: square display, thick borders and a Home button.
    var hasHomeButton = false
    /// Recent iPads have their front camera on the long edge, for landscape video calls.
    var hasLandscapeCamera = false

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Models with the same screen as a capture, newest first.
    static func matching(_ size: CGSize) -> [DeviceModel] {
        let width = min(size.width, size.height), height = max(size.width, size.height)
        return all.filter { $0.screen.width == width && $0.screen.height == height }.reversed()
    }

    static func model(id: String?) -> DeviceModel? {
        all.first { $0.id == id }
    }
}

// MARK: - Catalog

private let wideNotch = DeviceModel.Cutout.notch(width: 209, height: 30)
private let narrowNotch = DeviceModel.Cutout.notch(width: 162, height: 33)
private let island = DeviceModel.Cutout.dynamicIsland(top: 11, height: 37.33)
/// Thinner borders from iPhone 16 Pro on: the island sits lower and is a little shorter
/// (measured on an iPhone 16 Pro Max screen recording).
private let lowIsland = DeviceModel.Cutout.dynamicIsland(top: 14, height: 36.67)

private func finish(_ name: LocalizedStringResource, _ hex: String) -> DeviceFinish {
    DeviceFinish(name: name, hex: hex)
}

private let x = CGSize(width: 1125, height: 2436)
private let xsMax = CGSize(width: 1242, height: 2688)
private let xr = CGSize(width: 828, height: 1792)
private let mini = CGSize(width: 1080, height: 2340)
private let regular12 = CGSize(width: 1170, height: 2532)
private let max12 = CGSize(width: 1284, height: 2778)
private let regular14 = CGSize(width: 1179, height: 2556)
private let max14 = CGSize(width: 1290, height: 2796)
private let regular16 = CGSize(width: 1206, height: 2622)
private let max16 = CGSize(width: 1320, height: 2868)
private let air = CGSize(width: 1260, height: 2736)

private let finishesXS = [finish("Space Gray", "#4A4A4C"), finish("Silver", "#E3E4E5"), finish("Gold", "#E9D3B4")]
private let finishesXR = [finish("Black", "#1F2020"), finish("White", "#F3F3F3"), finish("Blue", "#3AA1D8"),
                          finish("Yellow", "#F8D74A"), finish("Coral", "#EE7762"), finish("Red", "#B3232C")]
private let finishes11 = [finish("Black", "#1F2020"), finish("White", "#F8F7F2"), finish("Green", "#AEE1CD"),
                          finish("Yellow", "#FFF3B0"), finish("Purple", "#D1CDDA"), finish("Red", "#BA0C2E")]
private let finishes11Pro = [finish("Space Gray", "#535150"), finish("Silver", "#EBEBE3"), finish("Gold", "#FAD7BD"),
                             finish("Midnight Green", "#4E5851")]
private let finishes12 = [finish("Black", "#25212B"), finish("White", "#F6F2EF"), finish("Blue", "#023B63"),
                          finish("Green", "#D8EFD5"), finish("Purple", "#B7AFE6"), finish("Red", "#D82E2E")]
private let finishes12Pro = [finish("Graphite", "#52514F"), finish("Silver", "#E3E4DF"), finish("Gold", "#F5E7CF"),
                             finish("Pacific Blue", "#2E4452")]
private let finishes13 = [finish("Midnight", "#232A31"), finish("Starlight", "#FAF6F2"), finish("Blue", "#276787"),
                          finish("Pink", "#FADDD7"), finish("Green", "#394C38"), finish("Red", "#BF0013")]
private let finishes13Pro = [finish("Graphite", "#54524F"), finish("Silver", "#F1F2ED"), finish("Gold", "#FAE7CF"),
                             finish("Sierra Blue", "#A7C1D9"), finish("Alpine Green", "#576856")]
private let finishes14 = [finish("Midnight", "#222930"), finish("Starlight", "#FAF6F2"), finish("Blue", "#A0B4C7"),
                          finish("Purple", "#E5DDEA"), finish("Yellow", "#F9E479"), finish("Red", "#FC0324")]
private let finishes14Pro = [finish("Space Black", "#403E3D"), finish("Silver", "#F0F2F2"), finish("Gold", "#F4E8CE"),
                             finish("Deep Purple", "#594F63")]
private let finishes15 = [finish("Black", "#35393B"), finish("Blue", "#D4E4ED"), finish("Green", "#E3E8D8"),
                          finish("Yellow", "#F9F2D4"), finish("Pink", "#F5DDE0")]
private let finishes15Pro = [finish("Black", "#3C3C3D"), finish("White", "#F2F1EB"),
                             finish("Blue", "#3F4A58"), finish("Natural", "#BAB4A9")]
private let finishes16 = [finish("Black", "#3C4042"), finish("White", "#FAFAFA"), finish("Pink", "#F2ADDA"),
                          finish("Teal", "#B0D4D2"), finish("Ultramarine", "#9AADF6")]
private let finishes16Pro = [finish("Black", "#3C3C3D"), finish("White", "#F2F1ED"),
                             finish("Natural", "#C2BCB2"), finish("Desert", "#BFA48F")]
private let finishes16e = [finish("Black", "#3C4042"), finish("White", "#FAFAFA")]
private let finishes17 = [finish("Black", "#353839"), finish("White", "#F5F5F5"), finish("Mist Blue", "#9FB4C9"),
                          finish("Sage", "#A6B39A"), finish("Lavender", "#C8BDE0")]
private let finishesAir = [finish("Space Black", "#2E2E30"), finish("Cloud White", "#F3F3F1"),
                           finish("Light Gold", "#EADFC9"), finish("Sky Blue", "#C5D9EA")]
private let finishes17Pro = [finish("Silver", "#E3E4E5"), finish("Cosmic Orange", "#E46E2E"), finish("Deep Blue", "#2F3B58")]
private let finishes18Pro = [finish("Black", "#2F3032"), finish("Silver", "#E3E4E5"), finish("Glacier", "#C9DCE6"),
                             finish("Burgundy", "#6B2A35")]

extension DeviceModel {
    static let all: [DeviceModel] = iPhones + iPads

    /// Oldest first. Corner radii come from each model's display corner radius.
    static let iPhones: [DeviceModel] = [
        DeviceModel(id: "iphone-x", name: "iPhone X", screen: x, scale: 3, cornerRadius: 39, cutout: wideNotch, finishes: Array(finishesXS.prefix(2))),
        DeviceModel(id: "iphone-xs", name: "iPhone XS", screen: x, scale: 3, cornerRadius: 39, cutout: wideNotch, finishes: finishesXS),
        DeviceModel(id: "iphone-xs-max", name: "iPhone XS Max", screen: xsMax, scale: 3, cornerRadius: 39, cutout: wideNotch, finishes: finishesXS),
        DeviceModel(id: "iphone-xr", name: "iPhone XR", screen: xr, scale: 2, cornerRadius: 41.5, cutout: wideNotch, finishes: finishesXR),
        DeviceModel(id: "iphone-11", name: "iPhone 11", screen: xr, scale: 2, cornerRadius: 41.5, cutout: wideNotch, finishes: finishes11),
        DeviceModel(id: "iphone-11-pro", name: "iPhone 11 Pro", screen: x, scale: 3, cornerRadius: 39, cutout: wideNotch, finishes: finishes11Pro),
        DeviceModel(id: "iphone-11-pro-max", name: "iPhone 11 Pro Max", screen: xsMax, scale: 3, cornerRadius: 39, cutout: wideNotch, finishes: finishes11Pro),
        DeviceModel(id: "iphone-12-mini", name: "iPhone 12 mini", screen: mini, scale: 3, cornerRadius: 44, cutout: wideNotch, finishes: finishes12),
        DeviceModel(id: "iphone-12", name: "iPhone 12", screen: regular12, scale: 3, cornerRadius: 47.33, cutout: wideNotch, finishes: finishes12),
        DeviceModel(id: "iphone-12-pro", name: "iPhone 12 Pro", screen: regular12, scale: 3, cornerRadius: 47.33, cutout: wideNotch, finishes: finishes12Pro),
        DeviceModel(id: "iphone-12-pro-max", name: "iPhone 12 Pro Max", screen: max12, scale: 3, cornerRadius: 53.33, cutout: wideNotch, finishes: finishes12Pro),
        DeviceModel(id: "iphone-13-mini", name: "iPhone 13 mini", screen: mini, scale: 3, cornerRadius: 44, cutout: narrowNotch, finishes: finishes13),
        DeviceModel(id: "iphone-13", name: "iPhone 13", screen: regular12, scale: 3, cornerRadius: 47.33, cutout: narrowNotch, finishes: finishes13),
        DeviceModel(id: "iphone-13-pro", name: "iPhone 13 Pro", screen: regular12, scale: 3, cornerRadius: 47.33, cutout: narrowNotch, finishes: finishes13Pro),
        DeviceModel(id: "iphone-13-pro-max", name: "iPhone 13 Pro Max", screen: max12, scale: 3, cornerRadius: 53.33, cutout: narrowNotch, finishes: finishes13Pro),
        DeviceModel(id: "iphone-14", name: "iPhone 14", screen: regular12, scale: 3, cornerRadius: 47.33, cutout: narrowNotch, finishes: finishes14),
        DeviceModel(id: "iphone-14-plus", name: "iPhone 14 Plus", screen: max12, scale: 3, cornerRadius: 53.33, cutout: narrowNotch, finishes: finishes14),
        DeviceModel(id: "iphone-14-pro", name: "iPhone 14 Pro", screen: regular14, scale: 3, cornerRadius: 55, cutout: island, finishes: finishes14Pro),
        DeviceModel(id: "iphone-14-pro-max", name: "iPhone 14 Pro Max", screen: max14, scale: 3, cornerRadius: 55, cutout: island, finishes: finishes14Pro),
        DeviceModel(id: "iphone-15", name: "iPhone 15", screen: regular14, scale: 3, cornerRadius: 55, cutout: island, finishes: finishes15),
        DeviceModel(id: "iphone-15-plus", name: "iPhone 15 Plus", screen: max14, scale: 3, cornerRadius: 55, cutout: island, finishes: finishes15),
        DeviceModel(id: "iphone-15-pro", name: "iPhone 15 Pro", screen: regular14, scale: 3, cornerRadius: 55, cutout: island, finishes: finishes15Pro),
        DeviceModel(id: "iphone-15-pro-max", name: "iPhone 15 Pro Max", screen: max14, scale: 3, cornerRadius: 55, cutout: island, finishes: finishes15Pro),
        DeviceModel(id: "iphone-16", name: "iPhone 16", screen: regular14, scale: 3, cornerRadius: 55, cutout: island, finishes: finishes16),
        DeviceModel(id: "iphone-16-plus", name: "iPhone 16 Plus", screen: max14, scale: 3, cornerRadius: 55, cutout: island, finishes: finishes16),
        DeviceModel(id: "iphone-16-pro", name: "iPhone 16 Pro", screen: regular16, scale: 3, cornerRadius: 62, cutout: lowIsland, finishes: finishes16Pro),
        DeviceModel(id: "iphone-16-pro-max", name: "iPhone 16 Pro Max", screen: max16, scale: 3, cornerRadius: 62, cutout: lowIsland, finishes: finishes16Pro),
        DeviceModel(id: "iphone-16e", name: "iPhone 16e", screen: regular12, scale: 3, cornerRadius: 47.33, cutout: narrowNotch, finishes: finishes16e),
        DeviceModel(id: "iphone-17", name: "iPhone 17", screen: regular16, scale: 3, cornerRadius: 62, cutout: lowIsland, finishes: finishes17),
        DeviceModel(id: "iphone-air", name: "iPhone Air", screen: air, scale: 3, cornerRadius: 62, cutout: lowIsland, finishes: finishesAir),
        DeviceModel(id: "iphone-17-pro", name: "iPhone 17 Pro", screen: regular16, scale: 3, cornerRadius: 62, cutout: lowIsland, finishes: finishes17Pro),
        DeviceModel(id: "iphone-17-pro-max", name: "iPhone 17 Pro Max", screen: max16, scale: 3, cornerRadius: 62, cutout: lowIsland, finishes: finishes17Pro),
        DeviceModel(id: "iphone-18-pro", name: "iPhone 18 Pro", screen: regular16, scale: 3, cornerRadius: 62, cutout: lowIsland, finishes: finishes18Pro),
        DeviceModel(id: "iphone-18-pro-max", name: "iPhone 18 Pro Max", screen: max16, scale: 3, cornerRadius: 62, cutout: lowIsland, finishes: finishes18Pro),
    ]
}

// MARK: - iPad

private let mini4 = CGSize(width: 1536, height: 2048)
private let pro105 = CGSize(width: 1668, height: 2224)
private let ipad102 = CGSize(width: 1620, height: 2160)
private let pro129 = CGSize(width: 2048, height: 2732)
private let pro11 = CGSize(width: 1668, height: 2388)
private let air109 = CGSize(width: 1640, height: 2360)
private let mini6 = CGSize(width: 1488, height: 2266)
private let pro11M4 = CGSize(width: 1668, height: 2420)
private let pro13M4 = CGSize(width: 2064, height: 2752)

private func whiteFront(_ name: LocalizedStringResource, _ hex: String) -> DeviceFinish {
    DeviceFinish(name: name, hex: hex, hasWhiteFront: true)
}

private let finishesClassic = [finish("Space Gray", "#4A4A4C"), whiteFront("Silver", "#E3E4E5"), whiteFront("Gold", "#E9D3B4")]
private let finishesClassicRose = finishesClassic + [whiteFront("Rose Gold", "#E6C7C2")]
private let finishesPro = [finish("Space Gray", "#4A4A4C"), finish("Silver", "#E3E4E5")]
private let finishesProBlack = [finish("Space Black", "#2E2E30"), finish("Silver", "#E3E4E5")]
private let finishesAir4 = [finish("Space Gray", "#4A4A4C"), finish("Silver", "#E3E4E5"), finish("Rose Gold", "#E6C7C2"),
                            finish("Green", "#B5C9B2"), finish("Sky Blue", "#AFC8DB")]
private let finishesAir5 = [finish("Space Gray", "#4A4A4C"), finish("Starlight", "#F0E9DD"), finish("Pink", "#EFD3D4"),
                            finish("Purple", "#C9C2DE"), finish("Blue", "#A8BFD9")]
private let finishesAirM = [finish("Space Gray", "#4A4A4C"), finish("Blue", "#A8BFD9"), finish("Purple", "#C9C2DE"),
                            finish("Starlight", "#F0E9DD")]
private let finishesMini6 = [finish("Space Gray", "#4A4A4C"), finish("Pink", "#EFD3D4"), finish("Purple", "#C9C2DE"),
                             finish("Starlight", "#F0E9DD")]
private let finishesMiniA17 = [finish("Space Gray", "#4A4A4C"), finish("Blue", "#A8BFD9"), finish("Purple", "#C9C2DE"),
                               finish("Starlight", "#F0E9DD")]
private let finishesIPad10 = [finish("Silver", "#E3E4E5"), finish("Blue", "#7FA7D1"), finish("Pink", "#E9A9B8"),
                              finish("Yellow", "#F2D65B")]

private func iPad(
    _ id: String, _ name: String, _ screen: CGSize, _ finishes: [DeviceFinish],
    homeButton: Bool = false, landscapeCamera: Bool = false
) -> DeviceModel {
    // All-screen iPads have 18 pt display corners (iPad Air and iPad Pro, from UIScreen);
    // iPad mini and the M4 and M5 iPad Pro are assumed to match.
    DeviceModel(id: id, name: name, screen: screen, scale: 2, cornerRadius: homeButton ? 0 : 18, cutout: nil,
                finishes: finishes, family: .iPad, hasHomeButton: homeButton, hasLandscapeCamera: landscapeCamera)
}

extension DeviceModel {
    /// iPads from 2015 to 2026, oldest first.
    static let iPads: [DeviceModel] = [
        iPad("ipad-mini-4", "iPad mini 4", mini4, finishesClassic, homeButton: true),
        iPad("ipad-pro-12-9-1", "iPad Pro 12.9-inch (1st generation)", pro129, finishesClassic, homeButton: true),
        iPad("ipad-pro-9-7", "iPad Pro 9.7-inch", mini4, finishesClassicRose, homeButton: true),
        iPad("ipad-5", "iPad (5th generation)", mini4, finishesClassic, homeButton: true),
        iPad("ipad-pro-10-5", "iPad Pro 10.5-inch", pro105, finishesClassicRose, homeButton: true),
        iPad("ipad-pro-12-9-2", "iPad Pro 12.9-inch (2nd generation)", pro129, finishesClassic, homeButton: true),
        iPad("ipad-6", "iPad (6th generation)", mini4, finishesClassic, homeButton: true),
        iPad("ipad-pro-11-1", "iPad Pro 11-inch (1st generation)", pro11, finishesPro),
        iPad("ipad-pro-12-9-3", "iPad Pro 12.9-inch (3rd generation)", pro129, finishesPro),
        iPad("ipad-air-3", "iPad Air (3rd generation)", pro105, finishesClassic, homeButton: true),
        iPad("ipad-mini-5", "iPad mini (5th generation)", mini4, finishesClassic, homeButton: true),
        iPad("ipad-7", "iPad (7th generation)", ipad102, finishesClassic, homeButton: true),
        iPad("ipad-pro-11-2", "iPad Pro 11-inch (2nd generation)", pro11, finishesPro),
        iPad("ipad-pro-12-9-4", "iPad Pro 12.9-inch (4th generation)", pro129, finishesPro),
        iPad("ipad-8", "iPad (8th generation)", ipad102, finishesClassic, homeButton: true),
        iPad("ipad-air-4", "iPad Air (4th generation)", air109, finishesAir4),
        iPad("ipad-pro-11-3", "iPad Pro 11-inch (3rd generation)", pro11, finishesPro),
        iPad("ipad-pro-12-9-5", "iPad Pro 12.9-inch (5th generation)", pro129, finishesPro),
        iPad("ipad-9", "iPad (9th generation)", ipad102, Array(finishesClassic.prefix(2)), homeButton: true),
        iPad("ipad-mini-6", "iPad mini (6th generation)", mini6, finishesMini6),
        iPad("ipad-air-5", "iPad Air (5th generation)", air109, finishesAir5),
        iPad("ipad-10", "iPad (10th generation)", air109, finishesIPad10, landscapeCamera: true),
        iPad("ipad-pro-11-4", "iPad Pro 11-inch (4th generation)", pro11, finishesPro),
        iPad("ipad-pro-12-9-6", "iPad Pro 12.9-inch (6th generation)", pro129, finishesPro),
        iPad("ipad-air-11-m2", "iPad Air 11-inch (M2)", air109, finishesAirM, landscapeCamera: true),
        iPad("ipad-air-13-m2", "iPad Air 13-inch (M2)", pro129, finishesAirM, landscapeCamera: true),
        iPad("ipad-pro-11-m4", "iPad Pro 11-inch (M4)", pro11M4, finishesProBlack, landscapeCamera: true),
        iPad("ipad-pro-13-m4", "iPad Pro 13-inch (M4)", pro13M4, finishesProBlack, landscapeCamera: true),
        iPad("ipad-mini-a17-pro", "iPad mini (A17 Pro)", mini6, finishesMiniA17),
        iPad("ipad-a16", "iPad (A16)", air109, finishesIPad10, landscapeCamera: true),
        iPad("ipad-air-11-m3", "iPad Air 11-inch (M3)", air109, finishesAirM, landscapeCamera: true),
        iPad("ipad-air-13-m3", "iPad Air 13-inch (M3)", pro129, finishesAirM, landscapeCamera: true),
        iPad("ipad-pro-11-m5", "iPad Pro 11-inch (M5)", pro11M4, finishesProBlack, landscapeCamera: true),
        iPad("ipad-pro-13-m5", "iPad Pro 13-inch (M5)", pro13M4, finishesProBlack, landscapeCamera: true),
        iPad("ipad-air-11-m4", "iPad Air 11-inch (M4)", air109, finishesAirM, landscapeCamera: true),
        iPad("ipad-air-13-m4", "iPad Air 13-inch (M4)", pro129, finishesAirM, landscapeCamera: true),
    ]
}
