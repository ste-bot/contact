import AppKit
import SwiftUI

@main
struct ProofPositiveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var app = AppModel.shared

    var body: some Scene {
        Window("Contact", id: "main") {
            RootView()
                .environment(app)
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1400, height: 950)
        .commands { ProofCommands(app: app) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // `swift run` launches a bare executable; make it a regular foreground app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        MainActor.assumeIsolated {
            // `ProofPositive <folder>` from a terminal opens that shoot.
            if let path = CommandLine.arguments.dropFirst().first(where: { !$0.hasPrefix("-") }) {
                AppModel.shared.open(URL(fileURLWithPath: path))
            }
            SelfCheck.runIfRequested()
        }
    }

    /// Folders dropped on the Dock icon.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Task { @MainActor in AppModel.shared.open(url) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { AppModel.shared.shoot?.saveNow() }
    }
}

@MainActor
struct ProofCommands: Commands {
    let app: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Shoot…") { app.presentOpenPanel() }
                .keyboardShortcut("o")
            Menu("Open Recent") {
                ForEach(app.recents, id: \.self) { url in
                    Button(url.lastPathComponent) { app.open(url) }
                }
            }
            Divider()
            Button("Back to Index") { app.close() }
                .disabled(app.shoot == nil)
                .keyboardShortcut("w", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .printItem) {}

        CommandMenu("Shoot") {
            Button("Print Selects…") { app.shoot?.preparePrint() }
                .keyboardShortcut("p")
            Button("Undo Print") { Task { await app.shoot?.undoPrint() } }
                .keyboardShortcut("z", modifiers: [.command, .option])
                .disabled(!(app.shoot?.canUndoPrint ?? false))
            Divider()
            Button("Reveal in Finder") {
                if let root = app.shoot?.shoot.root { NSWorkspace.shared.activateFileViewerSelecting([root]) }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }

        CommandGroup(after: .toolbar) {
            Button(app.shoot?.reprint == true ? "Show All Frames" : "Reprint Circled") { app.shoot?.reprint.toggle() }
                .keyboardShortcut("r")
            Button(app.shoot?.uprightVerticals == true ? "Lay Verticals Sideways" : "Upright Verticals") { app.shoot?.uprightVerticals.toggle() }
                .keyboardShortcut("u")
            Divider()
            Button("Zoom In") { app.shoot.map { $0.zoom = min($0.zoom * 1.25, 3) } }
                .keyboardShortcut("=")
            Button("Zoom Out") { app.shoot.map { $0.zoom = max($0.zoom / 1.25, 0.6) } }
                .keyboardShortcut("-")
            Button("Fit Width") { app.shoot?.zoom = 1 }
                .keyboardShortcut("0")
            Divider()
        }
    }
}
