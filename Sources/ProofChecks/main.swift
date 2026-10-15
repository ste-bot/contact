// Headless checks for ProofCore. Run with `swift run ProofChecks`; exits non-zero on failure.
import CoreGraphics
import Foundation
import ImageIO
import ProofCore
import UniformTypeIdentifiers

var failures = 0

// `swift run ProofChecks --scan <folder>`: read-only scan of a real shoot, printing its rolls and timing.
if let flag = CommandLine.arguments.firstIndex(of: "--scan"), flag + 1 < CommandLine.arguments.count {
    let folder = URL(fileURLWithPath: CommandLine.arguments[flag + 1])
    let clock = ContinuousClock()
    var shoot: Shoot?
    let elapsed = await clock.measure { shoot = await ShootScanner.scan(folder) }
    for roll in shoot!.rolls {
        print("\(roll.label)  \(roll.directory.isEmpty ? "(root)" : roll.directory) #\(roll.index)  \(roll.kind)  \(roll.format)  \(roll.frames.count) frames  mono=\(roll.isMonochrome)  first=\(roll.frames.first.map { "\($0.number) \($0.fileName) \($0.info.edgeText)" } ?? "")")
    }
    print("\(shoot!.frames.count) frames in \(elapsed)")
    exit(0)
}


func check(_ condition: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
    if condition() {
        print("  ✓ \(message)")
    } else {
        failures += 1
        print("  ✗ \(message)  (line \(line))")
    }
}

// MARK: Fixtures

func writeJPEG(_ url: URL, width: Int = 300, height: Int = 200, color: (CGFloat, CGFloat, CGFloat), date: String? = nil, model: String? = nil) {
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(red: color.0, green: color.1, blue: color.2, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    var props: [CFString: Any] = [:]
    if let date { props[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifDateTimeOriginal: date] }
    if let model { props[kCGImagePropertyTIFFDictionary] = [kCGImagePropertyTIFFMake: "RICOH IMAGING COMPANY, LTD.", kCGImagePropertyTIFFModel: model] }
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, props as CFDictionary)
    CGImageDestinationFinalize(destination)
}

func writeFakeRaw(_ url: URL) {
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! Data("not really a dng".utf8).write(to: url)
}

func exists(_ root: URL, _ path: String) -> Bool {
    FileManager.default.fileExists(atPath: root.appending(path: path).path)
}

func rating(_ url: URL) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/local/bin/exiftool")
    process.arguments = ["-s3", "-XMP-xmp:Rating", url.path]
    let pipe = Pipe()
    process.standardOutput = pipe
    try? process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: Lab names

print("Lab file names")
let labCases: [(String, String?)] = [
    ("000035020001", "1"),
    ("240928000032150012", "12"),
    ("R1-00012-0012", "12"),
    ("R1-00012-012A", "12A"),
    ("SC220622001151-01", "1"),
    ("SC220622BW001160-24", "24"),
    ("3854_000004", "4"),
    ("000001", "1"),
    ("r1-00012-012a", "12A"),
    ("sc220622001151-07", "7"),
    ("R0001234", nil),
    ("L1000123", nil),
    ("DSC_1234", nil),
]
for (name, expected) in labCases {
    check(LabNaming.frameNumber(in: name)?.label == expected, "\(name) → \(expected ?? "not a lab name")")
}
check(!LabNaming.isLabRoll(fileNames: ["1.dng", "2.dng"]), "folders with DNGs are never lab rolls")

// MARK: Scan

