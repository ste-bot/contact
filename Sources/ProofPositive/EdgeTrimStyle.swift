import ProofCore
import SwiftUI

/// How each edge trim looks. Ink stays with the roll (orange on colour, white on B&W); a trim
/// owns typeface, weights, spacing and the small marks real stock prints.
struct EdgeTrimStyle {
    enum HalfFrame { case triangle, arrow }

    let family: String
    /// Extra axes beyond weight (Archivo is set at its normal width here).
    var axes: [String: CGFloat] = [:]
    let makerWeight: CGFloat
    let detailWeight: CGFloat
    let numberWeight: CGFloat
    let halfWeight: CGFloat
    /// Letter-spacing as a fraction of the size.
    let tracking: CGFloat
    let halfFrame: HalfFrame
    var flanks = false
    var barcode = false
    var hairline = false

    static func of(_ trim: EdgeTrim) -> EdgeTrimStyle {
        switch trim {
        case .ricoh:
            EdgeTrimStyle(family: "Doto", makerWeight: 800, detailWeight: 800, numberWeight: 900, halfWeight: 800,
                          tracking: 0.08, halfFrame: .triangle)
        case .leica:
            EdgeTrimStyle(family: "Host Grotesk", makerWeight: 700, detailWeight: 400, numberWeight: 400, halfWeight: 500,
                          tracking: 0.16, halfFrame: .arrow, hairline: true)
        case .film:
            EdgeTrimStyle(family: "Archivo", axes: ["wdth": 100], makerWeight: 800, detailWeight: 400, numberWeight: 800, halfWeight: 700,
                          tracking: 0.05, halfFrame: .arrow, flanks: true, barcode: true)
        }
    }

    func font(_ size: CGFloat, weight: CGFloat) -> Font {
        var axes = axes
        axes["wght"] = weight
        let fallback = Font.system(size: size, weight: weight >= 650 ? .bold : .regular, design: family == "Doto" ? .monospaced : .default)
        return Typeface.variable(family, size: size, axes: axes, fallback: fallback)
    }

    /// `RICOH GR IV · ISO 400`, maker heavier than the rest; film adds ■■ either side, as Kodak colour stock does.
    func edgeLine(maker: String, detail: String, size: CGFloat, color: Color) -> Text {
        let track = size * tracking
        var line = Text(maker).font(font(size, weight: makerWeight)).tracking(track)
        if !detail.isEmpty {
            line = line + Text(" " + detail).font(font(size, weight: detailWeight)).tracking(track)
        }
        if flanks {
            let block = Text("■■").font(.system(size: size * 0.7)).tracking(size * 0.05)
            line = block + Text("  ") + line + Text("  ") + block
        }
        return line.foregroundColor(color)
    }

    func label(_ text: String, size: CGFloat, color: Color) -> Text {
        Text(text).font(font(size, weight: detailWeight)).tracking(size * tracking).foregroundColor(color)
    }

    func number(_ text: String, size: CGFloat, color: Color) -> Text {
        Text(text).font(font(size, weight: numberWeight)).foregroundColor(color)
    }

    func half(_ text: String, size: CGFloat, color: Color) -> Text {
        let body = halfFrame == .triangle ? "►" + text : text
        return Text(body).font(font(size, weight: halfWeight)).tracking(size * 0.04).foregroundColor(color)
    }
}
