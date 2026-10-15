import Foundation

/// Everything the app remembers about a shoot, saved as a hidden file at the shoot root
/// so it travels with the folder.
public struct ShootDocument: Codable, Sendable, Equatable {
    public static let fileName = ".contact.json"
    /// Written by the app before it was renamed Contact; read if a folder has nothing newer.
    static let legacyFileName = ".proofpositive.json"

    public var version = 1
    /// Working marks, keyed by frame id.
    public var marks: [String: Mark] = [:]
    /// The marks the files on disk reflect, as of the last print.
    public var printed: [String: Mark] = [:]
    /// `printed` before the last print — what Undo Print restores.
    public var previousPrinted: [String: Mark]?
    /// Editable stock names, keyed by roll id. Missing means `FILM`.
    public var stocks: [String: String] = [:]
    public var location = ""

    public init() {}

    public static func load(from root: URL) -> ShootDocument {
        let current = root.appending(path: fileName), legacy = root.appending(path: legacyFileName)
        let url = FileManager.default.fileExists(atPath: current.path) ? current : legacy
        guard let data = try? Data(contentsOf: url),
              let document = try? JSONDecoder().decode(ShootDocument.self, from: data)
        else { return ShootDocument() }
        return document
    }

    public func save(to root: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(self).write(to: root.appending(path: Self.fileName), options: .atomic)
    }

    /// Makes `printed` agree with where files actually are, in case the marks file was lost
    /// or files were moved by hand. Working marks follow when they'd otherwise contradict the disk.
    public mutating func reconcile(with frames: [Frame]) {
        for frame in frames {
            let printedMark = printed[frame.id]
            guard Bucket(for: printedMark) != frame.bucket else { continue }
            switch frame.bucket {
            case .selects:
                printed[frame.id] = .select
                if marks[frame.id]?.isKeeper != true { marks[frame.id] = .select }
            case .reject:
                printed[frame.id] = .reject
                if marks[frame.id] == nil { marks[frame.id] = .reject }
            case .original:
                printed[frame.id] = nil
            }
        }
    }
}
