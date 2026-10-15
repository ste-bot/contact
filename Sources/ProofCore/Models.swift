import Foundation

/// A grease-pencil mark. Unmarked frames are simply absent from the marks dictionary.
public enum Mark: String, Codable, Sendable {
    case select, hero, reject

    /// Both selects and heroes end up in `Selects/`.
    public var isKeeper: Bool { self == .select || self == .hero }

    /// The star rating Lightroom reads on import.
    public var rating: Int? {
        switch self {
        case .hero: 5
        case .select: 3
        case .reject: nil
        }
    }
}

/// Where a file physically sits relative to the shoot root.
public enum Bucket: String, Sendable {
    case original, selects, reject

    public static let selectsFolder = "Selects"
    public static let rejectFolder = "reject"

    public init(for mark: Mark?) {
        switch mark {
        case .select, .hero: self = .selects
        case .reject: self = .reject
        case nil: self = .original
        }
    }
}

public enum FilmFormat: Sendable, Equatable {
    case square120, sixBySeven120, thirtyFive

    public init(medianAspect: Double) {
        switch medianAspect {
        case ..<1.1: self = .square120
        case ..<1.38: self = .sixBySeven120
        default: self = .thirtyFive
        }
    }

    public var framesPerStrip: Int {
        switch self {
        case .square120: 4
        case .sixBySeven120: 3
        case .thirtyFive: 6
        }
    }

    /// Width ÷ height of a landscape frame on the strip.
    public var frameAspect: Double {
        switch self {
        case .square120: 1
        case .sixBySeven120: 1.25
        case .thirtyFive: 1.5
        }
    }

    public var hasSprockets: Bool { self == .thirtyFive }
}

/// What ImageIO tells us about a file, normalised to its upright orientation.
public struct ImageInfo: Sendable, Hashable {
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var captureDate: Date?
    public var cameraModel: String?
    public var iso: Int?
    public var isMonochrome: Bool

    public init(pixelWidth: Int, pixelHeight: Int, captureDate: Date? = nil, cameraModel: String? = nil, iso: Int? = nil, isMonochrome: Bool = false) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.captureDate = captureDate
        self.cameraModel = cameraModel
        self.iso = iso
        self.isMonochrome = isMonochrome
    }

    /// Used when a file can't be read; the frame still shows up so it can be culled.
    public static let unreadable = ImageInfo(pixelWidth: 3, pixelHeight: 2)

    public var isVertical: Bool { pixelHeight > pixelWidth }

    public var aspect: Double {
        let long = Double(max(pixelWidth, pixelHeight)), short = Double(max(1, min(pixelWidth, pixelHeight)))
        return long / short
    }

    /// `RICOH GR IV · ISO 800`
    public var edgeText: String {
        let model = (cameraModel ?? "DIGITAL").uppercased()
        guard let iso else { return model }
        return "\(model) · ISO \(iso)"
    }
}

public struct FrameFile: Sendable, Hashable {
    /// Where the file is right now.
    public var url: URL
    /// The path it would have if it had never been printed, relative to the shoot root (e.g. `Ricoh/R0001234.DNG`).
    public var originalPath: String

    public init(url: URL, originalPath: String) {
        self.url = url
        self.originalPath = originalPath
    }

    public var originalDirectory: String {
        (originalPath as NSString).deletingLastPathComponent
    }
}

public struct Frame: Identifiable, Sendable, Hashable {
    /// The anchor file's original path — stable across prints, unique within the shoot.
    public let id: String
    /// Display file first (the camera JPEG for a RAW+JPEG pair), then companions.
    public var files: [FrameFile]
    public var info: ImageInfo
    /// Edge label: `12`, or `12A` for a lab half-frame number.
    public var number: String
    public var bucket: Bucket

    public var display: FrameFile { files[0] }
    public var fileName: String { display.url.lastPathComponent }
}

public struct Roll: Identifiable, Sendable {
    public enum Kind: Sendable { case lab, digital }

    /// `<original directory>#<index>`, stable across launches; keys the editable stock name.
    public var id: String { "\(directory)#\(index)" }
    public var directory: String
    /// 1-based roll index within its directory.
    public var index: Int
    /// 1-based roll number across the shoot, printed as `R01`.
    public var number: Int
    public var kind: Kind
    public var format: FilmFormat
    public var frames: [Frame]

    public var isMonochrome: Bool { !frames.isEmpty && frames.allSatisfy(\.info.isMonochrome) }

    public var label: String { String(format: "R%02d", number) }

    public var strips: [[Frame]] {
        stride(from: 0, to: frames.count, by: format.framesPerStrip).map {
            Array(frames[$0..<min($0 + format.framesPerStrip, frames.count)])
        }
    }

    /// The month the roll was shot, from the earliest capture date.
    public var date: Date? { frames.compactMap(\.info.captureDate).min() }
}

public struct Shoot: Sendable {
    public var root: URL
    public var rolls: [Roll]

    public var name: String { root.lastPathComponent }
    public var frames: [Frame] { rolls.flatMap(\.frames) }
}
