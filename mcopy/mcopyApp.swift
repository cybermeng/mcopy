import SwiftUI
import AppKit

@main
struct McopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var clipboardMonitor: ClipboardMonitor?
    var historyStore: HistoryStore?
    var hotKeyManager: HotKeyManager?
    var historyPanel: HistoryPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        AppSettings.shared.launchAtLogin = AppSettings.syncLaunchAtLoginState()

        // 检查辅助功能权限
        AccessibilityPermission.shared.checkOnLaunch()

        Task {
            await initializeComponents()
        }
    }

    private func initializeComponents() async {
        do {
            let store = try await HistoryStore()
            historyStore = store

            clipboardMonitor = ClipboardMonitor(store: store)
            hotKeyManager = HotKeyManager()

            let panel = HistoryPanel(store: store)
            historyPanel = panel

            statusBarController = StatusBarController(
                historyStore: store,
                historyPanel: panel
            )

            clipboardMonitor?.startMonitoring()

            hotKeyManager?.registerHotKey(
                keyCode: 9,
                modifierFlags: [.option],
                action: { [weak self] in
                    self?.historyPanel?.toggle()
                }
            )
        } catch {
            print("Failed to initialize: \(error)")
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stopMonitoring()
        Task {
            await historyStore?.close()
        }
    }
}
