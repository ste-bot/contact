import Foundation

/// Walks a shoot folder and lays its images out as rolls.
public enum ShootScanner {
    public static let digitalRollLength = 36

    /// Folders that hold derivatives or editor data rather than originals.
    static func isSkipped(directoryName name: String, siblings: [String] = []) -> Bool {
        let n = name.trimmingCharacters(in: .whitespaces).lowercased()
        if isLabDelivery(n) {
            // Some rolls arrive at two resolutions; keep 16Base, drop the NoResize duplicate.
            return n.contains("noresize") && siblings.contains { isLabDelivery($0.lowercased()) && !$0.lowercased().contains("noresize") }
        }
        return n.hasPrefix("web") || n.hasPrefix("export") || n == "ig" || n.hasPrefix("ig ")
            || n == "captureone" || n.hasSuffix(".cosessiondb")
    }

    /// Labs deliver scans in folders like `Export TIFF 16Base` — those are originals, not your exports.
    static func isLabDelivery(_ lowercasedName: String) -> Bool {
        lowercasedName.wholeMatch(of: /export (tiff?|jpe?g) .+/) != nil
    }

    /// `JPEG`, `JPEGs`, `Ricoh JPEG(s)`, `Camera JPEG(s)` — camera JPEGs kept next to the raws.
    static func isJPEGFolder(_ name: String) -> Bool {
        // Lowercased first: case-insensitive regexes with optional parts misbehave in Swift 5.10.
        name.trimmingCharacters(in: .whitespaces).lowercased().wholeMatch(of: /((ricoh|camera) )?jpe?gs?/) != nil
    }

    struct Candidate {
        var url: URL
        var originalPath: String
        var bucket: Bucket

        var directory: String { (originalPath as NSString).deletingLastPathComponent }
        var baseName: String { ((originalPath as NSString).lastPathComponent as NSString).deletingPathExtension.uppercased() }
        var ext: String { url.pathExtension.lowercased() }
    }

    // MARK: Scan

    /// Finds every image under `root`, pairs RAW+JPEG, reads metadata (in parallel) and builds rolls.
    public static func scan(_ root: URL, progress: (@Sendable (Double) -> Void)? = nil) async -> Shoot {
        let root = root.resolvingSymlinksInPath()
        let candidates = findCandidates(in: root)
        let groups = pair(candidates)

        let infos = await readInfo(for: groups.map { $0[0].url }, progress: progress)
        let frames = zip(groups, infos).map { files, info in
            Frame(
                id: files.first { $0.ext == "dng" }?.originalPath ?? files[0].originalPath,
                files: files.map { FrameFile(url: $0.url, originalPath: $0.originalPath) },
                info: info,
                number: "",
                bucket: files[0].bucket
            )
        }
        return Shoot(root: root, rolls: makeRolls(from: frames))
    }

