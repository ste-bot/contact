import AppKit
import SwiftUI

/// Black and white: a darkroom bench, black film, cream proof paper and paper-white ink. The one hue is
/// safelight red, and it belongs to the grease pencil alone. Actions are square paper blocks (`BlockButtonStyle`).
enum Theme {
    static let bench = Color(red: 0.102, green: 0.098, blue: 0.090)
    static let paper = Color(red: 0.937, green: 0.922, blue: 0.890)
    static let film = Color(red: 0.050, green: 0.047, blue: 0.044)
    static let ink = Color(red: 0.165, green: 0.153, blue: 0.141)
    /// Secondary text on paper: 4.8:1, legible at sheet sizes (the old 50% ink was 2.9:1).
    static let inkMuted = Color(red: 0.420, green: 0.404, blue: 0.376)
    static let safelight = Color(red: 0.843, green: 0.169, blue: 0.118)
    /// Hairlines on the bench and film: paper at 14%.
    static let rule = Color(red: 0.937, green: 0.922, blue: 0.890, opacity: 0.14)
    /// White chinagraph, the colour of the drawn mark.
    static let wax = Color(red: 0.953, green: 0.941, blue: 0.902)
    /// Edge printing on colour stock.
    static let edgeColor = Color(red: 0.902, green: 0.604, blue: 0.231)
    /// Edge printing on B&W stock.
    static let edgeMono = Color(red: 0.910, green: 0.890, blue: 0.850)

    /// The CONTACT wordmark: Archivo ExtraCondensed Black.
    static func wordmark(_ size: CGFloat) -> Font {
        Typeface.variable("Archivo", size: size, axes: ["wdth": 62, "wght": 900], fallback: .system(size: size, weight: .black).width(.compressed))
    }
    /// What's typed on the sheet and the bench's titles: Archivo SemiCondensed.
    static func sheet(_ size: CGFloat, weight: CGFloat = 650) -> Font {
        Typeface.variable("Archivo", size: size, axes: ["wdth": 87, "wght": weight], fallback: .system(size: size, weight: weight >= 600 ? .semibold : .regular).width(.condensed))
    }
    /// Catalogue titles and big numerals: Archivo at regular width, light.
    static func display(_ size: CGFloat, weight: CGFloat = 380) -> Font {
        Typeface.variable("Archivo", size: size, axes: ["wdth": 100, "wght": weight], fallback: .system(size: size, weight: .light))
    }
    /// Caps labels: Archivo SemiCondensed bold. Set upper-case and tracked by `CatalogueLabel`.
    static func label(_ size: CGFloat, weight: CGFloat = 700) -> Font {
        Typeface.variable("Archivo", size: size, axes: ["wdth": 87, "wght": weight], fallback: .system(size: size, weight: .bold).width(.condensed))
    }
    /// The app's own voice — counts, states, labels, banners: Geist Mono.
    static func mono(_ size: CGFloat, weight: CGFloat = 500) -> Font {
        Typeface.variable("Geist Mono", size: size, axes: ["wght": weight], fallback: .system(size: size, weight: .medium, design: .monospaced))
    }
}

/// Bundled variable fonts (Resources/Fonts, registered by the app bundle), set by axis.
/// Falls back to a system face if a font isn't installed, so the app never renders blank text.
enum Typeface {
    static func variable(_ family: String, size: CGFloat, axes: [String: CGFloat], fallback: Font) -> Font {
        nsFont(family, size: size, axes: axes).map(Font.init) ?? fallback
    }

    /// The same face as an AppKit font, for the few controls drawn by AppKit (the inline editor).
    static func nsFont(_ family: String, size: CGFloat, axes: [String: CGFloat]) -> NSFont? {
        guard NSFontManager.shared.availableMembers(ofFontFamily: family) != nil else { return nil }
        let variation = Dictionary(uniqueKeysWithValues: axes.map { (tag($0.key), $0.value) })
        let descriptor = NSFontDescriptor(fontAttributes: [
            .family: family,
            NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variation,
        ])
        return NSFont(descriptor: descriptor, size: size)
    }

    /// OpenType axis tags are four ASCII bytes read as one integer: "wght" → 0x77676874.
    private static func tag(_ name: String) -> Int {
        name.utf8.reduce(0) { $0 << 8 | Int($1) }
    }
}

/// Deterministic randomness, so a frame's grease-pencil mark looks the same every time it's drawn.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(_ seed: String) {
        // FNV-1a; String.hashValue is randomised per launch.
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        state = hash
    }

    mutating func next() -> UInt64 {
        // SplitMix64
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }

    mutating func unit() -> CGFloat { CGFloat(Double(next() >> 11) / Double(1 << 53)) }
    mutating func range(_ r: ClosedRange<CGFloat>) -> CGFloat { r.lowerBound + unit() * (r.upperBound - r.lowerBound) }
}
