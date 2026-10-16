import AppKit
import Observation
import ProofCore
import SwiftUI

/// One row of the sheet. Rolls are flattened into rows so the lazy stack can scroll to any strip.
enum SheetRow: Identifiable {
    case header(Roll)
    case strip(Roll, index: Int, frames: [Frame])
    case footer(Roll)

    var id: String {
        switch self {
        case .header(let roll): "\(roll.id)/header"
        case .strip(let roll, let index, _): ShootModel.stripID(roll: roll, index: index)
        case .footer(let roll): "\(roll.id)/footer"
        }
    }
}

/// A transient message at the foot of the bench.
struct Banner: Equatable {
    var title: String
    var detail: String?
    /// Offer to open Selects/ in Finder — the next step after printing.
    var revealsSelects = false
}

/// Where the cursor is, for the loupe. Kept apart from the shoot so hover doesn't redraw the sheet.
@Observable
final class LoupeState {
    struct Hover: Equatable {
        var frameID: String
        /// Normalised position within the upright image.
        var point: CGPoint
        /// How long the frame's long edge is drawn inside the lens, in points. The sheet's small frames
        /// get a fixed size; full screen asks for a multiple of what's already on screen, so the loupe always magnifies.
        var magnifiedLongEdge: CGFloat = 1300
    }

    var isHeld = false
    var cursor: CGPoint = .zero
    var hover: Hover?
}

@Observable
@MainActor
final class ShootModel {
    private(set) var shoot: Shoot
    private(set) var document: ShootDocument

    var focusedID: String?
    var fullscreenID: String?
    var reprint = false { didSet { revealFocus() } }
    var uprightVerticals = false
    var zoom: CGFloat = 1
    /// A zoom asked for from the keyboard or menu; the sheet animates to it and then commits it to `zoom`.
    struct ZoomRequest: Equatable {
        var target: CGFloat
        var id = UUID()
    }
    var zoomRequest: ZoomRequest?

    func requestZoom(_ target: CGFloat) {
        zoomRequest = ZoomRequest(target: SheetZoom.clamp(target))
    }
    /// Set when focus moves by keyboard, so the sheet scrolls to follow it (clicks don't scroll).
    private(set) var scrollTarget: String?

    var pendingPlan: Printer.Plan?
    var isPrinting = false
    var banner: Banner?
    var failures: [String] = []

    let loupe = LoupeState()
    @ObservationIgnored let sheetPointer = SheetPointer()

    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var bannerTask: Task<Void, Never>?

    /// What's on disk, so browsing a shoot never writes into it.
    @ObservationIgnored private var savedDocument: ShootDocument

    init(shoot: Shoot, document: ShootDocument, savedDocument: ShootDocument) {
        self.shoot = shoot
        self.document = document
        self.savedDocument = savedDocument
    }

    var name: String { shoot.name }

    // MARK: Layout

    var visibleRolls: [Roll] {
        guard reprint else { return shoot.rolls }
        return shoot.rolls.compactMap { roll in
            var roll = roll
            roll.frames = roll.frames.filter { document.marks[$0.id]?.isKeeper == true }
            return roll.frames.isEmpty ? nil : roll
        }
    }

    var rows: [SheetRow] {
        visibleRolls.flatMap { roll in
            [.header(roll)] + roll.strips.enumerated().map { .strip(roll, index: $0.offset, frames: $0.element) } + [.footer(roll)]
        }
    }

    var visibleFrames: [Frame] { visibleRolls.flatMap(\.frames) }

    func frame(_ id: String) -> Frame? {
        shoot.rolls.lazy.flatMap(\.frames).first { $0.id == id }
    }

    func roll(containing id: String) -> Roll? {
        visibleRolls.first { $0.frames.contains { $0.id == id } }
    }

    nonisolated static func stripID(roll: Roll, index: Int) -> String { "\(roll.id)/strip\(index)" }

    func stripID(containing id: String) -> String? {
        for roll in visibleRolls {
            for (index, strip) in roll.strips.enumerated() where strip.contains(where: { $0.id == id }) {
                return Self.stripID(roll: roll, index: index)
            }
        }
        return nil
    }

    // MARK: Marks

    func mark(_ id: String) -> Mark? { document.marks[id] }

    func setMark(_ mark: Mark?, for id: String) {
        guard document.marks[id] != mark else { return }
        document.marks[id] = mark
        if mark != nil { freshMark = (id, .now) }
        scheduleSave()
    }

    /// The mark just made, so only it draws on — not marks scrolled back into view.
    @ObservationIgnored private var freshMark: (id: String, at: Date)?

