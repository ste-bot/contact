import AppKit
import ProofCore

/// Drives the UI through a script and snapshots its own window, for checking the app without
/// Screen Recording permission. Inert unless PROOF_SELFCHECK is set, e.g.
///
///     PROOF_SELFCHECK=/tmp/out PROOF_STEPS="snap:sheet;mark:3:select;snap:marked;quit" ProofPositive <shoot>
///
/// Steps: `wait:<seconds>`, `snap:<name>`, `open:<folder>`, `focus:<n>`, `mark:<n>:<select|hero|reject|clear>`, `reprint`,
/// `upright`, `zoom:<x>`, `fullscreen`, `close`, `loupe:<n>:<x>,<y>`, `macfullscreen`, `index`, `windowinfo` (prints the window style flags), `print`, `undo`, `quit`.
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
        case "zoom": model.zoom = CGFloat(Double(parts[1]) ?? 1)
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
