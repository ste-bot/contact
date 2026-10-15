import SwiftUI

/// The CONTACT mark: a box drawn in wax pencil. The strokes live in Resources/Brand/wax-box.json,
/// shared with scripts/make-icon.swift so the app icon and the in-app mark are the same drawing.
enum WaxBox {
    struct Data: Decodable {
        let grid: CGFloat
        let markBounds: [CGFloat]
        let strokes: String
        let secondPass: String
    }

    static let data: Data? = Bundle.main.url(forResource: "wax-box", withExtension: "json", subdirectory: "Brand")
        .flatMap { try? Foundation.Data(contentsOf: $0) }
        .flatMap { try? JSONDecoder().decode(Data.self, from: $0) }

    static let strokes = data.map { path($0.strokes) } ?? Path()
    static let secondPass = data.map { path($0.secondPass) } ?? Path()
    /// The drawn box's own extent on the 1024 grid, overshoots included.
    static let bounds: CGRect = data.map { CGRect(x: $0.markBounds[0], y: $0.markBounds[1], width: $0.markBounds[2], height: $0.markBounds[3]) }
        ?? CGRect(x: 244, y: 190, width: 536, height: 628)

    /// Parses the outline data, which only ever uses absolute M, L and Z.
    static func path(_ d: String) -> Path {
        var path = Path()
        var numbers: [CGFloat] = []
        var command: Character = "M"
        func flush() {
            guard numbers.count >= 2 else { return }
            let point = CGPoint(x: numbers[0], y: numbers[1])
            command == "M" ? path.move(to: point) : path.addLine(to: point)
            numbers.removeAll()
        }
        var token = ""
        for c in d {
            if c == "M" || c == "L" || c == "Z" {
                if let n = Double(token) { numbers.append(n) }
                token = ""
                flush()
                if c == "Z" { path.closeSubpath() } else { command = c }
            } else if c == " " || c == "," {
                if let n = Double(token) { numbers.append(n) }
                token = ""
                if numbers.count == 2 { flush(); if command == "M" { command = "L" } }
            } else {
                token.append(c)
            }
        }
        if let n = Double(token) { numbers.append(n) }
        flush()
        return path
    }
}

/// The drawn box on its own, scaled to fit. Wax grain is knocked out of the stroke at a fixed
/// density, seeded so it never shimmers between redraws.
struct WaxBoxMark: View {
    var color: Color = Theme.wax

    var body: some View {
        Canvas { context, size in
            let b = WaxBox.bounds
            let scale = min(size.width / b.width, size.height / b.height)
            let transform = CGAffineTransform(translationX: -b.minX, y: -b.minY)
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: (size.width - b.width * scale) / 2, y: (size.height - b.height * scale) / 2))

            context.drawLayer { layer in
                layer.fill(WaxBox.strokes.applying(transform), with: .color(color.opacity(0.94)))
                layer.fill(WaxBox.secondPass.applying(transform), with: .color(color.opacity(0.7)))
                // Grain only reads above a few hundred points; below that it would just grey the line.
                guard size.height > 60 else { return }
                layer.blendMode = .destinationOut
                var rng = SeededRandom("contact-wax")
                // Wax pits are tiny and drag along the stroke: sideways on the top and bottom bars, upright on the sides.
                for _ in 0..<5200 {
                    let gx = b.minX + rng.unit() * b.width, gy = b.minY + rng.unit() * b.height
                    let r = (0.7 + rng.unit() * 1.6) * scale
                    let sideways = abs(gy - 250) < 70 || abs(gy - 766) < 70
                    let w = r * (sideways ? 3.2 : 1.1), h = r * (sideways ? 1.1 : 3.2)
                    let p = CGPoint(x: gx, y: gy).applying(transform)
                    layer.fill(Path(ellipseIn: CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h)), with: .color(.black.opacity(0.45 + rng.unit() * 0.45)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The lock-up: the drawn box beside the typeset name, a little taller than the caps.
/// The mark never stands in for a letter.
struct Wordmark: View {
    var size: CGFloat
    var ink: Color = Theme.paper
    var mark: Color = Theme.wax

    var body: some View {
        HStack(spacing: size * 0.24) {
            WaxBoxMark(color: mark)
                .frame(width: size * 0.82, height: size * 0.96)
            Text("CONTACT")
                .font(Theme.wordmark(size))
                .foregroundStyle(ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Contact")
    }
}
