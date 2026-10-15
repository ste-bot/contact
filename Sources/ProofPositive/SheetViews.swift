import ProofCore
import SwiftUI

/// Sheet geometry in design units: a 1500-unit-wide page, scaled to the window. Frames per strip
/// and proportions follow the film format.
struct StripMetrics {
    static let pageWidth: CGFloat = 1500
    static let pageMargin: CGFloat = 60
    static let stripSpacing: CGFloat = 28

    let format: FilmFormat
    let unit: CGFloat

    var count: Int { format.framesPerStrip }
    var stripWidth: CGFloat { (Self.pageWidth - 2 * Self.pageMargin) * unit }
    var side: CGFloat { (format.hasSprockets ? 18 : 20) * unit }
    var gap: CGFloat {
        switch format {
        case .thirtyFive: 10 * unit
        case .square120: 14 * unit
        case .sixBySeven120: 16 * unit
        }
    }
    var frameWidth: CGFloat { (stripWidth - 2 * side - CGFloat(count - 1) * gap) / CGFloat(count) }
    var frameHeight: CGFloat { frameWidth / format.frameAspect }
    var rebate: CGFloat { (format.hasSprockets ? 34 : 22) * unit }
    var stripHeight: CGFloat { frameHeight + 2 * rebate }
    var frameSize: CGSize { CGSize(width: frameWidth, height: frameHeight) }

    func origin(slot: Int) -> CGPoint {
        CGPoint(x: side + CGFloat(slot) * (frameWidth + gap), y: rebate)
    }

    /// How far a grease-pencil circle runs past the frame. Kept inside the strip's own row vertically.
    var markOverhang: CGSize {
        CGSize(width: frameWidth * 0.05, height: min(frameHeight * 0.1, rebate + 8 * unit))
    }
}

// MARK: Rows

@MainActor
struct RollHeaderRow: View {
    let roll: Roll
    @Bindable var model: ShootModel
    let unit: CGFloat
    /// Hairlines on the proof paper.
    private let rule = Theme.ink.opacity(0.22)

    private var month: String? { roll.date?.formatted(.dateTime.month(.abbreviated).year()) }

    /// Where the roll's files live. A roll straight in the shoot folder has an empty relative path, so it
    /// names the shoot folder itself rather than showing nothing.
    private var folder: String {
        let path = roll.directory.isEmpty ? model.name : model.name + "/" + roll.directory
        // Finder shows `:` in folder names as `/`.
        return path.split(separator: "/").map { $0.replacingOccurrences(of: ":", with: "/") }.joined(separator: "  ›  ")
    }

    private var formatName: String {
        switch roll.format {
        case .thirtyFive: "35MM"
        case .square120: "120 · 6×6"
        case .sixBySeven120: "120 · 6×7"
        }
    }

