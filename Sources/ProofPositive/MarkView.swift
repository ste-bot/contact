import ProofCore
import SwiftUI

/// A safelight-red grease-pencil mark. Each frame's stroke is randomised from its id, so it's hand-made but stable.
/// `progress` draws the strokes on in order; it's animatable so a fresh mark can be drawn like a real pencil stroke.
@MainActor
struct MarkView: View, Animatable {
    let mark: Mark
    let seed: String
    var lineWidth: CGFloat = 4
    var progress: CGFloat = 1
    /// A single small symbol — loop, star or cross — for counts and legends.
    var glyph = false

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let strokes = strokes(in: CGRect(origin: .zero, size: size).insetBy(dx: lineWidth, dy: lineWidth))
            // Strokes are drawn one after another, each taking an equal share of the progress.
            for (index, path) in strokes.enumerated() {
                let share = min(max(progress * CGFloat(strokes.count) - CGFloat(index), 0), 1)
                guard share > 0 else { continue }
                pencil(share < 1 ? path.trimmedPath(from: 0, to: share) : path, in: &context)
            }
        }
        .allowsHitTesting(false)
    }

    private func strokes(in rect: CGRect) -> [Path] {
        var rng = SeededRandom(seed)
        switch (mark, glyph) {
        case (.select, _):
            return [GreasePencil.loop(in: rect, rng: &rng)]
        case (.hero, true):
            return [GreasePencil.star(center: CGPoint(x: rect.midX, y: rect.midY), radius: min(rect.width, rect.height) / 2, rng: &rng)]
        case (.hero, false):
            let r = min(rect.width, rect.height) * 0.13
            return [
                GreasePencil.loop(in: rect, rng: &rng),
                GreasePencil.loop(in: rect.insetBy(dx: rect.width * 0.035, dy: rect.height * 0.05), rng: &rng),
                GreasePencil.star(center: CGPoint(x: rect.maxX - r * 0.9, y: rect.minY + r * 0.9), radius: r, rng: &rng),
            ]
        case (.reject, _):
            let inset = glyph ? 0.1 : 0.16
            return GreasePencil.cross(in: rect.insetBy(dx: rect.width * inset, dy: rect.height * inset), rng: &rng)
        }
    }

    /// Two passes — a dense core and a thin offset ghost — read as wax on glossy paper.
    private func pencil(_ path: Path, in context: inout GraphicsContext) {
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        context.stroke(path, with: .color(Theme.safelight.opacity(0.9)), style: style)
        context.stroke(path.offsetBy(dx: lineWidth * 0.18, dy: lineWidth * 0.12),
                       with: .color(Theme.safelight.opacity(0.35)),
                       style: StrokeStyle(lineWidth: lineWidth * 0.45, lineCap: .round, lineJoin: .round))
    }
}

enum GreasePencil {
    /// An ellipse drawn in one go: it wobbles, drifts outward, and overshoots where it started.
    static func loop(in rect: CGRect, rng: inout SeededRandom) -> Path {
        let center = CGPoint(x: rect.midX + rng.range(-0.02...0.02) * rect.width, y: rect.midY + rng.range(-0.02...0.02) * rect.height)
        let rx = rect.width / 2, ry = rect.height / 2
        let start = rng.range(0...(2 * .pi))
        let sweep = 2 * CGFloat.pi + rng.range(0.25...0.5)
        let tilt = rng.range(-0.05...0.05)
        let phase1 = rng.range(0...(2 * .pi)), phase2 = rng.range(0...(2 * .pi))
        let drift = rng.range(0.03...0.07)

        var path = Path()
        let steps = 90
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let angle = start + sweep * t
            let wobble = 1 + 0.025 * sin(3 * angle + phase1) + 0.015 * sin(5 * angle + phase2)
            let scale = wobble * (0.97 + drift * t)
            let x = cos(angle) * rx * scale, y = sin(angle) * ry * scale
            let point = CGPoint(x: center.x + x * cos(tilt) - y * sin(tilt), y: center.y + x * sin(tilt) + y * cos(tilt))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    /// A pentagram drawn in a single stroke, the way people actually draw stars.
    static func star(center: CGPoint, radius: CGFloat, rng: inout SeededRandom) -> Path {
        let rotation = rng.range(-0.2...0.2) - .pi / 2
        var path = Path()
        for i in 0...5 {
            let angle = rotation + CGFloat(i * 2 % 5) * 2 * .pi / 5
            let r = radius * rng.range(0.9...1.08)
            let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    /// Two slightly bowed strokes, returned separately so they draw on one after the other.
    static func cross(in rect: CGRect, rng: inout SeededRandom) -> [Path] {
        [(CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY)),
         (CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.minX, y: rect.maxY))].map { a, b in
            let start = CGPoint(x: a.x + rng.range(-0.04...0.04) * rect.width, y: a.y + rng.range(-0.04...0.04) * rect.height)
            let end = CGPoint(x: b.x + rng.range(-0.04...0.04) * rect.width, y: b.y + rng.range(-0.04...0.04) * rect.height)
            let mid = CGPoint(x: (start.x + end.x) / 2 + rng.range(-0.05...0.05) * rect.width,
                              y: (start.y + end.y) / 2 + rng.range(-0.05...0.05) * rect.height)
            var path = Path()
            path.move(to: start)
            path.addQuadCurve(to: end, control: mid)
            return path
        }
    }
}

/// A mark that draws itself on when it has just been made, and appears instantly otherwise
/// (scrolling back to it, reopening the shoot, Reduce Motion).
@MainActor
struct DrawnMark: View {
    let mark: Mark
    let seed: String
    var lineWidth: CGFloat = 4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat

    init(mark: Mark, seed: String, lineWidth: CGFloat = 4, fresh: Bool) {
        self.mark = mark
        self.seed = seed
        self.lineWidth = lineWidth
        _progress = State(initialValue: fresh ? 0 : 1)
    }

    var body: some View {
        MarkView(mark: mark, seed: seed, lineWidth: lineWidth, progress: progress)
            .onAppear {
                guard progress < 1 else { return }
                if reduceMotion {
                    progress = 1
                } else {
                    // Quick enough to keep up with a fast cull; a hero's three strokes get a little longer.
                    withAnimation(.easeOut(duration: mark == .hero ? 0.34 : 0.2)) { progress = 1 }
                }
            }
    }
}