print("Scanning")
let root = FileManager.default.temporaryDirectory.appending(path: "ProofChecks-\(UUID().uuidString)/Cancun - Mar 2024: test ")
let red: (CGFloat, CGFloat, CGFloat) = (0.8, 0.2, 0.1), gray: (CGFloat, CGFloat, CGFloat) = (0.5, 0.5, 0.5)
writeFakeRaw(root.appending(path: "Ricoh/R0000001.DNG"))
writeJPEG(root.appending(path: "Ricoh/JPEG/R0000001.JPG"), color: red, date: "2024:03:02 10:00:00", model: "RICOH GR IV")
writeFakeRaw(root.appending(path: "Ricoh/R0000002.DNG"))
writeJPEG(root.appending(path: "Ricoh/R0000002.JPG"), color: red, date: "2024:03:02 09:00:00", model: "RICOH GR IV")
writeJPEG(root.appending(path: "Ricoh/R0000003.JPG"), width: 200, height: 300, color: red, date: "2024:03:02 11:00:00", model: "RICOH GR IV")
for i in 1...3 { writeJPEG(root.appending(path: "00003502/00003502000\(i).jpg"), width: 300, height: 300, color: gray) }
writeJPEG(root.appending(path: "Web/skip.jpg"), color: red)
for i in 1...2 {
    writeJPEG(root.appending(path: "14827_009758/Export JPG 16Base/R1-09758-000\(i).JPG"), color: red)
    writeJPEG(root.appending(path: "14827_009758/Export JPG NoResize/R1-09758-000\(i).JPG"), color: red)
}
writeJPEG(root.appending(path: "14827_009758/Export JPG 16Base/Web/R1-09758-0001.JPG"), color: red)
writeJPEG(root.appending(path: "Ricoh/._R0000003.JPG"), color: red)

var shoot = await ShootScanner.scan(root)
check(shoot.rolls.count == 3, "three rolls (got \(shoot.rolls.count))")
let delivered = shoot.rolls.first { $0.directory == "14827_009758/Export JPG 16Base" }
check(delivered?.kind == .lab && delivered?.frames.count == 2, "lab delivery folders are scans; NoResize duplicates and Web skipped")
let lab = shoot.rolls.first { $0.directory == "00003502" }
let ricoh = shoot.rolls.first { $0.directory == "Ricoh" }
check(lab?.kind == .lab && lab?.frames.map(\.number) == ["1", "2", "3"], "lab roll numbered from file names")
check(lab?.format == .square120, "square scans get 120 strips")
check(lab?.isMonochrome == true, "neutral grey scans read as B&W")
check(ricoh?.kind == .digital && ricoh?.frames.count == 3, "RAW+JPEG pairs are one frame each (got \(ricoh?.frames.count ?? 0))")
check(ricoh?.frames.map(\.id) == ["Ricoh/R0000002.DNG", "Ricoh/R0000001.DNG", "Ricoh/R0000003.JPG"], "digital frames ordered by capture time, keyed by raw")
check(ricoh?.frames.first?.display.url.pathExtension == "JPG", "the camera JPEG is displayed")
check(ricoh?.frames.first?.info.edgeText == "RICOH GR IV", "edge text from EXIF, brand not doubled")
check(ricoh?.frames.last?.info.isVertical == true, "verticals detected")
check(ricoh?.isMonochrome == false, "colour roll is not B&W")
check(shoot.rolls.map(\.label) == ["R01", "R02", "R03"], "rolls numbered across the shoot")

// MARK: Edge trims

print("Edge trims")
check(EdgeTrim.trim(for: ricoh!) == .ricoh, "a Ricoh roll prints the Ricoh trim")
check(EdgeTrim.trim(for: lab!) == .film, "lab rolls print the film trim")
var leicaRoll = ricoh!
for i in leicaRoll.frames.indices { leicaRoll.frames[i].info.cameraModel = i == 0 ? "RICOH GR IV" : "LEICA M10" }
check(EdgeTrim.trim(for: leicaRoll) == .leica, "the camera most of the roll used decides")
var unknown = ricoh!
for i in unknown.frames.indices { unknown.frames[i].info.cameraModel = "FUJIFILM X100V" }
check(EdgeTrim.trim(for: unknown) == .film, "unknown cameras fall back to the film trim")
check(ImageInfo(pixelWidth: 3, pixelHeight: 2, cameraModel: "RICOH GR IV", iso: 400).edgeParts == ("RICOH", "GR IV · ISO 400"), "edge text splits into maker and detail")
check(EdgeTrim.split(stock: "hp5 plus 400") == ("HP5", "PLUS 400"), "stock names split the same way")