    /// The body that shot most of the roll.
    private var camera: String {
        let models = roll.frames.compactMap(\.info.cameraModel)
        let counts = Dictionary(models.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max { $0.value < $1.value }?.key.uppercased() ?? "—"
    }

    var body: some View {
        catalogue
            .padding(.horizontal, StripMetrics.pageMargin * unit)
            .padding(.top, 48 * unit)
            .padding(.bottom, 24 * unit)
            .frame(width: StripMetrics.pageWidth * unit)
            .background(Theme.paper)
    }

    /// The roll as a catalogue entry: its number set huge and light, the shoot beside it, then a row of
    /// label/value columns between rules.
    private var catalogue: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                Text(roll.label)
                    .font(Theme.display(112 * unit, weight: 300))
                    .monospacedDigit()
                    .padding(.bottom, -14 * unit)
                Spacer(minLength: 24 * unit)
                VStack(alignment: .trailing, spacing: 6 * unit) {
                    Text(model.name)
                        .font(Theme.display(30 * unit, weight: 420))
                        .lineLimit(1)
                    if let month {
                        Text(month.uppercased())
                            .font(Theme.mono(12 * unit)).tracking(0.4 * unit)
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
            }
            Rectangle().fill(Theme.ink).frame(height: max(1, 1.5 * unit)).padding(.top, 18 * unit)
            HStack(alignment: .firstTextBaseline, spacing: 40 * unit) {
                column("Folder", folder.uppercased(), flexible: true)
                VStack(alignment: .leading, spacing: 5 * unit) {
                    CatalogueLabel("Location", size: 10 * unit, color: Theme.inkMuted)
                    InlineField(value: model.location, placeholder: "ADD LOCATION", unit: unit,
                                help: "Where the shoot was made; shown on every roll. Click to edit.",
                                editing: { model.isEditingText = $0 }) { model.location = $0 }
                }
                column("Format", formatName)
                column("Frames", String(format: "%02d", roll.frames.count))
                if roll.kind == .lab {
                    VStack(alignment: .leading, spacing: 5 * unit) {
                        CatalogueLabel("Stock", size: 10 * unit, color: Theme.inkMuted)
                        InlineField(value: model.stock(for: roll), placeholder: "FILM", unit: unit,
                                    help: "The film stock printed on the edge of this roll. Click to edit.",
                                    editing: { model.isEditingText = $0 }) { model.setStock($0, for: roll) }
                    }
                } else {
                    column("Camera", camera)
                }
            }
            .padding(.vertical, 12 * unit)
            Rectangle().fill(rule).frame(height: 1)
        }
        .foregroundStyle(Theme.ink)
    }

    private func column(_ label: String, _ value: String, flexible: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5 * unit) {
            CatalogueLabel(label, size: 10 * unit, color: Theme.inkMuted)
            Text(value)
                .font(Theme.mono(12 * unit)).tracking(0.3 * unit)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
    }
}

/// A value typed straight onto the sheet (the shoot's location, a lab roll's film stock): plain mono with an
/// underline until clicked. Clicking opens it with the current text selected, so typing replaces it at once.
/// Return, Tab or clicking away keeps the edit; Esc puts the old value back. The text field only exists while
/// editing, so it can never take the sheet's S/F/X keys, and the sheet gets the keyboard back when it ends.
@MainActor
struct InlineField: View {
    let value: String
    let placeholder: String
    let unit: CGFloat
    let help: String
    /// Told when editing starts and ends.
    var editing: (Bool) -> Void = { _ in }
    let commit: (String) -> Void
    @State private var text = ""
    @State private var isEditing = false
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if isEditing {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .fixedSize()
                    .frame(minWidth: 80 * unit, alignment: .leading)
                    .tint(Theme.ink)
                    .onAppear {
                        focused = true
                        // Select what's there once the field editor exists, so the first keystroke replaces it.
                        DispatchQueue.main.async { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }
                    }
                    .onSubmit { finish(keep: true) }
                    .onExitCommand { finish(keep: false) }
                    .onChange(of: focused) { _, isFocused in if !isFocused { finish(keep: true) } }
            } else {
                Text(text.isEmpty ? placeholder : text.uppercased())
                    .foregroundStyle(text.isEmpty ? Theme.inkMuted : Theme.ink)
                    .underline(true, color: Theme.inkMuted.opacity(0.5))
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture { begin() }
            }
        }
        .font(Theme.mono(12 * unit))
        .tracking(0.3 * unit)
        .onAppear { text = value }
        .onChange(of: value) { _, newValue in if !isEditing { text = newValue } }
        .help(help)
    }

    private func begin() {
        text = value
        isEditing = true
        editing(true)
    }

    private func finish(keep: Bool) {
        guard isEditing else { return }
        if keep { commit(text.trimmingCharacters(in: .whitespaces)) } else { text = value }
        isEditing = false
        editing(false)
    }
}

@MainActor
struct StripRow: View {
    let roll: Roll
    let index: Int
    let frames: [Frame]
    let model: ShootModel
    let unit: CGFloat

    var body: some View {
        let metrics = StripMetrics(format: roll.format, unit: unit)
        StripView(roll: roll, index: index, frames: frames, model: model, metrics: metrics)
            .frame(width: StripMetrics.pageWidth * unit, height: metrics.stripHeight + StripMetrics.stripSpacing * unit)
            .background(Theme.paper)
    }
}

