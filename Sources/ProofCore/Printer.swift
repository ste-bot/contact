import Foundation

/// "Print Selects": moves files to match marks and writes star ratings Lightroom reads on import.
/// Nothing is ever deleted.
public enum Printer {
    public struct Move: Sendable, Hashable {
        public var from: URL
        public var to: URL
    }

    public struct Plan: Sendable {
        public var moves: [Move] = []
        /// Ratings to write after the moves, keyed by destination; nil clears the rating.
        public var ratings: [URL: Int?] = [:]
        public var selects = 0, heroes = 0, rejects = 0

        public var isEmpty: Bool { moves.isEmpty && ratings.isEmpty }

        public var summary: String {
            func count(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }
            return "\(count(selects, "select")) · \(count(heroes, "hero").replacingOccurrences(of: "heros", with: "heroes")) · \(count(rejects, "reject"))"
        }
    }

    public struct Result: Sendable {
        public var moved: [Move] = []
        public var failures: [String] = []
        public var ratingNote: String?
    }

    public static func destination(for file: FrameFile, mark: Mark?, root: URL) -> URL {
        var url = root
        switch Bucket(for: mark) {
        case .selects: url.append(path: Bucket.selectsFolder, directoryHint: .isDirectory)
        case .reject: url.append(path: Bucket.rejectFolder, directoryHint: .isDirectory)
        case .original: break
        }
        for component in file.originalPath.split(separator: "/", omittingEmptySubsequences: true) {
            url.append(path: String(component), directoryHint: .notDirectory)
        }
        return url
    }

    /// What it takes to get from `printed` (what's on disk) to `target`.
    public static func plan(frames: [Frame], target: [String: Mark], printed: [String: Mark], root: URL) -> Plan {
        var plan = Plan()
        for frame in frames {
            let mark = target[frame.id]
            let previous = printed[frame.id]
            switch mark {
            case .select: plan.selects += 1
            case .hero: plan.heroes += 1
            case .reject: plan.rejects += 1
            case nil: break
            }
            for file in frame.files {
                let to = destination(for: file, mark: mark, root: root)
                let moving = to.standardizedFileURL != file.url.standardizedFileURL
                if moving { plan.moves.append(Move(from: file.url, to: to)) }

                if let rating = mark?.rating, mark != previous || moving {
                    plan.ratings[to] = rating
                } else if mark?.rating == nil, previous?.rating != nil {
                    plan.ratings[to] = .some(nil)
                }
            }
        }
        return plan
    }

    /// Runs off the caller's actor: moves are renames on the same volume, ratings go through exiftool.
    public static func execute(_ plan: Plan, root: URL) async -> Result {
        let fm = FileManager.default
        var result = Result()

        for move in plan.moves {
            do {
                if fm.fileExists(atPath: move.to.path) {
                    result.failures.append("\(move.to.lastPathComponent) already exists in \(move.to.deletingLastPathComponent().lastPathComponent)")
                    continue
                }
                try fm.createDirectory(at: move.to.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.moveItem(at: move.from, to: move.to)
                result.moved.append(move)
            } catch {
                result.failures.append("\(move.from.lastPathComponent): \(error.localizedDescription)")
            }
        }

        let failedDestinations = Set(plan.moves.map(\.to)).subtracting(result.moved.map(\.to))
        let ratings = plan.ratings.filter { !failedDestinations.contains($0.key) }
        if !ratings.isEmpty {
            result.ratingNote = writeRatings(ratings, failures: &result.failures)
        }

        removeEmptyFolders(in: root.appending(path: Bucket.selectsFolder))
        removeEmptyFolders(in: root.appending(path: Bucket.rejectFolder))
        return result
    }

    // MARK: Ratings

    static let exiftoolPaths = ["/opt/homebrew/bin/exiftool", "/usr/local/bin/exiftool", "/usr/bin/exiftool"]

    static var exiftool: URL? {
        exiftoolPaths.lazy.map(URL.init(fileURLWithPath:)).first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// Writes XMP Rating into the files themselves (Lightroom ignores .xmp sidecars for DNG and JPEG).
    /// `-P` keeps modification dates, so cached thumbnails stay valid.
    static func writeRatings(_ ratings: [URL: Int?], failures: inout [String]) -> String? {
        guard let exiftool else {
            return "Ratings not written — install exiftool (brew install exiftool) and print again."
        }
        let byValue = Dictionary(grouping: ratings.keys) { ratings[$0]! }
        for (value, urls) in byValue {
            let assignment = value.map { "-XMP-xmp:Rating=\($0)" } ?? "-XMP-xmp:Rating="
            let process = Process()
            process.executableURL = exiftool
            process.arguments = ["-overwrite_original", "-P", "-q", "-q", "-m", assignment] + urls.map(\.path)
            let errors = Pipe()
            process.standardError = errors
            process.standardOutput = FileHandle.nullDevice
            do {
                try process.run()
                let output = errors.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    let message = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                    failures.append("exiftool: \(message.isEmpty ? "exit \(process.terminationStatus)" : message)")
                }
            } catch {
                failures.append("exiftool: \(error.localizedDescription)")
            }
        }
        return nil
    }

    // MARK: Tidy

    /// Removes folders left empty inside Selects/ or reject/ (ignoring Finder and exFAT junk). Never touches originals.
    static func removeEmptyFolders(in folder: URL) {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey]) else { return }
        for child in children where (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            removeEmptyFolders(in: child)
        }
        let remaining = (try? fm.contentsOfDirectory(atPath: folder.path)) ?? []
        guard remaining.allSatisfy({ $0 == ".DS_Store" || $0.hasPrefix("._") }) else { return }
        for junk in remaining { try? fm.removeItem(at: folder.appending(path: junk)) }
        try? fm.removeItem(at: folder)
    }
}