    static func findCandidates(in root: URL) -> [Candidate] {
        let rootComponents = root.pathComponents
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var found: [Candidate] = []
        for case let url as URL in enumerator {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDirectory {
                let siblings = url.lastPathComponent.lowercased().contains("noresize")
                    ? (try? FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)) ?? []
                    : []
                if isSkipped(directoryName: url.lastPathComponent, siblings: siblings) { enumerator.skipDescendants() }
                continue
            }
            guard ImageLoader.imageExtensions.contains(url.pathExtension.lowercased()) else { continue }

            // Path relative to the root, by components — robust to `:` and trailing spaces in folder names.
            var relative = Array(url.resolvingSymlinksInPath().pathComponents.dropFirst(rootComponents.count))
            var bucket = Bucket.original
            if relative.count > 1, relative[0] == Bucket.selectsFolder {
                bucket = .selects
                relative.removeFirst()
            } else if relative.count > 1, relative[0] == Bucket.rejectFolder {
                bucket = .reject
                relative.removeFirst()
            }
            found.append(Candidate(url: url, originalPath: relative.joined(separator: "/"), bucket: bucket))
        }
        return found
    }

    /// Groups candidates into frames: a DNG plus its camera JPEG becomes one frame, display file first.
    static func pair(_ candidates: [Candidate]) -> [[Candidate]] {
        struct Key: Hashable { var scope: String; var base: String }

        var raws: [Key: Candidate] = [:]
        for c in candidates where c.ext == "dng" {
            raws[Key(scope: c.directory, base: c.baseName)] = c
        }

        var groups: [[Candidate]] = []
        var pairedRaws: Set<Key> = []
        for c in candidates where c.ext == "jpg" || c.ext == "jpeg" {
            let folder = (c.directory as NSString).lastPathComponent
            let scope = isJPEGFolder(folder) ? (c.directory as NSString).deletingLastPathComponent : c.directory
            let key = Key(scope: scope, base: c.baseName)
            if let raw = raws[key], !pairedRaws.contains(key) {
                pairedRaws.insert(key)
                groups.append([c, raw])
            } else {
                groups.append([c])
            }
        }
        for (key, raw) in raws where !pairedRaws.contains(key) {
            groups.append([raw])
        }
        for c in candidates where c.ext == "tif" || c.ext == "tiff" {
            groups.append([c])
        }
        return groups
    }

    /// Reads metadata with bounded parallelism — the drive is usually USB, so more readers doesn't help.
    static func readInfo(for urls: [URL], progress: (@Sendable (Double) -> Void)?) async -> [ImageInfo] {
        var results = [ImageInfo](repeating: .unreadable, count: urls.count)
        await withTaskGroup(of: (Int, ImageInfo).self) { group in
            var next = 0
            func addNext() {
                guard next < urls.count else { return }
                let index = next, url = urls[index]
                group.addTask { (index, ImageLoader.info(for: url)) }
                next += 1
            }
            for _ in 0..<8 { addNext() }
            var done = 0
            for await (index, info) in group {
                results[index] = info
                done += 1
                if done % 16 == 0 || done == urls.count { progress?(Double(done) / Double(urls.count)) }
                addNext()
            }
        }
        return results
    }

    // MARK: Rolls

    static func makeRolls(from frames: [Frame]) -> [Roll] {
        // A RAW+JPEG frame belongs with its raw's folder.
        let byDirectory = Dictionary(grouping: frames) { frame in
            (frame.files.first { $0.url.pathExtension.lowercased() == "dng" } ?? frame.display).originalDirectory
        }
        let directories = byDirectory.keys.sorted { a, b in
            a.isEmpty != b.isEmpty ? a.isEmpty : a.localizedStandardCompare(b) == .orderedAscending
        }

        var rolls: [Roll] = []
        for directory in directories {
            let frames = byDirectory[directory]!
            let allNames = frames.flatMap { $0.files.map { $0.url.lastPathComponent } }

            if LabNaming.isLabRoll(fileNames: allNames) {
                let numbered = frames.map { frame -> (LabNaming.FrameNumber?, Frame) in
                    (LabNaming.frameNumber(in: (frame.fileName as NSString).deletingPathExtension), frame)
                }.sorted { a, b in
                    switch (a.0, b.0) {
                    case let (x?, y?) where x != y: x < y
                    case (_?, nil): true
                    case (nil, _?): false
                    default: a.1.fileName.localizedStandardCompare(b.1.fileName) == .orderedAscending
                    }
                }
                let laid = numbered.enumerated().map { offset, pair in
                    var frame = pair.1
                    frame.number = pair.0?.label ?? "\(offset + 1)"
                    return frame
                }
                rolls.append(Roll(directory: directory, index: 1, number: 0, kind: .lab, format: format(of: laid), frames: laid))
            } else {
                let sorted = frames.sorted { a, b in
                    switch (a.info.captureDate, b.info.captureDate) {
                    case let (x?, y?) where x != y: x < y
                    case (_?, nil): true
                    case (nil, _?): false
                    default: a.fileName.localizedStandardCompare(b.fileName) == .orderedAscending
                    }
                }
                for (rollIndex, start) in stride(from: 0, to: sorted.count, by: digitalRollLength).enumerated() {
                    let chunk = sorted[start..<min(start + digitalRollLength, sorted.count)]
                    let laid = chunk.enumerated().map { offset, frame in
                        var frame = frame
                        frame.number = "\(offset + 1)"
                        return frame
                    }
                    rolls.append(Roll(directory: directory, index: rollIndex + 1, number: 0, kind: .digital, format: format(of: laid), frames: laid))
                }
            }
        }
        for i in rolls.indices { rolls[i].number = i + 1 }
        return rolls
    }

    static func format(of frames: [Frame]) -> FilmFormat {
        let aspects = frames.map(\.info.aspect).sorted()
        guard !aspects.isEmpty else { return .thirtyFive }
        return FilmFormat(medianAspect: aspects[aspects.count / 2])
    }
}

/// A quick look at a shoot for the launch screen, without reading any image metadata.
public struct ShootSummary: Sendable, Equatable {
    /// The display file of the frame that stands for the shoot.
    public var cover: URL?
    public var location: String
    public var frames: Int
    public var selects: Int
    public var heroes: Int
    public var rejects: Int
}

extension ShootScanner {
    /// The starred frame stands for the shoot, then the first select. Unmarked shoots use a frame a
    /// quarter of the way in, because rolls tend to open on a fogged leader or a test shot.
    public static func summary(of root: URL) -> ShootSummary {
        let root = root.resolvingSymlinksInPath()
        let groups = pair(findCandidates(in: root)).sorted { $0[0].originalPath < $1[0].originalPath }
        let document = ShootDocument.load(from: root)
        func id(_ group: [Candidate]) -> String { group.first { $0.ext == "dng" }?.originalPath ?? group[0].originalPath }
        func first(_ mark: Mark) -> [Candidate]? { groups.first { document.marks[id($0)] == mark } }
        let cover = first(.hero) ?? first(.select) ?? (groups.isEmpty ? nil : groups[groups.count / 4])
        let marks = Array(document.marks.values)
        return ShootSummary(
            cover: cover?[0].url,
            location: document.location,
            frames: groups.count,
            selects: marks.filter { $0 == .select }.count,
            heroes: marks.filter { $0 == .hero }.count,
            rejects: marks.filter { $0 == .reject }.count
        )
    }
}