@MainActor
struct RollFooterRow: View {
    let unit: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Theme.paper
                .frame(width: StripMetrics.pageWidth * unit, height: 40 * unit)
            Color.clear.frame(height: 40)
        }
    }
}

// MARK: Strip

@MainActor
struct StripView: View {
    let roll: Roll
    let index: Int
    let frames: [Frame]
    let model: ShootModel
    let metrics: StripMetrics

    var body: some View {
        // Strips never sit perfectly square on a real sheet.
        var rng = SeededRandom("\(roll.id)/\(index)")
        let skew = rng.range(-0.35...0.35)
        let shift = rng.range(-8...8) * metrics.unit

        ZStack(alignment: .topLeading) {
            StripChrome(roll: roll, frames: frames, stock: model.stock(for: roll), metrics: metrics)
            ForEach(Array(frames.enumerated()), id: \.element.id) { slot, frame in
                let origin = metrics.origin(slot: slot)
                FrameCell(frame: frame, size: metrics.frameSize, model: model)
                    .offset(x: origin.x, y: origin.y)
            }
            // Marks go on top of every frame, so a circle can run over its neighbour like real grease pencil.
            ForEach(Array(frames.enumerated()), id: \.element.id) { slot, frame in
                if let mark = model.mark(frame.id) {
                    let origin = metrics.origin(slot: slot), over = metrics.markOverhang
                    DrawnMark(mark: mark, seed: frame.id, lineWidth: max(2, 5 * metrics.unit), fresh: model.isFresh(frame.id))
                        .id("\(frame.id)|\(mark)")
                        .frame(width: metrics.frameWidth + 2 * over.width, height: metrics.frameHeight + 2 * over.height)
                        .offset(x: origin.x - over.width, y: origin.y - over.height)
                }
            }
        }
        .frame(width: metrics.stripWidth, height: metrics.stripHeight, alignment: .topLeading)
        .rotationEffect(.degrees(skew))
        .offset(x: shift)
    }
}

/// The film itself: black base, sprocket holes, and edge printing.
@MainActor
struct StripChrome: View {
    let roll: Roll
    let frames: [Frame]
    let stock: String
    let metrics: StripMetrics

    var body: some View {
        let m = metrics
        let edgeColor = roll.isMonochrome ? Theme.edgeMono : Theme.edgeColor
        let style = EdgeTrimStyle.of(EdgeTrim.trim(for: roll))

        Canvas { context, size in
            context.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 2 * m.unit), with: .color(Theme.film))

            if m.format.hasSprockets {
                // 35mm has eight perforations per frame.
                let pitch = (m.frameWidth + m.gap) / 8
                let hole = CGSize(width: pitch * 0.5, height: m.rebate * 0.34)
                var x = pitch * 0.3
                while x + hole.width < size.width {
                    for y in [m.rebate * 0.14, size.height - m.rebate * 0.14 - hole.height] {
                        context.fill(Path(roundedRect: CGRect(origin: CGPoint(x: x, y: y), size: hole), cornerRadius: 1.5 * m.unit),
                                     with: .color(Theme.paper))
                    }
                    x += pitch
                }
            }

            let topY = m.format.hasSprockets ? m.rebate * 0.74 : m.rebate * 0.55
            let bottomY = size.height - topY
            let u = m.unit
            let small = max(5, 9 * u), big = max(6, 11 * u), tiny = max(4.5, 7.5 * u)

            // Leica: one hairline along the top rebate.
            if style.hairline {
                context.fill(Path(CGRect(x: m.side, y: m.rebate - 3 * u, width: size.width - 2 * m.side, height: max(0.5, 0.6 * u))),
                             with: .color(edgeColor.opacity(0.55)))
            }