    func isFresh(_ id: String) -> Bool {
        guard let freshMark, freshMark.id == id else { return false }
        return Date.now.timeIntervalSince(freshMark.at) < 0.5
    }

    func toggle(_ mark: Mark, for id: String) {
        setMark(self.mark(id) == mark ? nil : mark, for: id)
    }

    var counts: (selects: Int, heroes: Int, rejects: Int) {
        let ids = Set(shoot.frames.map(\.id))
        let marks = document.marks.filter { ids.contains($0.key) }.values
        return (marks.filter { $0 == .select }.count, marks.filter { $0 == .hero }.count, marks.filter { $0 == .reject }.count)
    }

    var location: String {
        get { document.location }
        set { document.location = newValue; scheduleSave() }
    }

    func stock(for roll: Roll) -> String { document.stocks[roll.id] ?? "FILM" }

    func setStock(_ stock: String, for roll: Roll) {
        let trimmed = stock.trimmingCharacters(in: .whitespaces).uppercased()
        document.stocks[roll.id] = trimmed.isEmpty || trimmed == "FILM" ? nil : trimmed
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            self.saveNow()
        }
    }

    func saveNow() {
        guard document != savedDocument else { return }
        do {
            try document.save(to: shoot.root)
            savedDocument = document
        } catch {
            showBanner(Banner(title: "Marks not saved", detail: "\(error.localizedDescription) Your marks are still here; they'll save on the next change."))
        }
    }

    // MARK: Focus and navigation

    /// A click only puts the focus ring on a frame; marking is always a key (S, F, X) so a stray click never
    /// marks anything. ⌘-click or a double-click opens the frame full screen.
    func click(_ id: String) {
        focusedID = id
        if NSEvent.modifierFlags.contains(.command) { openFullscreen() }
    }

    func doubleClick(_ id: String) {
        focusedID = id
        openFullscreen()
    }

    /// The cursor resting on a frame makes it the one the keys act on. Arrow keys carry on from there.
    func hoverFocus(_ id: String) {
        guard fullscreenID == nil, focusedID != id, !Self.ignoresHover else { return }
        focusedID = id
    }

    /// True while a value typed onto the sheet (location, stock) is being edited. Hover and the marking keys
    /// leave the keyboard alone until it ends, then focus goes straight back to the sheet.
    var isEditingText = false {
        didSet { if oldValue && !isEditingText { refocusSheet += 1 } }
    }
    /// Bumped when an edit ends, so the sheet takes the keyboard back without a click.
    private(set) var refocusSheet = 0

    /// The self-check's click tests turn hover-focus off, so the real pointer resting on the window can't move focus.
    private static let ignoresHover = ProcessInfo.processInfo.environment["PROOF_NOHOVER"] != nil

    /// One level up: full screen back to the sheet, the sheet back to the index.
    func goBack() {
        if fullscreenID != nil { fullscreenID = nil } else { AppModel.shared.close() }
    }

    private func focus(_ id: String?) {
        focusedID = id
        if fullscreenID != nil { fullscreenID = id }
        scrollTarget = id
        prefetchNeighbours()
    }

    private func revealFocus() {
        if let id = focusedID, !visibleFrames.contains(where: { $0.id == id }) {
            focusedID = visibleFrames.first?.id
        }
        if let fullscreenID, !visibleFrames.contains(where: { $0.id == fullscreenID }) {
            self.fullscreenID = nil
        }
    }

    func step(_ delta: Int) {
        let frames = visibleFrames
        guard !frames.isEmpty else { return }
        guard let id = focusedID, let index = frames.firstIndex(where: { $0.id == id }) else {
            return focus(frames.first?.id)
        }
        focus(frames[min(max(index + delta, 0), frames.count - 1)].id)
    }

    /// Up/down: same position on the previous/next strip, across rolls.
    func stepStrip(_ delta: Int) {
        let strips = visibleRolls.flatMap(\.strips)
        guard !strips.isEmpty else { return }
        guard let id = focusedID,
              let row = strips.firstIndex(where: { $0.contains { $0.id == id } }),
              let column = strips[row].firstIndex(where: { $0.id == id })
        else { return focus(strips.first?.first?.id) }
        let target = min(max(row + delta, 0), strips.count - 1)
        focus(strips[target][min(column, strips[target].count - 1)].id)
    }

    func openFullscreen() {
        if focusedID == nil { focusedID = visibleFrames.first?.id }
        fullscreenID = focusedID
        prefetchNeighbours()
    }

    private func prefetchNeighbours() {
        guard fullscreenID != nil, let id = focusedID else { return }
        let frames = visibleFrames
        guard let index = frames.firstIndex(where: { $0.id == id }) else { return }
        let urls = [index - 1, index + 1, index + 2].filter(frames.indices.contains).map { frames[$0].display.url }
        ImageStore.shared.prefetch(urls, maxPixel: ImageStore.detailSize)
    }

    // MARK: Keyboard

    func handle(_ press: KeyPress) -> KeyPress.Result {
        // While a value is being typed onto the sheet, every key belongs to the field: Return saves it, Esc
        // reverts it, and S/F/X are letters, not marks.
        if isEditingText || press.modifiers.contains(.command) { return .ignored }

        if press.key == .space {
            loupe.isHeld = press.phase != .up
            return .handled
        }
        guard press.phase != .up else { return .ignored }

        switch press.key {
        case .leftArrow: step(-1)
        case .rightArrow: step(1)
        case .upArrow: fullscreenID == nil ? stepStrip(-1) : step(-1)
        case .downArrow: fullscreenID == nil ? stepStrip(1) : step(1)
        case .return: fullscreenID == nil ? openFullscreen() : (fullscreenID = nil)
        case .escape:
            guard fullscreenID != nil else { return .ignored }
            fullscreenID = nil
        case .delete, .deleteForward:
            if let id = focusedID { setMark(nil, for: id) }
        default:
            guard let id = focusedID else { return .ignored }
            switch press.characters.lowercased() {
            case "s": toggle(.select, for: id)
            case "f": toggle(.hero, for: id)
            case "x": toggle(.reject, for: id)
            default: return .ignored
            }
        }
        return .handled
    }

    // MARK: Printing

    var canUndoPrint: Bool { document.previousPrinted != nil && !isPrinting }

    func preparePrint() {
        guard !isPrinting else { return }
        saveNow()
        let plan = Printer.plan(frames: shoot.frames, target: document.marks, printed: document.printed, root: shoot.root)
        if plan.isEmpty {
            showBanner(Banner(title: "Nothing to print", detail: "The folder already matches your marks."))
        } else {
            pendingPlan = plan
        }
    }

    func confirmPrint() async {
        guard let plan = pendingPlan else { return }
        pendingPlan = nil
        let target = document.marks
        let previous = document.printed
        await run(plan, target: target)
        document.previousPrinted = previous
        saveNow()
        showBanner(Banner(title: "Printed — \(plan.summary)",
                          detail: plan.selects + plan.heroes > 0 ? "Import Selects into Lightroom, heroes rated 5★." : nil,
                          revealsSelects: plan.selects + plan.heroes > 0), seconds: 10)
    }

    func undoPrint() async {
        guard let previous = document.previousPrinted, !isPrinting else { return }
        let plan = Printer.plan(frames: shoot.frames, target: previous, printed: document.printed, root: shoot.root)
        await run(plan, target: previous)
        document.previousPrinted = nil
        saveNow()
        showBanner(Banner(title: "Print undone", detail: "Files are back where they were. Your marks are unchanged."))
    }

    /// Executes a plan, then updates frame locations and `printed` for every frame whose files all moved.
    private func run(_ plan: Printer.Plan, target: [String: Mark]) async {
        isPrinting = true
        defer { isPrinting = false }
        let root = shoot.root
        let result = await Printer.execute(plan, root: root)

        let moved = Dictionary(uniqueKeysWithValues: result.moved.map { ($0.from, $0.to) })
        let failed = Set(plan.moves.map(\.from)).subtracting(moved.keys)
        for r in shoot.rolls.indices {
            for f in shoot.rolls[r].frames.indices {
                var frame = shoot.rolls[r].frames[f]
                for i in frame.files.indices {
                    if let to = moved[frame.files[i].url] { frame.files[i].url = to }
                }
                if !frame.files.contains(where: { failed.contains($0.url) }) {
                    document.printed[frame.id] = target[frame.id]
                    frame.bucket = Bucket(for: target[frame.id])
                }
                shoot.rolls[r].frames[f] = frame
            }
        }

        failures = result.failures + (result.ratingNote.map { [$0] } ?? [])
    }

    func revealSelects() {
        let selects = shoot.root.appending(path: Bucket.selectsFolder)
        NSWorkspace.shared.activateFileViewerSelecting([FileManager.default.fileExists(atPath: selects.path) ? selects : shoot.root])
    }

    func showBanner(_ banner: Banner, seconds: Double = 6) {
        withAnimation(.easeOut(duration: 0.2)) { self.banner = banner }
        bannerTask?.cancel()
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) { self?.banner = nil }
        }
    }
}
