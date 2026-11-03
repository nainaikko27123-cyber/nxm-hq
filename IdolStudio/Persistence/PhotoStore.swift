import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Member photos live in ~/Library/Application Support/Idol Studio/photos/,
/// next to company.json, so they back up together. Each photo is stored twice:
/// `<id>.jpg` (512×512 profile) and `<id>_thumb.jpg` (128×128 for tiny avatars).
/// Member data keeps only the file name.
enum PhotoStore {
    static let profileSide = 512
    static let thumbnailSide = 128
    static let allowedTypes: [UTType] = [.png, .jpeg, .webP]
    static let allowedExtensions: Set<String> = ["png", "jpg", "jpeg", "webp"]

    static var directory: URL? {
        CompanyStore.defaultURL?.deletingLastPathComponent().appendingPathComponent("photos", isDirectory: true)
    }

    static func url(for fileName: String, thumbnail: Bool) -> URL? {
        guard let directory else { return nil }
        return directory.appendingPathComponent(thumbnail ? thumbnailName(for: fileName) : fileName)
    }

    private static func thumbnailName(for fileName: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        return base + "_thumb.jpg"
    }

    // MARK: Reading a picked image

    /// Decodes an image file with its EXIF rotation applied, capped at 2048px so huge photos stay quick to crop.
    static func loadForCropping(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return orientedImage(from: source)
    }

    static func loadForCropping(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return orientedImage(from: source)
    }

    private static func orientedImage(from source: CGImageSource) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2048,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    // MARK: Saving

    enum PhotoError: LocalizedError {
        case noDirectory, encodeFailed
        var errorDescription: String? {
            switch self {
            case .noDirectory: "Couldn't find the app's data folder."
            case .encodeFailed: "Couldn't save the photo."
            }
        }
    }

    /// Saves an already-cropped square image as a 512px profile and 128px thumbnail. Returns the file name to store.
    static func save(croppedSquare image: CGImage) throws -> String {
        guard let directory else { throw PhotoError.noDirectory }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = UUID().uuidString + ".jpg"
        guard let profile = resized(image, side: profileSide),
              let thumb = resized(image, side: thumbnailSide) else { throw PhotoError.encodeFailed }
        try writeJPEG(profile, to: directory.appendingPathComponent(fileName))
        try writeJPEG(thumb, to: directory.appendingPathComponent(thumbnailName(for: fileName)))
        return fileName
    }

    static func delete(_ fileName: String?) {
        guard let fileName, !fileName.isEmpty else { return }
        for thumbnail in [false, true] {
            if let url = url(for: fileName, thumbnail: thumbnail) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        PhotoCache.shared.forget(fileName)
    }

    private static func resized(_ image: CGImage, side: Int) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        // Transparent PNGs get the app's near-black background instead of turning into black-on-black artifacts.
        context.setFillColor(CGColor(srgbRed: 0.05, green: 0.05, blue: 0.06, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        return context.makeImage()
    }

    private static func writeJPEG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw PhotoError.encodeFailed }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PhotoError.encodeFailed }
    }
}

/// In-memory cache of decoded photos. Files are read off the main thread the first time an avatar appears.
final class PhotoCache: @unchecked Sendable {
    static let shared = PhotoCache()
    private let cache = NSCache<NSString, NSImage>()

    private func key(_ fileName: String, _ thumbnail: Bool) -> NSString {
        "\(fileName)|\(thumbnail ? "t" : "f")" as NSString
    }

    func cached(_ fileName: String, thumbnail: Bool) -> NSImage? {
        cache.object(forKey: key(fileName, thumbnail))
    }

    func image(_ fileName: String, thumbnail: Bool) async -> NSImage? {
        if let hit = cached(fileName, thumbnail: thumbnail) { return hit }
        let urls = [PhotoStore.url(for: fileName, thumbnail: thumbnail),
                    PhotoStore.url(for: fileName, thumbnail: !thumbnail)].compactMap { $0 }
        let image = await Task.detached(priority: .userInitiated) { () -> NSImage? in
            for url in urls {
                // Decode now (in the background) so drawing on the main thread is instant.
                if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                   let cg = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) {
                    return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                }
            }
            return nil
        }.value
        if let image { cache.setObject(image, forKey: key(fileName, thumbnail)) }
        return image
    }

    func forget(_ fileName: String) {
        cache.removeObject(forKey: key(fileName, true))
        cache.removeObject(forKey: key(fileName, false))
    }
}
