import ProofCore
import SwiftUI

@MainActor
struct ShootView: View {
    @Bindable var model: ShootModel
    @FocusState private var sheetFocused: Bool
    @State private var pinchBase: CGFloat?

    var body: some View {
        GeometryReader { geometry in
            let pageWidth = max(640, (geometry.size.width - 96) * model.zoom)
            let unit = pageWidth / StripMetrics.pageWidth

            ScrollViewReader { proxy in
                ScrollView(model.zoom > 1 ? [.vertical, .horizontal] : .vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(model.rows) { row in
                            switch row {
                            case .header(let roll): RollHeaderRow(roll: roll, model: model, unit: unit)
                            case .strip(let roll, let index, let frames): StripRow(roll: roll, index: index, frames: frames, model: model, unit: unit)
                            case .footer: RollFooterRow(unit: unit)
                            }
                        }
                    }
                    .padding(.vertical, 48)
                    .frame(minWidth: geometry.size.width)
                }
                .onChange(of: model.scrollTarget) { _, id in
                    guard let id, let strip = model.stripID(containing: id) else { return }
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(strip) }
                }
            }
        }
        .background(Theme.bench)
        .overlay { emptyState }
        .overlay { FullscreenView(model: model) }
        .overlay { LoupeOverlay(model: model, loupe: model.loupe) }
        .overlay(alignment: .bottom) { banner }
        .overlay { if model.isPrinting { printingCover.transition(.opacity) } }
        .animation(.easeOut(duration: 0.25), value: model.isPrinting)
        .coordinateSpace(.named("bench"))
        .onContinuousHover(coordinateSpace: .named("bench")) { phase in
            if case .active(let location) = phase { model.loupe.cursor = location }
        }
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    let base = pinchBase ?? model.zoom
                    pinchBase = base
                    model.zoom = min(max(base * value.magnification, 0.6), 3)
                }
                .onEnded { _ in pinchBase = nil }
        )
        .focusable()
        .focusEffectDisabled()
        .focused($sheetFocused)
        // The sheet, not the first text field, owns the keyboard — otherwise S/F/X would type into the stock name.
        .defaultFocus($sheetFocused, true)
        .onKeyPress(phases: [.down, .repeat, .up]) { press in model.handle(press) }
        .task {
            // macOS hands initial focus to the first text field after layout; take it back once the window settles.
            try? await Task.sleep(for: .milliseconds(100))
            sheetFocused = true
        }
        .onChange(of: model.focusedID) { sheetFocused = true }
        // The toolbar sits on the same flat black as the bench, in its own bar above the sheet.
        .toolbarBackground(Theme.bench, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .background(WindowTitleVisibility(visible: true))
        .navigationTitle(model.name)
        .navigationSubtitle(subtitle)
        .toolbar { toolbar }
        .alert("Print Selects?", isPresented: Binding(get: { model.pendingPlan != nil }, set: { if !$0 { model.pendingPlan = nil } })) {
            Button("Print") { Task { await model.confirmPrint() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let plan = model.pendingPlan {
                Text("\(plan.summary)\n\nMoves \(plan.moves.count) files into Selects and reject, and writes star ratings to \(plan.ratings.count). Nothing is deleted, and you can undo.")
            }
        }
        .alert("Some files weren't printed", isPresented: Binding(get: { !model.failures.isEmpty }, set: { if !$0 { model.failures = [] } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.failures.prefix(8).joined(separator: "\n") + (model.failures.count > 8 ? "\n…and \(model.failures.count - 8) more" : ""))
        }
    }

    private var subtitle: String {
        let frames = model.shoot.frames.count, rolls = model.shoot.rolls.count
        return "\(frames) frame\(frames == 1 ? "" : "s") · \(rolls) roll\(rolls == 1 ? "" : "s")"
    }

    /// The two ways the bench can be empty, each with the way out.
    @ViewBuilder
    private var emptyState: some View {
        if model.shoot.frames.isEmpty {
            EmptyBench(title: "No photos in this folder",
                       message: "Contact reads DNG, JPEG and TIFF files here and in subfolders, skipping Web and Export folders.",
                       actionTitle: "Open Another Shoot…") { AppModel.shared.presentOpenPanel() }
        } else if model.reprint && model.visibleRolls.isEmpty {
            EmptyBench(title: "Nothing selected yet",
                       message: "Hover a frame and press S to select it, then reprint to narrow the selects down to stars.",
                       actionTitle: "Show All Frames") { model.reprint = false }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // One way back, one level at a time: full screen → the sheet → the index.
        ToolbarItem(placement: .navigation) {
            Button { model.goBack() } label: {
                Label(model.fullscreenID == nil ? "Index" : "Contact Sheet", systemImage: "chevron.left")
            }
            .help(model.fullscreenID == nil ? "Back to the index of shoots (⇧⌘W). Marks are saved." : "Back to the contact sheet (Esc)")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Tally(counts: model.counts)
            Toggle(isOn: $model.reprint) {
                Label("Reprint Circled", systemImage: "line.3.horizontal.decrease.circle")
            }
            .help("Lay out only circled frames, for a second pass (⌘R)")
            Toggle(isOn: $model.uprightVerticals) {
                Label("Upright Verticals", systemImage: "rectangle.portrait.rotate")
            }
            .help("Stand vertical frames upright instead of sideways on the strip (⌘U)")
            Button("Print Selects") { model.preparePrint() }
                .buttonStyle(BlockButtonStyle())
                .disabled(model.shoot.frames.isEmpty || model.isPrinting)
            .help("Move selects and rejects into their folders and write ratings (⌘P)")
        }
    }

    /// A square black block at the foot of the bench: a caps label, the count as a headline, the next step.
    @ViewBuilder
    private var banner: some View {
        if let banner = model.banner {
            HStack(alignment: .center, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(banner.title)
                        .font(Theme.display(20, weight: 430))
                        .foregroundStyle(Theme.paper)
                    if let detail = banner.detail {
                        Text(detail)
                            .font(Theme.display(13, weight: 400))
                            .foregroundStyle(Theme.paper.opacity(0.65))
                    }
                }
                if banner.revealsSelects {
                    Button("Reveal Selects") { model.revealSelects() }
                        .buttonStyle(BlockButtonStyle(outline: true))
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(Theme.film)
            .overlay(Rectangle().strokeBorder(Theme.paper.opacity(0.22), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
            .padding(.bottom, 28)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// While files move the bench goes dark and says so, large. No colour: red is the pencil's.
    private var printingCover: some View {
        ZStack(alignment: .bottomLeading) {
            Theme.film.opacity(0.78)
            VStack(alignment: .leading, spacing: 6) {
                Text("Printing")
                    .font(Theme.display(120, weight: 300))
                    .foregroundStyle(Theme.paper)
                CatalogueLabel("Moving files and writing ratings", size: 12)
            }
            .padding(48)
        }
        .ignoresSafeArea()
    }
}

/// The primary action: a hard paper block with a heavy caps label, like a label stuck on the sheet.
/// Square, flat, no glow; under the cursor it inverts to an outline. Toolbar buttons ignore tint, so it draws its own.
struct BlockButtonStyle: ButtonStyle {
    var large = false
    /// Secondary actions: the same square, drawn as an outline; it fills under the cursor.
    var outline = false

    func makeBody(configuration: Configuration) -> some View {
        BlockButton(configuration: configuration, large: large, outline: outline)
    }

    private struct BlockButton: View {
        let configuration: Configuration
        let large: Bool
        let outline: Bool
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            let flipped = isEnabled && hovering && !configuration.isPressed
            // A filled block inverts to an outline under the cursor; an outline fills.
            let inverted = outline ? !flipped && !configuration.isPressed : flipped
            configuration.label
                .font(Theme.sheet(large ? 15 : 12, weight: 760))
                .textCase(.uppercase)
                .tracking(large ? 0.9 : 0.5)
                .foregroundStyle(inverted ? Theme.paper : Theme.film)
                .padding(.horizontal, large ? 22 : 12)
                .padding(.vertical, large ? 13 : 5)
                .background(Rectangle().fill(inverted ? Color.clear : Theme.paper.opacity(configuration.isPressed ? 0.8 : 1)))
                .overlay(Rectangle().strokeBorder(Theme.paper, lineWidth: large ? 2 : 1.5))
                .opacity(isEnabled ? 1 : 0.35)
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }
    }
}

/// The running count, drawn in the same grease pencil as the marks on the sheet.
@MainActor
struct Tally: View {
    let counts: (selects: Int, heroes: Int, rejects: Int)

    var body: some View {
        HStack(spacing: 14) {
            item(.select, counts.selects)
            item(.hero, counts.heroes)
            item(.reject, counts.rejects)
        }
        .padding(.horizontal, 6)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(counts.selects) selects, \(counts.heroes) heroes, \(counts.rejects) rejects")
        .help("Selects, heroes and rejects marked so far")
    }

    private func item(_ mark: Mark, _ count: Int) -> some View {
        HStack(spacing: 5) {
            MarkView(mark: mark, seed: "tally-\(mark)", lineWidth: 1.8, glyph: true)
                .frame(width: mark == .select ? 20 : 15, height: 15)
            Text("\(count)")
                .font(Theme.mono(14))
                .fixedSize()
                .monospacedDigit()
                .foregroundStyle(count == 0 ? Theme.paper.opacity(0.55) : Theme.paper)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: count)
        }
    }
}

/// An empty bench says why it's empty and offers the way out: the empty box, the reason, a square outlined block.
@MainActor
struct EmptyBench: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 36) {
            WaxBoxMark(color: Theme.wax.opacity(0.85))
                .frame(width: 92, height: 108)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(Theme.display(40, weight: 380))
                    .foregroundStyle(Theme.paper)
                Text(message)
                    .font(Theme.display(14, weight: 400))
                    .foregroundStyle(Theme.paper.opacity(0.65))
                    .frame(maxWidth: 380, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                Button(actionTitle, action: action)
                    .buttonStyle(BlockButtonStyle(outline: true))
                    .padding(.top, 22)
            }
        }
        .padding(40)
    }
}