            for slot in 0..<m.count {
                let origin = m.origin(slot: slot)
                let frame = slot < frames.count ? frames[slot] : nil
                let parts = roll.kind == .lab
                    ? EdgeTrim.split(stock: stock)
                    : ((frame ?? frames.first)?.info.edgeParts ?? (maker: "", detail: ""))
                let line = style.edgeLine(maker: parts.maker, detail: parts.detail, size: small, color: edgeColor)
                let label = style.label(roll.label, size: small, color: edgeColor)

                // Top edge: roll label and stock, alternating along the strip.
                if m.format.hasSprockets {
                    if slot % 3 == 0 {
                        context.draw(label, at: CGPoint(x: origin.x + m.frameWidth - 6 * u, y: topY), anchor: .trailing)
                    } else if slot % 3 == 1 {
                        context.draw(line, at: CGPoint(x: origin.x + 6 * u, y: topY), anchor: .leading)
                    }
                } else {
                    context.draw(line, at: CGPoint(x: origin.x + 6 * u, y: topY), anchor: .leading)
                    context.draw(label, at: CGPoint(x: origin.x + m.frameWidth - 6 * u, y: topY), anchor: .trailing)
                }

                // Bottom edge: frame number at the frame's start, then (film) a DX barcode, then the half-frame mark.
                guard let frame else { continue }
                guard m.format.hasSprockets else {
                    context.draw(style.number(frame.number, size: big, color: edgeColor),
                                 at: CGPoint(x: origin.x + m.frameWidth / 2, y: bottomY), anchor: .center)
                    continue
                }
                let number = context.resolve(style.number(frame.number, size: big, color: edgeColor))
                let numberSize = number.measure(in: size)
                context.draw(number, at: CGPoint(x: origin.x + 6 * u, y: bottomY), anchor: .leading)

                if style.barcode {
                    drawBarcode(in: &context, from: origin.x + 6 * u + numberSize.width + 5 * u, to: origin.x + m.frameWidth * 0.62,
                                centerY: bottomY, height: m.rebate * 0.3, seed: "\(roll.id)/\(frame.id)", color: edgeColor)
                }

                guard !frame.number.hasSuffix("A") else { continue }
                let halfX = origin.x + m.frameWidth * 0.8
                switch style.halfFrame {
                case .triangle:
                    context.draw(style.half(frame.number + "A", size: tiny, color: edgeColor),
                                 at: CGPoint(x: halfX - 8 * u, y: bottomY), anchor: .leading)
                case .arrow:
                    // Kodak's half-frame: a small 17A sitting on a thin arrow.
                    context.draw(style.half(frame.number + "A", size: tiny, color: edgeColor),
                                 at: CGPoint(x: halfX, y: bottomY - 2.5 * u), anchor: .center)
                    var arrow = Path()
                    let y = bottomY + 3.5 * u, half = 13 * u, head = 2.6 * u
                    arrow.move(to: CGPoint(x: halfX - half, y: y))
                    arrow.addLine(to: CGPoint(x: halfX + half, y: y))
                    arrow.move(to: CGPoint(x: halfX + half - head, y: y - head * 0.6))
                    arrow.addLine(to: CGPoint(x: halfX + half, y: y))
                    arrow.addLine(to: CGPoint(x: halfX + half - head, y: y + head * 0.6))
                    context.stroke(arrow, with: .color(edgeColor), lineWidth: max(0.5, 0.7 * u))
                }
            }
        }
        .frame(width: m.stripWidth, height: m.stripHeight)
    }
}

/// A DX-style barcode: bars of seeded widths and heights, stable per frame.
private func drawBarcode(in context: inout GraphicsContext, from start: CGFloat, to end: CGFloat, centerY: CGFloat,
                         height: CGFloat, seed: String, color: Color) {
    guard end - start > height else { return }
    var rng = SeededRandom(seed)
    let unitWidth = height / 7
    var x = start
    while x < end {
        let width = unitWidth * CGFloat(Int(rng.range(1...2.99)))
        let tall = rng.unit() > 0.35
        let barHeight = tall ? height : height * 0.62
        let top = centerY - height / 2 + (tall ? 0 : (rng.unit() > 0.5 ? 0 : height - barHeight))
        if x + width <= end {
            context.fill(Path(CGRect(x: x, y: top, width: width, height: barHeight)), with: .color(color))
        }
        x += width + unitWidth * CGFloat(Int(rng.range(1...2.99)))
    }
}

