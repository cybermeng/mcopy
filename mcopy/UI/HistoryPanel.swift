import SwiftUI
import AppKit

@MainActor
class HistoryPanel: NSObject {
    private var panel: NSPanel?
    private let store: HistoryStore
    private var viewModel: HistoryViewModel
    private var localKeyMonitor: Any?
    private var globalClickMonitor: Any?
    private var previousApp: NSRunningApplication?

    init(store: HistoryStore) {
        self.store = store
        self.viewModel = HistoryViewModel(store: store)
        super.init()
        installEventMonitors()
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication

        if panel == nil {
            createPanel()
        }

        guard let panel = panel else { return }

        Task {
            await viewModel.loadItems()
        }

        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame

        var panelFrame = panel.frame
        panelFrame.origin.x = mouseLocation.x - panelFrame.width / 2
        panelFrame.origin.y = mouseLocation.y - panelFrame.height - 10

        panelFrame.origin.x = max(screenFrame.minX, min(panelFrame.origin.x, screenFrame.maxX - panelFrame.width))
        panelFrame.origin.y = max(screenFrame.minY, min(panelFrame.origin.y, screenFrame.maxY - panelFrame.height))

        panel.setFrame(panelFrame, display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func clearAll() {
        viewModel.items = []
        viewModel.selectedItem = nil
        Task {
            try? await store.clearAll()
        }
    }

    func toggle() {
        if let panel = panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func pasteAndHide(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        var writeSuccess = false
        switch item.contentType {
        case .image:
            if let image = item.loadImage() {
                writeSuccess = pasteboard.writeObjects([image])
            }
        case .rtf:
            if let data = item.content.data(using: .utf8) {
                pasteboard.setData(data, forType: .rtf)
                writeSuccess = true
            }
        case .html:
            if let data = item.content.data(using: .utf8) {
                pasteboard.setData(data, forType: .html)
                writeSuccess = true
            }
        case .fileURL:
            let urls = item.content.components(separatedBy: "\n").compactMap { URL(fileURLWithPath: $0) }
            if !urls.isEmpty {
                writeSuccess = pasteboard.writeObjects(urls as [NSPasteboardWriting])
            }
        case .text, .unknown:
            writeSuccess = pasteboard.setString(item.content, forType: .string)
        }

        guard writeSuccess else {
            print("Failed to write to pasteboard")
            return
        }

        let prevApp = previousApp
        hide()
        NSApp.hide(nil)

        // 使用 AX API 进行粘贴，需要辅助功能权限
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            prevApp?.activate(options: .activateIgnoringOtherApps)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // 使用 kCGHIDEventTap 确保系统级别的事件投递
                guard let source = CGEventSource(stateID: .combinedSessionState) else {
                    print("Failed to create event source")
                    return
                }

                let keyV: CGKeyCode = 0x09  // 'v' key

                guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true),
                      let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false) else {
                    print("Failed to create keyboard events")
                    return
                }

                keyDown.flags = .maskCommand
                keyUp.flags = .maskCommand

                // 先 post keyDown，再 post keyUp
                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)
            }
        }
    }

    private func installEventMonitors() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, let panel = self.panel, panel.isVisible else { return event }
            switch event.keyCode {
            case 53:
                self.hide()
                return nil
            case 36:
                if let item = self.viewModel.selectedItem {
                    self.pasteAndHide(item)
                }
                return nil
            case 51:
                if let item = self.viewModel.selectedItem {
                    self.viewModel.deleteItem(item)
                }
                return nil
            default:
                return event
            }
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let panel = self.panel else { return }
            if panel.isVisible {
                let mouseLocation = NSEvent.mouseLocation
                if !NSMouseInRect(mouseLocation, panel.frame, false) {
                    self.hide()
                }
            }
        }
    }

    private func removeEventMonitors() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    private func createPanel() {
        let contentView = HistoryView(
            viewModel: self.viewModel,
            onPaste: { [weak self] item in
                self?.pasteAndHide(item)
            },
            onDelete: { [weak self] item in
                self?.viewModel.deleteItem(item)
            },
            onClearAll: { [weak self] in
                self?.clearAll()
            },
            onClose: { [weak self] in
                self?.hide()
            }
        )

        let hostingView = NSHostingView(rootView: contentView)

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel?.contentView = hostingView
        panel?.isFloatingPanel = true
        panel?.level = .floating
        panel?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel?.backgroundColor = .clear
        panel?.isOpaque = false
        panel?.hasShadow = true
    }
}

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var selectedItem: ClipboardItem?
    @Published var searchText: String = ""
    private let store: HistoryStore

    init(store: HistoryStore) {
        self.store = store
    }

    func loadItems() async {
        do {
            let fetchedItems = try await store.getRecentItems(limit: 100)
            await MainActor.run {
                self.items = fetchedItems
            }
        } catch {
            print("Failed to load items: \(error)")
        }
    }

    var filteredItems: [ClipboardItem] {
        if searchText.isEmpty { return items }
        return items.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        if selectedItem?.id == item.id {
            selectedItem = nil
        }
        Task {
            try? await store.deleteItem(id: item.id)
        }
    }
}

struct HistoryView: View {
    @StateObject var viewModel: HistoryViewModel
    @State private var showClearConfirm = false
    let onPaste: (ClipboardItem) -> Void
    let onDelete: (ClipboardItem) -> Void
    let onClearAll: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $viewModel.searchText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.filteredItems) { item in
                        HistoryItemRow(
                            item: item,
                            isSelected: viewModel.selectedItem?.id == item.id
                        )
                        .contentShape(Rectangle())
                        .gesture(
                            TapGesture(count: 2)
                                .onEnded { onPaste(item) }
                        )
                        .onTapGesture(count: 1) {
                            viewModel.selectedItem = item
                        }
                        .contextMenu {
                            Button("Paste") {
                                onPaste(item)
                            }
                            Button("Delete", role: .destructive) {
                                onDelete(item)
                            }
                        }
                        .id(item.id)
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            Divider()
        HStack {
            Text("\(viewModel.filteredItems.count) items")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button(action: {
                showClearConfirm = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Clear")
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
            .disabled(viewModel.items.isEmpty)
            .alert("Clear History", isPresented: $showClearConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    onClearAll()
                }
            } message: {
                Text("Delete all clipboard history? This cannot be undone.")
            }
            Button(action: {
                if let item = viewModel.selectedItem {
                    onPaste(item)
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.clipboard")
                    Text("Paste")
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(viewModel.selectedItem != nil ? .accentColor : .secondary)
            .disabled(viewModel.selectedItem == nil)
            Text("Enter paste · Del remove · Esc close")
                .font(.caption)
                .foregroundColor(.secondary)
        }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 500, height: 400)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(radius: 8)
        )
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search...", text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

struct HistoryItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            if item.contentType == .image, let nsImage = item.loadThumbnail(maxSize: 40) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(truncatedContent)
                    .lineLimit(1)
                    .font(.system(size: 13))
                Text(item.formattedTimestamp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

        Spacer()
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
    .contentShape(Rectangle())
    }

    private var iconName: String {
        switch item.contentType {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .fileURL: return "doc"
        case .rtf, .html: return "textformat"
        case .unknown: return "questionmark"
        }
    }

    private var iconColor: Color {
        switch item.contentType {
        case .text: return .blue
        case .image: return .green
        case .fileURL: return .orange
        case .rtf, .html: return .purple
        case .unknown: return .gray
        }
    }

    private var truncatedContent: String {
        let content = item.displayTitle
        return content.count > 60 ? String(content.prefix(60)) + "..." : content
    }
}
