import SwiftUI
import AppKit

@MainActor
class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private let historyStore: HistoryStore
    private let historyPanel: HistoryPanel
    private var menu: NSMenu?

    init(historyStore: HistoryStore, historyPanel: HistoryPanel) {
        self.historyStore = historyStore
        self.historyPanel = historyPanel
        statusBar = NSStatusBar()
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)

        setupStatusBar()
    }

    private func setupStatusBar() {
        if let button = statusItem.button {
        button.image = NSImage(
            systemSymbolName: "clipboard.fill",
            accessibilityDescription: "mcopy"
        )
            button.action = #selector(statusBarClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusBarClicked() {
        let menu = buildMenu()
        self.menu = menu

        guard let button = statusItem.button else { return }
        let point = NSPoint(
            x: button.bounds.origin.x,
            y: button.bounds.origin.y + button.bounds.height
        )
        menu.popUp(positioning: nil, at: point, in: button)
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let showItem = NSMenuItem(
            title: "Show History",
            action: #selector(showHistory),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(NSMenuItem.separator())

        let clearItem = NSMenuItem(
            title: "Clear History",
            action: #selector(clearHistory),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit mcopy",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @MainActor @objc private func showHistory() {
        historyPanel.show()
    }

    @MainActor @objc private func showPreferences() {
        let prefsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        prefsWindow.title = "mcopy Preferences"
        prefsWindow.contentView = NSHostingView(rootView: PreferencesView())
        prefsWindow.center()
        prefsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func clearHistory() {
        Task {
            do {
                try await historyStore.clearAll()
            } catch {
                print("Failed to clear history: \(error)")
            }
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
