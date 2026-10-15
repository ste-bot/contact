import AppKit
import SwiftUI

/// Zoom for the contact sheet, done the native way: the AppKit scroll view behind the sheet magnifies itself.
///
/// AppKit handles the pinch directly — it tracks the fingers frame by frame, anchors on them, rubber-bands at
/// the limits and never re-lays out the sheet — so zoom feels like Preview or Photos. ⌘+ / ⌘− / ⌘0 animate the
/// same magnification around the middle of the view. The sheet itself is always laid out at fit width.
enum SheetZoom {
    static let range: ClosedRange<CGFloat> = 0.6...3
    static let step: CGFloat = 1.25

    static func clamp(_ zoom: CGFloat) -> CGFloat { min(max(zoom, range.lowerBound), range.upperBound) }
}

/// A handle on the `NSScrollView` behind the sheet's SwiftUI `ScrollView`.
@MainActor
final class SheetScroller {
    /// Told the magnification whenever a pinch or an animated zoom settles.
    var onMagnification: (CGFloat) -> Void = { _ in }

    private(set) weak var scrollView: NSScrollView?
    private var pinchEnded: NSObjectProtocol?

    /// Takes over a scroll view the first time it's seen (it's rebuilt if SwiftUI recreates the `ScrollView`).
    func adopt(_ found: NSScrollView) {
        guard found !== scrollView else { return }
        scrollView = found
        found.allowsMagnification = true
        found.minMagnification = SheetZoom.range.lowerBound
        found.maxMagnification = SheetZoom.range.upperBound
        if let pinchEnded { NotificationCenter.default.removeObserver(pinchEnded) }
        pinchEnded = NotificationCenter.default.addObserver(forName: NSScrollView.didEndLiveMagnifyNotification,
                                                            object: found, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.report() }
        }
    }

    /// Animates to `magnification` around the middle of what's on screen.
    func zoom(to magnification: CGFloat) {
        guard let scrollView else { return }
        let target = SheetZoom.clamp(magnification)
        let bounds = scrollView.contentView.bounds
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            scrollView.animator().setMagnification(target, centeredAt: center)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.report() }
        }
    }

    private func report() {
        if let scrollView { onMagnification(scrollView.magnification) }
    }
}

/// Placed inside the scroll view's content to find the enclosing `NSScrollView`.
struct SheetScrollerAccess: NSViewRepresentable {
    let scroller: SheetScroller

    func makeNSView(context: Context) -> NSView { Probe(scroller: scroller) }
    func updateNSView(_ view: NSView, context: Context) {}

    final class Probe: NSView {
        let scroller: SheetScroller
        init(scroller: SheetScroller) {
            self.scroller = scroller
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError("not used") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            adopt()
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            adopt()
        }

        private func adopt() {
            MainActor.assumeIsolated { if let found = enclosingScrollView { scroller.adopt(found) } }
        }
    }
}

/// Finds the frame under the pointer for hover-focus, click-to-focus, double-click and the loupe.
///
/// SwiftUI's own hit-testing doesn't account for the scroll view's magnification (at 2× a click lands on the
/// wrong frame), so the sheet does it itself: every frame cell registers its rect in the sheet's content space,
/// and one event monitor converts the pointer with AppKit — which does account for magnification — and looks it up.
@MainActor
final class SheetPointer {
    static let space = "sheetContent"

    private struct Entry {
        var rect: CGRect
        /// Maps a point in the cell to a normalised point in the upright image (for the loupe).
        var upright: (CGPoint) -> CGPoint
    }

    weak var model: ShootModel?
    weak var scroller: SheetScroller?
    private var entries: [String: Entry] = [:]
    private var monitor: Any?

    func register(_ id: String, rect: CGRect, upright: @escaping (CGPoint) -> CGPoint) {
        entries[id] = Entry(rect: rect, upright: upright)
    }

    func unregister(_ id: String) { entries[id] = nil }

    func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown]) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) ?? event }
        }
    }

    func uninstall() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard let model, let scrollView = scroller?.scrollView, let document = scrollView.documentView,
              let window = scrollView.window, event.window === window,
              model.fullscreenID == nil, !model.isEditingText, !model.isPrinting
        else { return event }
        window.acceptsMouseMovedEvents = true

        // Only the sheet itself: not the title bar or toolbar the content runs under, not outside the scroll view,
        // and not the banner floating at the foot of the bench.
        let inScroll = scrollView.convert(event.locationInWindow, from: nil)
        let overBanner = model.banner != nil && inScroll.y > scrollView.bounds.height - 120
        guard window.contentLayoutRect.contains(event.locationInWindow), scrollView.bounds.contains(inScroll), !overBanner else {
            if event.type != .leftMouseDown { model.loupe.hover = nil }
            return event
        }

        let point = document.convert(event.locationInWindow, from: nil)
        let hit = entries.first { $0.value.rect.contains(point) }

        switch event.type {
        case .leftMouseDown:
            guard let (id, _) = hit else { return event }
            if event.clickCount >= 2 { model.doubleClick(id) } else { model.click(id) }
            return nil
        default:
            if let (id, entry) = hit {
                model.hoverFocus(id)
                let local = CGPoint(x: point.x - entry.rect.minX, y: point.y - entry.rect.minY)
                // The frame is bigger on screen when zoomed in; the lens magnifies past that.
                model.loupe.hover = LoupeState.Hover(frameID: id, point: entry.upright(local),
                                                     magnifiedLongEdge: 1300 * max(1, scrollView.magnification))
            } else if model.loupe.hover != nil {
                model.loupe.hover = nil
            }
            return event
        }
    }
}
