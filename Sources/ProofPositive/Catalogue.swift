import AppKit
import SwiftUI

/// The catalogue checklist: the app's one recurring move. Shoots, rolls and frames are indexed entries
/// ([01], R01 · 017) on hairline rules, with label/value caption blocks, like an exhibition checklist.

/// A small caps label: Archivo SemiCondensed bold, tracked out.
struct CatalogueLabel: View {
    let text: String
    var size: CGFloat = 11
    var color: Color = Theme.paper.opacity(0.55)

    init(_ text: String, size: CGFloat = 11, color: Color = Theme.paper.opacity(0.55)) {
        self.text = text
        self.size = size
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.label(size))
            .tracking(size * 0.08)
            .foregroundStyle(color)
    }
}

/// A bracketed index: `[01]`, `[R01]`, `[S]`.
struct CatalogueIndex: View {
    let text: String
    var size: CGFloat = 12
    var color: Color = Theme.paper.opacity(0.55)

    init(_ text: String, size: CGFloat = 12, color: Color = Theme.paper.opacity(0.55)) {
        self.text = text
        self.size = size
        self.color = color
    }

    init(number: Int, size: CGFloat = 12, color: Color = Theme.paper.opacity(0.55)) {
        self.init(String(format: "%02d", number), size: size, color: color)
    }

    var body: some View {
        Text("[\(text)]")
            .font(Theme.mono(size))
            .monospacedDigit()
            .foregroundStyle(color)
    }
}

/// A one-pixel rule.
struct Hairline: View {
    var color: Color = Theme.rule

    var body: some View {
        Rectangle().fill(color).frame(height: 1)
    }
}

/// Label/value rows, the caption block from an exhibition checklist. Labels in caps, values as set.
struct CaptionGrid: View {
    let rows: [(label: String, value: String)]
    var labelWidth: CGFloat = 76
    var size: CGFloat = 12
    var ink: Color = Theme.paper

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    CatalogueLabel(row.label, size: size - 2, color: ink.opacity(0.55))
                        .frame(width: labelWidth, alignment: .leading)
                    Text(row.value)
                        .font(Theme.mono(size))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }
}

/// Sets the window up once: a transparent title bar with content running beneath it. The launch screen uses
/// that to go edge to edge; the contact sheet puts its toolbar on a flat bench-black bar. The style is never
/// switched between screens, so the window (and macOS full screen) keeps its size when you go back and forth.
struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ChromeView() }
    func updateNSView(_ view: NSView, context: Context) {}

    /// Transparent title bar, content running beneath it. Safe to call repeatedly: it only changes a window
    /// that isn't already set up, so an already-styled window never resizes.
    static func apply(to window: NSWindow?) {
        guard let window else { return }
        if !window.titlebarAppearsTransparent { window.titlebarAppearsTransparent = true }
        if !window.styleMask.contains(.fullSizeContentView) { window.styleMask.insert(.fullSizeContentView) }
    }

    /// Applies the style once the view joins its window. SwiftUI resets `titlebarAppearsTransparent` when it
    /// rebuilds a screen's toolbar, so the view also watches that flag and puts it back.
    final class ChromeView: NSView {
        private var watch: NSKeyValueObservation?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            watch = nil
            guard let window else { return }
            WindowChrome.apply(to: window)
            watch = window.observe(\.titlebarAppearsTransparent) { window, _ in
                guard !window.titlebarAppearsTransparent else { return }
                DispatchQueue.main.async { WindowChrome.apply(to: window) }
            }
        }
    }
}

/// Shows or hides the window's title text for the current screen. The index hides it (the wordmark is the
/// title, and a visible title draws a title-bar strip over the photo); the contact sheet shows the shoot name.
/// Only the title text changes, never the window style, so the content keeps its size.
struct WindowTitleVisibility: NSViewRepresentable {
    let visible: Bool

    func makeNSView(context: Context) -> NSView {
        let view = TitleView()
        view.visible = visible
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        (view as? TitleView)?.visible = visible
    }

    final class TitleView: NSView {
        var visible = true { didSet { apply() } }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }
        private func apply() {
            // SwiftUI can reapply its own title-bar setup when a screen's toolbar changes, so the window
            // style is re-asserted here too, after it.
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.window else { return }
                window.titleVisibility = self.visible ? .visible : .hidden
                WindowChrome.apply(to: window)
            }
        }
    }
}