// MARK: Frame

@MainActor
struct FrameCell: View {
    let frame: Frame
    let size: CGSize
    let model: ShootModel
    @State private var image: CGImage?

    /// Verticals lie sideways in a landscape frame, the way a portrait sits on film.
    private var isSideways: Bool { frame.info.isVertical && !model.uprightVerticals && size.width > size.height }
    private var isLetterboxed: Bool { frame.info.isVertical && model.uprightVerticals }
    /// Thumbnails are decoded for the size on screen, which grows with zoom.
    private var pixelSize: Int { ImageStore.thumbnailSize(forPoints: max(size.width, size.height) * max(1, model.zoom)) }

    var body: some View {
        ZStack {
            Color(white: 0.08)
            if let image {
                let picture = Image(decorative: image, scale: 1).resizable()
                if isSideways {
                    picture.aspectRatio(contentMode: .fill)
                        .frame(width: size.height, height: size.width)
                        .clipped()
                        .rotationEffect(.degrees(-90))
                } else {
                    picture.aspectRatio(contentMode: isLetterboxed ? .fit : .fill)
                        .frame(width: size.width, height: size.height)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .overlay {
            if model.focusedID == frame.id {
                Rectangle()
                    .strokeBorder(Theme.paper.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .padding(-4)
            }
        }
        // Hover, clicks and the loupe go through SheetPointer, which hit-tests correctly when zoomed.
        .background {
            GeometryReader { geometry in
                let rect = geometry.frame(in: .named(SheetPointer.space))
                Color.clear
                    .onAppear { model.sheetPointer.register(frame.id, rect: rect, upright: uprightPoint) }
                    .onChange(of: rect) { _, rect in model.sheetPointer.register(frame.id, rect: rect, upright: uprightPoint) }
                    .onDisappear { model.sheetPointer.unregister(frame.id) }
            }
        }
        .task(id: "\(frame.display.url.path)|\(pixelSize)") {
            if let cached = ImageStore.shared.cached(frame.display.url, maxPixel: pixelSize) {
                image = cached
                return
            }
            if image == nil { image = ImageStore.shared.bestCached(frame.display.url) }
            if let loaded = await ImageStore.shared.image(for: frame.display.url, maxPixel: pixelSize) { image = loaded }
        }
    }

    /// Maps a point in the cell to a normalised point in the upright image, undoing crop, letterbox and rotation.
    private func uprightPoint(_ location: CGPoint) -> CGPoint {
        let box = size.width / size.height
        let upright = Double(frame.info.pixelWidth) / Double(max(1, frame.info.pixelHeight))
        var u = location.x / size.width, v = location.y / size.height

        if isSideways {
            (u, v) = ContentMapping.fill(u, v, box: box, content: 1 / upright)
            return CGPoint(x: (1 - v).clamped, y: u.clamped)
        }
        (u, v) = isLetterboxed ? ContentMapping.fit(u, v, box: box, content: upright) : ContentMapping.fill(u, v, box: box, content: upright)
        return CGPoint(x: u.clamped, y: v.clamped)
    }
}

enum ContentMapping {
    /// Box-normalised → content-normalised, for content scaled to fill (and cropped by) the box.
    static func fill(_ u: CGFloat, _ v: CGFloat, box: CGFloat, content: CGFloat) -> (CGFloat, CGFloat) {
        content > box ? (0.5 + (u - 0.5) * box / content, v) : (u, 0.5 + (v - 0.5) * content / box)
    }

    /// Box-normalised → content-normalised, for content scaled to fit (letterboxed in) the box.
    static func fit(_ u: CGFloat, _ v: CGFloat, box: CGFloat, content: CGFloat) -> (CGFloat, CGFloat) {
        content > box ? (u, 0.5 + (v - 0.5) * content / box) : (0.5 + (u - 0.5) * box / content, v)
    }
}

extension CGFloat {
    var clamped: CGFloat { Swift.min(Swift.max(self, 0), 1) }
}
