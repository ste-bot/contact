import Foundation

/// Where a remembered shoot is now. Recents are kept as a path plus a bookmark, so a folder renamed or moved on
/// the same drive is followed; a path on an unplugged drive is told apart from one that has gone.
public enum ShootLocation {
    public enum Status: Sendable, Equatable {
        case available
        /// The path is on `/Volumes/<name>` and that drive isn't mounted.
        case driveNotConnected(volume: String)
        /// The drive is there but the folder isn't: moved, renamed or deleted.
        case missing
    }

    public static func status(of url: URL) -> Status {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue { return .available }
        let parts = url.standardizedFileURL.pathComponents
        if parts.count > 2, parts[1] == "Volumes", !FileManager.default.fileExists(atPath: "/Volumes/\(parts[2])") {
            return .driveNotConnected(volume: parts[2])
        }
        return .missing
    }

    public static func bookmark(for url: URL) -> Data? {
        try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// The folder a bookmark points at now, if it still exists. Never mounts a drive or asks the user.
    public static func resolve(_ bookmark: Data) -> URL? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale),
              status(of: url) == .available
        else { return nil }
        return url
    }

    /// The deepest folder above `url` that still exists: where to start looking for a shoot that has moved.
    public static func nearestExistingAncestor(of url: URL) -> URL? {
        var candidate = url.standardizedFileURL.deletingLastPathComponent()
        while candidate.path != "/" {
            if status(of: candidate) == .available { return candidate }
            candidate = candidate.deletingLastPathComponent()
        }
        return nil
    }
}
