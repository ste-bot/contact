import ProofCore
import SwiftUI

/// Hold Space: a circular magnifier under the cursor, always showing the frame upright.
@MainActor
struct LoupeOverlay: View {
    let model: ShootModel
    let loupe: LoupeState
    @State private var detail: (url: URL, image: CGImage)?

    var body: some View {
        if loupe.isHeld, let hover = loupe.hover, let frame = model.frame(hover.frameID) {
            let url = frame.display.url
            // Decode at the size the lens draws (2× for Retina), never past the file's own pixels.
            let longest = max(frame.info.pixelWidth, frame.info.pixelHeight)
            let pixels = min(max(ImageStore.detailSize, Int(hover.magnifiedLongEdge * 2)), max(longest, ImageStore.detailSize))
            LoupeLens(image: detail?.url == url ? detail?.image : ImageStore.shared.bestCached(url),
                      point: hover.point,
                      diameter: model.fullscreenID == nil ? 300 : 380,
                      magnifiedLongEdge: hover.magnifiedLongEdge)
                .position(loupe.cursor)
                .task(id: "\(url.path)|\(pixels)") {
                    if let image = await ImageStore.shared.image(for: url, maxPixel: pixels) {
                        detail = (url, image)
                    }
                }
        }
    }
}

@MainActor
struct LoupeLens: View {
    let image: CGImage?
    let point: CGPoint
    var diameter: CGFloat = 300
    /// On-screen size of the image's long edge inside the lens.
    var magnifiedLongEdge: CGFloat = 1300

    var body: some View {
        // The lens is a fixed-size base with the image hung off its top-left corner. A ZStack would
        // grow to the image's size and then be centred in the lens, throwing the point off by hundreds of points.
        Theme.film
            .frame(width: diameter, height: diameter)
            .overlay(alignment: .topLeading) {
                if let image {
                    let aspect = CGFloat(image.width) / CGFloat(max(1, image.height))
                    let size = aspect >= 1
                        ? CGSize(width: magnifiedLongEdge, height: magnifiedLongEdge / aspect)
                        : CGSize(width: magnifiedLongEdge * aspect, height: magnifiedLongEdge)
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: size.width, height: size.height)
                        .offset(x: diameter / 2 - point.x * size.width, y: diameter / 2 - point.y * size.height)
                }
            }
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.film, lineWidth: 10))
        .overlay(Circle().stroke(Theme.paper.opacity(0.3), lineWidth: 1).padding(-5))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
        .allowsHitTesting(false)
    }
}

/// Return or ⌘-click: one frame, upright, as large as the window allows, with its checklist entry in a
/// column on the left — frame number set large, label/value caption, the keys as an index. Same keys as the sheet.
@MainActor
struct FullscreenView: View {
    let model: ShootModel
    @State private var detail: (url: URL, image: CGImage)?

    var body: some View {
        if let id = model.fullscreenID, let frame = model.frame(id) {
            let url = frame.display.url
            let image = detail?.url == url ? detail?.image : ImageStore.shared.bestCached(url)

            HStack(spacing: 0) {
                caption(for: frame, id: id)
                    .frame(width: 270)
                Rectangle().fill(Theme.rule).frame(width: 1)

                GeometryReader { geometry in
                    if let image {
                        let fitted = fit(CGSize(width: image.width, height: image.height), in: geometry.size)
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .frame(width: fitted.width, height: fitted.height)
                            .overlay {
                                if let mark = model.mark(id) {
                                    DrawnMark(mark: mark, seed: id, lineWidth: 7, fresh: model.isFresh(id))
                                        .id("\(id)|\(mark)")
                                        .padding(.horizontal, -fitted.width * 0.04)
                                        .padding(.vertical, -fitted.height * 0.05)
                                }
                            }
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let p):
                                    // Three times what's on screen, so the loupe magnifies here too.
                                    model.loupe.hover = LoupeState.Hover(frameID: id,
                                                                         point: CGPoint(x: (p.x / fitted.width).clamped, y: (p.y / fitted.height).clamped),
                                                                         magnifiedLongEdge: max(fitted.width, fitted.height) * 3)
                                case .ended:
                                    model.loupe.hover = nil
                                }
                            }
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                }
                .padding(.horizontal, 56)
                .padding(.vertical, 56)
            }
            .background(Theme.film)
            .task(id: url) {
                if let loaded = await ImageStore.shared.image(for: url, maxPixel: ImageStore.detailSize) {
                    detail = (url, loaded)
                }
            }
        }
    }

    private func caption(for frame: Frame, id: String) -> some View {
        let roll = model.roll(containing: id)
        var rows: [(label: String, value: String)] = []
        if let roll { rows.append(("Roll", roll.label)) }
        rows.append(("File", frame.fileName))
        // A lab scan has no camera in its metadata, and its date is when the lab scanned it, not when it was shot.
        let isScan = roll?.kind == .lab
        if isScan, let roll {
            rows.append(("Stock", model.stock(for: roll).uppercased()))
        } else {
            rows.append(("Camera", frame.info.edgeText))
        }
        if let date = frame.info.captureDate {
            // Short enough to fit the column: 16 OCT 2026 · 11:49
            let day = date.formatted(.dateTime.day().month(.abbreviated).year())
            let time = date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute())
            rows.append((isScan ? "Scanned" : "Date", "\(day) · \(time)".uppercased()))
        }
        rows.append(("Size", "\(frame.info.pixelWidth) × \(frame.info.pixelHeight)"))

        return VStack(alignment: .leading, spacing: 0) {
            CatalogueLabel("Frame")
                .padding(.bottom, 10)
            Hairline()
            Text(frame.number)
                .font(Theme.display(96, weight: 300))
                .monospacedDigit()
                .foregroundStyle(Theme.paper)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 14)
            Hairline().padding(.top, 10)
            CaptionGrid(rows: rows, labelWidth: 52, size: 11)
                .padding(.top, 14)
            Spacer()
            Hairline()
            VStack(alignment: .leading, spacing: 7) {
                key("← →", "Step")
                key("S", "Select")
                key("F", "Star")
                key("X", "Reject")
                key("Del", "Clear")
                key("Space", "Loupe")
                key("Esc", "Contact sheet")
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 28)
    }

    private func key(_ key: String, _ action: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            CatalogueIndex(key, size: 11).frame(width: 74, alignment: .leading)
            CatalogueLabel(action, size: 10, color: Theme.paper.opacity(0.7))
        }
    }

    private func fit(_ size: CGSize, in box: CGSize) -> CGSize {
        let scale = min(box.width / max(1, size.width), box.height / max(1, size.height))
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}
