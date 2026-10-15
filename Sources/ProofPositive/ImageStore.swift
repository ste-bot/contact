import CoreGraphics
import Foundation
import ProofCore

/// In-memory images on top of the disk thumbnail cache, with in-flight requests de-duplicated.
@MainActor
final class ImageStore {
    static let shared = ImageStore()

    /// Sheet thumbnails go through the disk cache; loupe and full-screen sizes are decoded fresh.
    nonisolated static let thumbnailSizes = [480, 960]
    static let detailSize = 2560

    private final class Box {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }

    private let memory: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.totalCostLimit = 1_500_000_000
        return cache
    }()
    private var inFlight: [String: Task<CGImage?, Never>] = [:]
    private let disk = ThumbnailDiskCache()

    nonisolated static func thumbnailSize(forPoints points: CGFloat) -> Int {
        // Retina: two pixels per point.
        thumbnailSizes.first { CGFloat($0) >= points * 2 } ?? thumbnailSizes.last!
    }

    func cached(_ url: URL, maxPixel: Int) -> CGImage? {
        memory.object(forKey: key(url, maxPixel))?.image
    }

    /// The best image already in memory for `url`, at any size.
    func bestCached(_ url: URL) -> CGImage? {
        ([Self.detailSize] + Self.thumbnailSizes.reversed()).lazy.compactMap { self.cached(url, maxPixel: $0) }.first
    }

    func image(for url: URL, maxPixel: Int) async -> CGImage? {
        let key = key(url, maxPixel)
        if let hit = memory.object(forKey: key) { return hit.image }
        if let running = inFlight[key as String] { return await running.value }

        let disk = disk
        let detail = maxPixel > Self.thumbnailSizes.last!
        // ImageIO decoding is blocking work; keep it off the main actor.
        let task = Task.detached(priority: detail ? .userInitiated : .utility) {
            detail ? ImageLoader.image(for: url, maxPixel: maxPixel) : disk.image(for: url, maxPixel: maxPixel)
        }
        inFlight[key as String] = task
        let image = await task.value
        inFlight[key as String] = nil
        if let image {
            memory.setObject(Box(image), forKey: key, cost: image.bytesPerRow * image.height)
        }
        return image
    }

    /// Decoding the next and previous frames ahead of time keeps full-screen stepping instant.
    func prefetch(_ urls: [URL], maxPixel: Int) {
        for url in urls where cached(url, maxPixel: maxPixel) == nil {
            Task { _ = await image(for: url, maxPixel: maxPixel) }
        }
    }

    private func key(_ url: URL, _ maxPixel: Int) -> NSString {
        "\(maxPixel)|\(url.path)" as NSString
    }
}
