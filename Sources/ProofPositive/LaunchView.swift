import ProofCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct RootView: View {
    @Environment(AppModel.self) private var app
    @State private var isDropTarget = false

    var body: some View {
        Group {
            if let loading = app.loading {
                DevelopingView(loading: loading)
            } else if let shoot = app.shoot {
                ShootView(model: shoot)
            } else {
                LaunchView()
            }
        }
        .background(WindowChrome())
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            app.open(url)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeOut(duration: 0.12)) { isDropTarget = targeted }
        }
        .overlay {
            if isDropTarget {
                // A hard paper frame round the whole bench: drop and it develops.
                ZStack(alignment: .bottomLeading) {
                    Rectangle().fill(Theme.film.opacity(0.72))
                    Rectangle().strokeBorder(Theme.paper, lineWidth: 2)
                    Text("Drop to develop")
                        .font(Theme.display(72, weight: 340))
                        .foregroundStyle(Theme.paper)
                    .padding(36)
                }
                .padding(14)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
    }
}

@MainActor
struct LaunchView: View {
    @Environment(AppModel.self) private var app
    /// The last recent shoot the cursor was over. Kept after the cursor leaves, so the preview doesn't flick back.
    @State private var hovered: URL?
    @State private var isOverList = false
    @State private var summaries: [URL: ShootSummary] = [:]

    private var recents: [URL] { Array(app.recents.prefix(6)) }
    private var available: [URL] { recents.filter { FileManager.default.fileExists(atPath: $0.path) } }
    /// The shoot on the right: the one last hovered, else the most recent one still on disk.
    private var previewed: URL? { hovered ?? available.first }

    var body: some View {
        GeometryReader { geometry in
            let preview = geometry.size.width >= 1040 ? previewed : nil
            HStack(spacing: 0) {
                index
                    .frame(width: preview == nil ? nil : min(max(geometry.size.width * 0.48, 640), 820))
                    .frame(maxWidth: preview == nil ? .infinity : nil, maxHeight: .infinity)
                if let preview {
                    ShootPreview(url: preview, number: (recents.firstIndex(of: preview) ?? 0) + 1, summary: summaries[preview])
                        .transition(.opacity)
                }
            }
        }
        .background(Theme.bench.ignoresSafeArea())
        // The wordmark is the title, and the index runs under a bare title bar: no toolbar band carried over
        // from the contact sheet.
        .navigationTitle("")
        .toolbarBackground(.hidden, for: .windowToolbar)
        .background(WindowTitleVisibility(visible: false))
        .task(id: available) {
            for url in available where summaries[url] == nil {
                let summary = await Task.detached(priority: .utility) { ShootScanner.summary(of: url) }.value
                summaries[url] = summary
                if let cover = summary.cover { ImageStore.shared.prefetch([cover], maxPixel: ShootPreview.pixelSize) }
            }
        }
    }

    /// The left half: a label row, the lock-up and the one action, and the shoots as a numbered index at the foot.
    private var index: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                CatalogueLabel("Index")
                Spacer()
                CatalogueLabel(recents.isEmpty ? "No shoots yet" : "\(String(format: "%02d", recents.count)) shoot\(recents.count == 1 ? "" : "s")")
            }
            .padding(.bottom, 10)
            Hairline()

            Wordmark(size: 104)
                .padding(.top, 72)

            HStack(alignment: .center, spacing: 20) {
                Button("Choose Folder") { app.presentOpenPanel() }
                    .buttonStyle(BlockButtonStyle(large: true))
                    .keyboardShortcut("o")
                Text("or drop a folder anywhere")
                    .font(Theme.display(14, weight: 400))
                    .foregroundStyle(Theme.paper.opacity(0.55))
            }
            .padding(.top, 40)

            Spacer(minLength: 56)

            if !recents.isEmpty {
                RecentShoots(urls: recents, summaries: summaries, hovered: $hovered, isOverList: $isOverList) { app.open($0) }
            }
        }
        .padding(.horizontal, 56)
        .padding(.top, 28)
        .padding(.bottom, 44)
    }
}

@MainActor
private struct RecentShoots: View {
    let urls: [URL]
    let summaries: [URL: ShootSummary]
    @Binding var hovered: URL?
    @Binding var isOverList: Bool
    let open: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                CatalogueLabel("No.").frame(width: 56, alignment: .leading)
                CatalogueLabel("Recent")
                Spacer()
                CatalogueLabel("Frames")
            }
            .padding(.bottom, 10)
            Hairline(color: Theme.paper.opacity(0.4))
            ForEach(Array(urls.enumerated()), id: \.element) { index, url in
                RecentRow(url: url, number: index + 1, frames: summaries[url]?.frames, dimmed: isOverList && hovered != url) { open(url) }
                    .onHover { if $0 { hovered = url } }
                Hairline()
            }
        }
        .onHover { isOverList = $0 }
    }
}

/// One shoot as an index entry: number, name set large and light, frame count.
@MainActor
private struct RecentRow: View {
    let url: URL
    let number: Int
    let frames: Int?
    /// Another row is under the cursor; this one steps back, like the A24 index.
    let dimmed: Bool
    let open: () -> Void

