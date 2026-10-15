import Foundation

/// The edge print a roll gets. Like real film stocks, each camera family prints its own edge:
/// its own typeface, numbering and marks. Add a case and a rule when a new camera arrives.
public enum EdgeTrim: String, Sendable, CaseIterable {
    /// Dot-matrix, after Fujifilm and lab printers.
    case ricoh
    /// Quiet and exact: hairline rule, light numerals.
    case leica
    /// After Kodak: flanking blocks, bold numerals, half-frames over an arrow, DX barcode.
    case film

    /// Camera-maker rules for digital rolls, checked in order. Anything unmatched prints as `film`.
    public static let rules: [(prefix: String, trim: EdgeTrim)] = [
        ("RICOH", .ricoh),
        ("LEICA", .leica),
    ]

    public static func trim(for roll: Roll) -> EdgeTrim {
        guard roll.kind == .digital else { return .film }
        // The camera most of the roll was shot on decides; a stray frame from another body doesn't.
        let models = roll.frames.compactMap { $0.info.cameraModel?.uppercased() }
        let counts = Dictionary(models.map { ($0, 1) }, uniquingKeysWith: +)
        guard let model = counts.max(by: { $0.value < $1.value })?.key else { return .film }
        return rules.first { model.hasPrefix($0.prefix) }?.trim ?? .film
    }
}

extension ImageInfo {
    /// The edge text split the way film prints it: the maker set heavier, the rest lighter.
    /// `RICOH GR IV · ISO 400` → (`RICOH`, `GR IV · ISO 400`).
    public var edgeParts: (maker: String, detail: String) {
        Self.split(edgeText)
    }

    static func split(_ text: String) -> (maker: String, detail: String) {
        let parts = text.split(separator: " ", maxSplits: 1).map(String.init)
        return (parts.first ?? text, parts.count > 1 ? parts[1] : "")
    }
}

extension EdgeTrim {
    /// A lab roll's stock name split the same way: `HP5 PLUS 400` → (`HP5`, `PLUS 400`).
    public static func split(stock: String) -> (maker: String, detail: String) {
        ImageInfo.split(stock.uppercased())
    }
}
