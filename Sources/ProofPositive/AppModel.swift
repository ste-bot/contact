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
    /// Where each recent shoot is, as of the last look. Rechecked when the app comes forward or a drive mounts.
    private(set) var recentStatus: [URL: ShootLocation.Status] = [:]

    @ObservationIgnored private var openTask: Task<Void, Never>?
    /// Bookmarks keyed by path, so a recent shoot renamed or moved on the same drive is followed.
    @ObservationIgnored private var bookmarks: [String: Data] = [:]
    private static let recentsKey = "recentShoots"
    private static let bookmarksKey = "recentShootBookmarks"

    init() {
        recents = (UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? []).map { URL(fileURLWithPath: $0) }
        bookmarks = UserDefaults.standard.dictionary(forKey: Self.bookmarksKey) as? [String: Data] ?? [:]
        refreshRecents()
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification, NSWorkspace.didRenameVolumeNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { _ in MainActor.assumeIsolated { AppModel.shared.refreshRecents() } }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { AppModel.shared.refreshRecents() }
        }
    }

    func status(of url: URL) -> ShootLocation.Status { recentStatus[url] ?? ShootLocation.status(of: url) }

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
        guard ShootLocation.status(of: url) == .available else {
            // A recent shoot that isn't where it was: ask where it went.
            if recents.contains(url) { locate(url) }
            return
        }

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

    /// Asks where a recent shoot has gone, replaces the stale entry and opens it.
    func locate(_ url: URL) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = ShootLocation.nearestExistingAncestor(of: url)
        panel.prompt = "Open Shoot"
        if case .driveNotConnected(let volume) = status(of: url) {
            panel.message = "“\(volume)” isn’t connected. Plug it in, or find “\(url.lastPathComponent)” somewhere else."
        } else {
            panel.message = "“\(url.lastPathComponent)” isn’t in \(url.deletingLastPathComponent().path) any more. Find where it went."
        }
        guard panel.runModal() == .OK, let found = panel.url else { return }
        forget(url)
        open(found)
    }

    func forget(_ url: URL) {
        recents.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
        saveRecents()
    }

    /// Follows bookmarks for shoots that have moved, merges any that turn out to be a shoot already in the list,
    /// and rechecks which are reachable.
    func refreshRecents() {
        var changed = false
        for (index, url) in recents.enumerated() where ShootLocation.status(of: url) != .available {
            guard let bookmark = bookmarks[url.path], let moved = ShootLocation.resolve(bookmark) else { continue }
            recents[index] = moved
            bookmarks[moved.path] = bookmark
            changed = true
        }
        if changed {
            var seen = Set<String>()
            recents = recents.filter { seen.insert($0.standardizedFileURL.path).inserted }
            saveRecents()
        }
        recheckRecents()
    }

    private func remember(_ url: URL) {
        recents.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
        recents.insert(url, at: 0)
        recents = Array(recents.prefix(12))
        if let bookmark = ShootLocation.bookmark(for: url) { bookmarks[url.path] = bookmark }
        saveRecents()
    }

    private func saveRecents() {
        let paths = recents.map(\.path)
        bookmarks = bookmarks.filter { paths.contains($0.key) }
        UserDefaults.standard.set(paths, forKey: Self.recentsKey)
        UserDefaults.standard.set(bookmarks, forKey: Self.bookmarksKey)
        recheckRecents()
    }

    private func recheckRecents() {
        recentStatus = Dictionary(recents.map { ($0, ShootLocation.status(of: $0)) }, uniquingKeysWith: { first, _ in first })
    }
}
