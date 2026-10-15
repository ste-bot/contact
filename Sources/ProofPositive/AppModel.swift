import AppKit
import Observation
import ProofCore

@Observable
@MainActor
final class AppModel {
    static let shared = AppModel()

    struct Loading {
        var name: String
        var progress: Double
    }

    private(set) var shoot: ShootModel?
    private(set) var loading: Loading?
    private(set) var recents: [URL] = []

    @ObservationIgnored private var openTask: Task<Void, Never>?
    private static let recentsKey = "recentShoots"

    init() {
        recents = (UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? []).map { URL(fileURLWithPath: $0) }
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Shoot"
        panel.message = "Choose a shoot folder. Every subfolder becomes a roll."
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }

    func open(_ url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { return }

        shoot?.saveNow()
        openTask?.cancel()
        loading = Loading(name: url.lastPathComponent, progress: 0)
        openTask = Task {
            let scanned = await ShootScanner.scan(url) { fraction in
                Task { @MainActor in AppModel.shared.loading?.progress = fraction }
            }
            guard !Task.isCancelled else { return }
            let saved = ShootDocument.load(from: scanned.root)
            var document = saved
            document.reconcile(with: scanned.frames)
            shoot = ShootModel(shoot: scanned, document: document, savedDocument: saved)
            loading = nil
            remember(scanned.root)
        }
    }

    func close() {
        shoot?.saveNow()
        openTask?.cancel()
        shoot = nil
        loading = nil
    }

    private func remember(_ url: URL) {
        recents.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
        recents.insert(url, at: 0)
        recents = Array(recents.prefix(12))
        UserDefaults.standard.set(recents.map(\.path), forKey: Self.recentsKey)
    }
}