// MARK: Print

print("Print Selects")
var document = ShootDocument()
document.marks = ["Ricoh/R0000001.DNG": .hero, "Ricoh/R0000002.DNG": .reject, "00003502/000035020002.jpg": .select]
let plan = Printer.plan(frames: shoot.frames, target: document.marks, printed: document.printed, root: shoot.root)
check(plan.moves.count == 5, "5 files move (got \(plan.moves.count))")
check(plan.summary == "1 select · 1 hero · 1 reject", "summary counts")
let result = await Printer.execute(plan, root: shoot.root)
document.previousPrinted = document.printed
document.printed = document.marks
try document.save(to: shoot.root)

check(exists(root, "Selects/Ricoh/JPEG/R0000001.JPG") && exists(root, "Selects/Ricoh/R0000001.DNG"), "hero pair moved together, subfolders mirrored")
check(exists(root, "reject/Ricoh/R0000002.JPG") && exists(root, "reject/Ricoh/R0000002.DNG"), "rejects kept in reject/")
check(exists(root, "Selects/00003502/000035020002.jpg"), "lab select keeps its roll folder")
check(exists(root, "Ricoh/R0000003.JPG") && exists(root, "00003502/000035020001.jpg"), "unmarked frames stay put")
check(rating(root.appending(path: "Selects/Ricoh/JPEG/R0000001.JPG")) == "5", "hero rated 5★")
check(rating(root.appending(path: "Selects/00003502/000035020002.jpg")) == "3", "select rated 3★")
check(rating(root.appending(path: "00003502/000035020001.jpg")).isEmpty, "originals outside Selects never written")
print("    (expected failures from the fake DNGs: \(result.failures.count))")

// MARK: Reopen

print("Reopening")
shoot = await ShootScanner.scan(root)
var reopened = ShootDocument.load(from: shoot.root)
check(reopened.marks == document.marks, "marks restored from the hidden file")
check(shoot.frames.count == 8, "every frame still on the sheet (got \(shoot.frames.count))")
check(shoot.rolls.first { $0.directory == "Ricoh" }?.frames.map(\.id) == ["Ricoh/R0000002.DNG", "Ricoh/R0000001.DNG", "Ricoh/R0000003.JPG"],
      "printed frames keep their roll and position")
let before = reopened
reopened.reconcile(with: shoot.frames)
check(reopened == before, "disk and marks file agree")
check(Printer.plan(frames: shoot.frames, target: reopened.marks, printed: reopened.printed, root: shoot.root).isEmpty, "re-printing unchanged marks is a no-op")

var lost = ShootDocument()
lost.reconcile(with: shoot.frames)
check(lost.marks["00003502/000035020002.jpg"] == .select && lost.marks["Ricoh/R0000002.DNG"] == .reject, "a lost marks file is rebuilt from Selects/ and reject/")

// MARK: Undo

print("Undo Print")
let undo = Printer.plan(frames: shoot.frames, target: reopened.previousPrinted ?? [:], printed: reopened.printed, root: shoot.root)
_ = await Printer.execute(undo, root: shoot.root)
check(exists(root, "Ricoh/JPEG/R0000001.JPG") && exists(root, "Ricoh/R0000002.DNG") && exists(root, "00003502/000035020002.jpg"), "files back where they started")
check(!exists(root, "Selects") && !exists(root, "reject"), "empty Selects/ and reject/ removed")
check(rating(root.appending(path: "00003502/000035020002.jpg")).isEmpty, "rating cleared on the way out")

try? FileManager.default.removeItem(at: root.deletingLastPathComponent())
print(failures == 0 ? "\nAll checks passed." : "\n\(failures) check(s) failed.")
exit(failures == 0 ? 0 : 1)
