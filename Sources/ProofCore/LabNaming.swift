import Foundation

/// Recognises the file names labs give scanned frames and pulls out the real frame number.
public enum LabNaming {
    public struct FrameNumber: Comparable, Sendable {
        public var value: Int
        /// `A` for half-frame numbers like `12A`.
        public var suffix: String

        public var label: String { "\(value)\(suffix)" }

        public static func < (a: Self, b: Self) -> Bool {
            (a.value, a.suffix) < (b.value, b.suffix)
        }
    }

    // Patterns from /Volumes/Archive 1, matched against the uppercased name. Each captures the frame number and an optional A suffix.
    private static let patterns: [Regex<(Substring, Substring, Substring?)>] = [
        // Fuji Frontier: 8-digit roll + 4-digit frame — 000035020001
        /^\d{8}(\d{4})()?$/,
        // Noritsu / EZ Controller: YYMMDD + roll + frame — 240928000032150001
        /^\d{14}(\d{4})()?$/,
        // Digital Link: R1-00012-0012, R1-00012-012A
        /^R\d+-\d+-(\d+)(A)?$/,
        // Canadian Film Lab: SC220622001151-01, SC220622BW001160-12
        /^SC\d+[A-Z]*\d*-(\d+)(A)?$/,
        // NCL: 3854_000004
        /^\d+_(\d+)(A)?$/,
        // Plain counters: 000001, 01
        /^(\d{1,6})(A)?$/,
    ]

    /// The frame number in a lab file name (without extension), or nil if it isn't a lab name.
    public static func frameNumber(in baseName: String) -> FrameNumber? {
        // Uppercased first: case-insensitive regexes with optional parts misbehave in Swift 5.10.
        let name = baseName.trimmingCharacters(in: .whitespaces).uppercased()
        for pattern in patterns {
            if let match = name.wholeMatch(of: pattern), let value = Int(match.output.1) {
                return FrameNumber(value: value, suffix: match.output.2.map { String($0).uppercased() } ?? "")
            }
        }
        return nil
    }

    /// A folder is a lab roll when it has no camera raws and nearly every name is a lab name.
    public static func isLabRoll(fileNames: [String]) -> Bool {
        guard !fileNames.isEmpty else { return false }
        if fileNames.contains(where: { ($0 as NSString).pathExtension.lowercased() == "dng" }) { return false }
        let matched = fileNames.filter { frameNumber(in: ($0 as NSString).deletingPathExtension) != nil }.count
        return Double(matched) >= Double(fileNames.count) * 0.8
    }
}
