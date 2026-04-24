import Foundation
import AppKit

enum ContentType: String, Codable, CaseIterable {
    case text = "text"
    case rtf = "rtf"
    case html = "html"
    case image = "image"
    case fileURL = "fileURL"
    case unknown = "unknown"
}

final class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 50
    }

    func image(for path: String) -> NSImage? {
        let key = path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = NSImage(contentsOfFile: path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    func thumbnail(for path: String, maxSize: CGFloat = 40) -> NSImage? {
        let key = ("thumb_\(Int(maxSize))_" + path) as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = image(for: path) else { return nil }

        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }

        let ratio = min(maxSize / originalSize.width, maxSize / originalSize.height)
        if ratio >= 1 {
            cache.setObject(image, forKey: key)
            return image
        }

        let newSize = NSSize(width: originalSize.width * ratio,
                            height: originalSize.height * ratio)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: originalSize),
                  operation: .copy,
                  fraction: 1.0)
        newImage.unlockFocus()

        cache.setObject(newImage, forKey: key)
        return newImage
    }

    func clear() {
        cache.removeAllObjects()
    }
}

struct ClipboardItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let content: String
    let timestamp: Date
    let contentType: ContentType
    let preview: String?
    let imagePath: String?

    init(
        id: UUID = UUID(),
        content: String,
        timestamp: Date = Date(),
        contentType: ContentType,
        preview: String? = nil,
        imagePath: String? = nil
    ) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.contentType = contentType
        self.preview = preview ?? String(content.prefix(100))
        self.imagePath = imagePath
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    var displayTitle: String {
        switch contentType {
        case .text:
            return preview?.replacingOccurrences(of: "\n", with: " ") ?? content
        case .image:
            return "[Image]"
        case .fileURL:
            return "[File] \(content)"
        case .rtf, .html:
            return "[Rich Text]"
        case .unknown:
            return "[Unknown]"
        }
    }

    func loadImage() -> NSImage? {
        guard contentType == .image, let path = imagePath else { return nil }
        return ImageCache.shared.image(for: path)
    }

    func loadThumbnail(maxSize: CGFloat = 40) -> NSImage? {
        guard contentType == .image, let path = imagePath else { return nil }
        return ImageCache.shared.thumbnail(for: path, maxSize: maxSize)
    }
}
