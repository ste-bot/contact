import AppKit
import ProofCore

/// Drives the UI through a script and snapshots its own window, for checking the app without
/// Screen Recording permission. Inert unless PROOF_SELFCHECK is set, e.g.
///
///     PROOF_SELFCHECK=/tmp/out PROOF_STEPS="snap:sheet;mark:3:select;snap:marked;quit" ProofPositive <shoot>
///
/// Steps: `wait:<seconds>`, `snap:<name>`, `open:<folder>`, `focus:<n>`, `mark:<n>:<select|hero|reject|clear>`, `reprint`,
/// `upright`, `zoom:<x>`, `fullscreen`, `close`, `loupe:<n>:<x>,<y>`, `macfullscreen`, `index`, `windowinfo` (prints the window style flags), `zoominfo`, `location:<text>`, `type:<text>`, `key:<return|esc|tab>`, `editinfo` (the field editor's text and selection),
/// `clickat:<x>,<y>` / `hoverat:<x>,<y>` (synthetic pointer events in window points; set PROOF_NOHOVER=1 so the real
/// pointer resting on the window can't move focus), `print`, `undo`, `quit`.
/// `<n>` is the 1-based frame index on the sheet.
@MainActor
enum SelfCheck {
    static func runIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard let outDir = env["PROOF_SELFCHECK"] else { return }
        let steps = (env["PROOF_STEPS"] ?? "wait:4;snap:sheet;quit").split(separator: ";").map(String.init)
        Task {
            // Let a shoot passed on the command line finish scanning; otherwise start at the launch screen.
            if CommandLine.arguments.dropFirst().contains(where: { !$0.hasPrefix("-") }) {
                while AppModel.shared.shoot == nil { try? await Task.sleep(for: .milliseconds(200)) }
            }
            try? await Task.sleep(for: .seconds(2))
            for step in steps { await run(step, outDir: URL(fileURLWithPath: outDir)) }
        }
    }

    private static func run(_ step: String, outDir: URL) async {
        let parts = step.split(separator: ":").map(String.init)
        switch parts[0] {
        case "wait": try? await Task.sleep(for: .seconds(Double(parts[1]) ?? 1)); return
        case "snap": snapshot(to: outDir.appending(path: "\(parts[1]).png")); return
        case "open": AppModel.shared.open(URL(fileURLWithPath: parts.dropFirst().joined(separator: ":"))); return
        case "quit": NSApp.terminate(nil); return
        case "macfullscreen":
            NSApp.windows.first { $0.isVisible }?.toggleFullScreen(nil)
            try? await Task.sleep(for: .seconds(2))
            return
        case "index": AppModel.shared.close(); try? await Task.sleep(for: .seconds(1)); return
        case "hoverat":
            // A synthetic mouse move at a point in the window (points from the top-left), to check hit-testing.
            let xy = parts[1].split(separator: ",").compactMap { Double($0) }
            if let window = NSApp.windows.first(where: { $0.isVisible }), xy.count == 2 {
                let location = NSPoint(x: xy[0], y: window.contentView!.bounds.height - xy[1])
                for dx in [0.0, 1.0] {
                    if let event = NSEvent.mouseEvent(with: .mouseMoved, location: NSPoint(x: location.x + dx, y: location.y), modifierFlags: [],
                                                      timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                                                      context: nil, eventNumber: 0, clickCount: 0, pressure: 0) {
                        NSApp.sendEvent(event)
                    }
                }
            }
            try? await Task.sleep(for: .milliseconds(300))
            print("HOVER at=\(parts[1]) focused=\(AppModel.shared.shoot?.focusedID ?? "nil") loupe=\(String(describing: AppModel.shared.shoot?.loupe.hover))")
            return
        case "clickat":
            let xy = parts[1].split(separator: ",").compactMap { Double($0) }
            if let window = NSApp.windows.first(where: { $0.isVisible }), xy.count == 2 {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                try? await Task.sleep(for: .milliseconds(200))
                let location = NSPoint(x: xy[0], y: window.contentView!.bounds.height - xy[1])
                for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                    if let event = NSEvent.mouseEvent(with: type, location: location, modifierFlags: [],
                                                      timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                                                      context: nil, eventNumber: 0, clickCount: 1, pressure: 1) {
                        NSApp.sendEvent(event)
                    }
                }
            }
            try? await Task.sleep(for: .milliseconds(500))
            print("CLICK at=\(parts[1]) focused=\(AppModel.shared.shoot?.focusedID ?? "nil")")
            return
        case "location":
            AppModel.shared.shoot?.location = parts.dropFirst().joined(separator: ":")
            try? await Task.sleep(for: .milliseconds(500))
            return
        case "type", "key":
            // Synthetic keystrokes to the key window: `type:<text>`, or `key:return` / `key:esc` / `key:tab`.
            guard let window = NSApp.windows.first(where: { $0.isVisible }) else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            let special: [String: (String, UInt16)] = ["return": ("\r", 36), "esc": ("\u{1b}", 53), "tab": ("\t", 48)]
            let strokes: [(String, UInt16)] = parts[0] == "key" ? [special[parts[1]] ?? ("", 0)] : parts.dropFirst().joined(separator: ":").map { (String($0), 0) }
            for (chars, code) in strokes {
                for type in [NSEvent.EventType.keyDown, .keyUp] {
                    if let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                                    windowNumber: window.windowNumber, context: nil, characters: chars,
                                                    charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code) {
                        NSApp.sendEvent(event)
                    }
                }
            }
            try? await Task.sleep(for: .milliseconds(300))
            print("TYPED \(parts.joined(separator: ":")) location=\(AppModel.shared.shoot?.location ?? "nil")")
            return
        case "editinfo":
            // What the keyboard is in right now: the text and the selected range of the field being edited.
            let responder = NSApp.windows.first(where: { $0.isVisible })?.firstResponder
            if let editor = responder as? NSTextView {
                print("EDIT text=\(editor.string) selected=\(editor.selectedRange()) length=\((editor.string as NSString).length)")
            } else {
                print("EDIT responder=\(responder.map { String(describing: type(of: $0)) } ?? "nil")")
            }
            return
        case "zoominfo":
            if let sv = NSApp.windows.first(where: { $0.isVisible })?.contentView.flatMap(Self.findScrollView) {
                print("ZOOMINFO magnification=\(sv.magnification) clip=\(sv.contentView.bounds) doc=\(sv.documentView?.frame ?? .zero)")
            }
            return
        case "windowinfo":
            for w in NSApp.windows where w.isVisible {
                print("WINDOW fullSize=\(w.styleMask.contains(.fullSizeContentView)) transparent=\(w.titlebarAppearsTransparent) title=\(w.titleVisibility == .visible) toolbar=\(w.toolbar != nil) toolbarVisible=\(w.toolbar?.isVisible ?? false) style=\(w.toolbarStyle.rawValue) sep=\(w.titlebarSeparatorStyle.rawValue)")
            }
            return
        default: break
        }
        guard let model = AppModel.shared.shoot else { return }
        let frames = model.visibleFrames
        func frame(_ s: String) -> Frame? { Int(s).flatMap { frames.indices.contains($0 - 1) ? frames[$0 - 1] : nil } }

        switch parts[0] {
        case "focus": model.focusedID = frame(parts[1])?.id
        case "mark":
            if let f = frame(parts[1]) { model.setMark(Mark(rawValue: parts[2]), for: f.id) }
        case "reprint": model.reprint.toggle()
        case "upright": model.uprightVerticals.toggle()
        case "zoom": model.requestZoom(CGFloat(Double(parts[1]) ?? 1))
        case "fullscreen": model.openFullscreen()
        case "close": model.fullscreenID = nil
        case "loupe":
            if let f = frame(parts[1]) {
                let xy = parts[2].split(separator: ",").compactMap { Double($0) }
                // In full screen the view asks for 3× the fitted frame; approximate a 1400pt-wide fit.
                model.loupe.hover = .init(frameID: f.id, point: CGPoint(x: xy[0], y: xy[1]),
                                          magnifiedLongEdge: model.fullscreenID == nil ? 1300 : 4200)
                model.loupe.cursor = CGPoint(x: 500, y: 400)
                model.loupe.isHeld = true
            }
        case "print":
            model.preparePrint()
            await model.confirmPrint()
        case "undo": await model.undoPrint()
        default: break
        }
        try? await Task.sleep(for: .milliseconds(1200))
    }

    private static func findScrollView(_ view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView, scroll.allowsMagnification { return scroll }
        for sub in view.subviews { if let found = findScrollView(sub) { return found } }
        return nil
    }

    private static func snapshot(to url: URL) {
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }) else { return }
        // Render the view hierarchy itself; window-list capture needs Screen Recording permission.
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