    var body: some View {
        let available = FileManager.default.fileExists(atPath: url.path)
        let strength: Double = !available ? 0.35 : dimmed ? 0.32 : 1
        Button(action: open) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                CatalogueIndex(number: number, color: Theme.paper.opacity(0.55 * strength))
                    .frame(width: 56, alignment: .leading)
                title(url.lastPathComponent, strength: strength)
                    .font(Theme.display(40, weight: 380))
                    .lineLimit(1)
                Spacer(minLength: 16)
                if available {
                    Text(frames.map { String($0) } ?? "—")
                        .font(Theme.mono(13))
                        .monospacedDigit()
                        .foregroundStyle(Theme.paper.opacity(0.7 * strength))
                } else {
                    CatalogueLabel("Drive not connected", size: 10, color: Theme.paper.opacity(0.45))
                }
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .help(url.path)
    }

    /// The A24 two-tone title: the name in full ink, " - " and whatever follows (usually the month) stepped back.
    /// The whole folder name always shows.
    private func title(_ name: String, strength: Double) -> Text {
        guard let split = name.range(of: " - ") else { return Text(name).foregroundColor(Theme.paper.opacity(strength)) }
        return Text(name[..<split.lowerBound]).foregroundColor(Theme.paper.opacity(strength))
            + Text(name[split.lowerBound...]).foregroundColor(Theme.paper.opacity(0.4 * strength))
    }
}

/// The right half of the launch screen: one frame from the shoot, edge to edge, with its checklist entry
/// in a black block flush to the corner.
@MainActor
private struct ShootPreview: View {
    static let pixelSize = 1800

    let url: URL
    let number: Int
    let summary: ShootSummary?
    @State private var loaded: (url: URL, image: CGImage)?

    var body: some View {
        let cover = summary?.cover
        let image = loaded?.url == cover ? loaded?.image : cover.flatMap { ImageStore.shared.cached($0, maxPixel: Self.pixelSize) }
        Theme.film
            .overlay {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                        .id(cover)
                        .transition(.opacity)
                }
            }
            .clipped()
            .overlay(alignment: .bottomLeading) { caption }
            .animation(.easeOut(duration: 0.2), value: cover)
            .ignoresSafeArea()
            .task(id: cover) {
                guard let cover else { return }
                if let image = await ImageStore.shared.image(for: cover, maxPixel: Self.pixelSize) { loaded = (cover, image) }
            }
            .accessibilityElement(children: .combine)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                CatalogueIndex(number: number, size: 13)
                Text(url.lastPathComponent)
                    .font(Theme.display(24, weight: 420))
                    .foregroundStyle(Theme.paper)
                    .lineLimit(1)
            }
            Hairline()
            if let summary {
                CaptionGrid(rows: rows(summary))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .frame(width: 340, alignment: .leading)
        .background(Theme.film)
    }

    private func rows(_ s: ShootSummary) -> [(label: String, value: String)] {
        var rows: [(label: String, value: String)] = []
        if !s.location.isEmpty { rows.append(("Place", s.location)) }
        rows.append(("Frames", String(s.frames)))
        rows.append(("Starred", s.heroes > 0 ? String(s.heroes) : "—"))
        rows.append(("Selects", s.selects > 0 ? String(s.selects) : "—"))
        rows.append(("Rejects", s.rejects > 0 ? String(s.rejects) : "—"))
        return rows
    }
}

/// Loading a shoot: the name, the percentage set huge, and a strip of film whose frames come up as the scan
/// reads files — real progress, not a spinner.
@MainActor
struct DevelopingView: View {
    let loading: AppModel.Loading

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                CatalogueLabel("Developing")
                Spacer()
                CatalogueLabel("Reading files")
            }
            .padding(.bottom, 10)
            Hairline()
            Spacer()
            Text(loading.name)
                .font(Theme.display(44, weight: 400))
                .foregroundStyle(Theme.paper)
                .lineLimit(1)
            Text("\(Int(loading.progress * 100))%")
                .font(Theme.display(220, weight: 300))
                .monospacedDigit()
                .foregroundStyle(Theme.paper)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: Int(loading.progress * 100))
                .padding(.top, -8)
            DevelopingStrip(progress: loading.progress)
                .frame(width: 440, height: 70)
                .animation(.easeOut(duration: 0.35), value: loading.progress)
                .padding(.top, 8)
            Spacer()
        }
        .padding(.horizontal, 56)
        .padding(.top, 28)
        .padding(.bottom, 56)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.bench.ignoresSafeArea())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Developing \(loading.name), \(Int(loading.progress * 100)) percent")
    }
}

@MainActor
struct DevelopingStrip: View, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let count = 6, side: CGFloat = 10, gap: CGFloat = 6
            let frameWidth = (size.width - 2 * side - CGFloat(count - 1) * gap) / CGFloat(count)
            let frameHeight = frameWidth / 1.5
            let rebate = (size.height - frameHeight) / 2

            context.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 2), with: .color(Theme.film))

            let pitch = (frameWidth + gap) / 8
            let hole = CGSize(width: pitch * 0.5, height: rebate * 0.42)
            var x = pitch * 0.3
            while x + hole.width < size.width {
                for y in [rebate * 0.22, size.height - rebate * 0.22 - hole.height] {
                    context.fill(Path(roundedRect: CGRect(origin: CGPoint(x: x, y: y), size: hole), cornerRadius: 1), with: .color(Theme.paper))
                }
                x += pitch
            }

            // Each frame comes up out of the black in turn, like a print in the developer tray.
            for i in 0..<count {
                let developed = min(max(progress * Double(count) - Double(i), 0), 1)
                let rect = CGRect(x: side + CGFloat(i) * (frameWidth + gap), y: rebate, width: frameWidth, height: frameHeight)
                context.fill(Path(rect), with: .color(Color(white: 0.09)))
                context.fill(Path(rect), with: .color(Theme.paper.opacity(0.62 * developed)))
            }
        }
    }
}
