import Foundation
import AppKit

class ClipboardMonitor {
    private let store: HistoryStore
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general
    private var isMonitoring = false
    private var lastContentHash: String = ""

    private let sensitiveBundleIDs: Set<String> = [
        "com.agilebits.onepassword",
        "com.agilebits.onepassword-osx",
        "com.1password.1password",
        "com.bitwarden.desktop",
        "com.mozilla.firefox",
        "com.apple.keychainaccess",
    ]

    init(store: HistoryStore) {
        self.store = store
        self.lastChangeCount = pasteboard.changeCount
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        timer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
            self?.checkPasteboard()
        }

        RunLoop.current.add(timer!, forMode: .common)
    }

    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        guard !isFromSensitiveApp() else { return }

        if let item = extractClipboardItem() {
            let contentHash = item.contentType.rawValue + ":" + item.content
            guard contentHash != lastContentHash else { return }
            lastContentHash = contentHash

            Task {
                do {
                    try await store.save(item)
                } catch {
                    print("Failed to save clipboard item: \(error)")
                }
            }
        }
    }

    private func isFromSensitiveApp() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier else {
            return false
        }
        return sensitiveBundleIDs.contains { bundleID.hasPrefix($0) }
    }

    private func extractClipboardItem() -> ClipboardItem? {
        // Priority: Plain Text first (most common, cheapest)
        // Only check image if no text type is available

        // Check for plain text
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return ClipboardItem(
                content: text,
                contentType: .text,
                preview: String(text.prefix(100))
            )
        }

        // Check for RTF
        if let rtfData = pasteboard.data(forType: .rtf),
           let attributedString = try? NSAttributedString(
               data: rtfData,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ), !attributedString.string.isEmpty {
            return ClipboardItem(
                content: attributedString.string,
                contentType: .rtf,
                preview: String(attributedString.string.prefix(100))
            )
        }

        // Check for HTML
        if let htmlData = pasteboard.data(forType: .html),
           let htmlString = String(data: htmlData, encoding: .utf8), !htmlString.isEmpty {
            return ClipboardItem(
                content: htmlString,
                contentType: .html,
                preview: String(htmlString.prefix(100))
            )
        }

        // Check for images — only when no text content available
        if pasteboard.types?.contains(.tiff) == true || pasteboard.types?.contains(.png) == true {
            if let image = pasteboard.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
                return saveImageAndCreateItem(image)
            }
        }

        // Check for file URLs
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           !fileURLs.isEmpty {
            let paths = fileURLs.map { $0.path }.joined(separator: "\n")
            return ClipboardItem(
                content: paths,
                contentType: .fileURL
            )
        }

        return nil
    }

    private func saveImageAndCreateItem(_ image: NSImage) -> ClipboardItem {
        let imagePath = saveImageToDisk(image)
        return ClipboardItem(
            content: "[image data]",
            contentType: .image,
            preview: "[Image]",
            imagePath: imagePath
        )
    }

    private func saveImageToDisk(_ image: NSImage) -> String? {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let imagesFolder = appSupport
            .appendingPathComponent("mcopy", isDirectory: true)
            .appendingPathComponent("images", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: imagesFolder,
            withIntermediateDirectories: true
        )

        let filename = "\(UUID().uuidString).png"
        let imagePath = imagesFolder.appendingPathComponent(filename).path

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        do {
            try pngData.write(to: URL(fileURLWithPath: imagePath))
            var attributes = [FileAttributeKey: Any]()
            attributes[.posixPermissions] = 0o600
            try FileManager.default.setAttributes(attributes, ofItemAtPath: imagePath)
            return imagePath
        } catch {
            return nil
        }
    }
}
