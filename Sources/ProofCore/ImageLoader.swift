import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Reads metadata and decodes thumbnails with ImageIO. Everything here is synchronous and thread-safe;
/// callers decide where it runs.
public enum ImageLoader {
    public static let imageExtensions: Set<String> = ["dng", "jpg", "jpeg", "tif", "tiff"]

    private static let exifDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return f
    }()

    // MARK: Metadata

    public static func info(for url: URL) -> ImageInfo {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return .unreadable }

        var width = props[kCGImagePropertyPixelWidth] as? Int ?? 3
        var height = props[kCGImagePropertyPixelHeight] as? Int ?? 2
        // EXIF orientations 5–8 are rotated a quarter turn.
        if let orientation = props[kCGImagePropertyOrientation] as? Int, (5...8).contains(orientation) {
            swap(&width, &height)
        }

        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String ?? tiff[kCGImagePropertyTIFFDateTime] as? String
        let iso = (exif[kCGImagePropertyExifISOSpeedRatings] as? [Int])?.first

        return ImageInfo(
            pixelWidth: width,
            pixelHeight: height,
            captureDate: dateString.flatMap { exifDate.date(from: $0) },
            cameraModel: cameraName(make: tiff[kCGImagePropertyTIFFMake] as? String, model: tiff[kCGImagePropertyTIFFModel] as? String),
            iso: iso,
            isMonochrome: probe(source).map(isMonochrome) ?? false
        )
    }

    /// `RICOH IMAGING COMPANY, LTD.` + `RICOH GR IV` → `RICOH GR IV`; `LEICA CAMERA AG` + `LEICA M10` → `LEICA M10`.
    static func cameraName(make: String?, model: String?) -> String? {
        guard let model = model?.trimmingCharacters(in: .whitespaces), !model.isEmpty else { return nil }
        guard let brand = make?.split(separator: " ").first.map(String.init), !brand.isEmpty,
              !model.uppercased().hasPrefix(brand.uppercased())
        else { return model }
        return "\(brand) \(model)"
    }

    /// A tiny image for colour analysis — the embedded EXIF thumbnail when there is one, so it's cheap.
    private static func probe(_ source: CGImageSource) -> CGImage? {
        CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceThumbnailMaxPixelSize: 96,
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary)
    }

    /// Lab B&W scans come back as RGB files, so B&W has to be judged from the pixels.
    public static func isMonochrome(_ image: CGImage) -> Bool {
        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return false }
        var chroma = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
            chroma += max(r, g, b) - min(r, g, b)
        }
        // Mean chroma under ~4% allows for a slight warm/cool cast from the scanner.
        return Double(chroma) / Double(side * side) < 10
    }

    // MARK: Thumbnails

    /// An upright image whose long edge is at most `maxPixel`.
    public static func image(for url: URL, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let isRaw = url.pathExtension.lowercased() == "dng"

        func make(always: Bool) -> CGImage? {
            CGImageSourceCreateThumbnailAtIndex(source, 0, [
                always ? kCGImageSourceCreateThumbnailFromImageAlways : kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                kCGImageSourceShouldCacheImmediately: true,
            ] as CFDictionary)
        }

        // JPEG and TIFF decode quickly at reduced size, and their embedded EXIF thumbnails are too small to use.
        guard isRaw else { return make(always: true) }
        // For raws, prefer the embedded preview; only develop the raw when the preview is too small.
        if let preview = make(always: false), max(preview.width, preview.height) >= maxPixel * 3 / 4 {
            return preview
        }
        return make(always: true)
    }
}

/// Thumbnails on disk in ~/Library/Caches, keyed by path + size + modification date, so reopening a shoot is instant.
public struct ThumbnailDiskCache: Sendable {
    public let directory: URL

    public init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "ProofPositive/thumbs", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    public func image(for url: URL, maxPixel: Int) -> CGImage? {
        guard let key = key(for: url, maxPixel: maxPixel) else { return ImageLoader.image(for: url, maxPixel: maxPixel) }
        let cached = directory.appending(path: key)
        if let source = CGImageSourceCreateWithURL(cached as CFURL, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            return image
        }
        guard let image = ImageLoader.image(for: url, maxPixel: maxPixel) else { return nil }
        if let destination = CGImageDestinationCreateWithURL(cached as CFURL, UTType.jpeg.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
            CGImageDestinationFinalize(destination)
        }
        return image
    }

    private func key(for url: URL, maxPixel: Int) -> String? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
              let size = values.fileSize, let modified = values.contentModificationDate
        else { return nil }
        let raw = "\(url.path)|\(size)|\(modified.timeIntervalSince1970)|\(maxPixel)"
        return SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined() + ".jpg"
    }
}
