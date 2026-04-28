import Foundation
import AppKit
import ApplicationServices

/// 辅助功能权限管理
final class AccessibilityPermission {
    static let shared = AccessibilityPermission()

    private init() {}

    /// 检查是否已获得辅助功能权限
    var isGranted: Bool {
        return AXIsProcessTrustedWithOptions(nil)
    }

    /// 检查并请求辅助功能权限
    /// - Returns: 是否已获得权限
    @discardableResult
    func checkAndRequest() -> Bool {
        if isGranted {
            return true
        }

        // 请求权限 - 这会打开系统设置中的辅助功能面板
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let granted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        return granted
    }

    /// 显示权限提示对话框
    /// - Parameter completion: 用户点击后的回调
    func showPermissionAlert(completion: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "mcopy 需要辅助功能权限来执行粘贴操作。请在系统设置中授予权限，然后重新启动应用。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 打开系统设置中的辅助功能面板
            openAccessibilitySettings()
        }

        completion()
    }

    /// 打开系统设置中的辅助功能面板
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// 启动时检查权限，如果没有则提示用户
    func checkOnLaunch() {
        if !isGranted {
            // 异步显示提示，不阻塞启动流程
            DispatchQueue.main.async {
                self.showPermissionAlert {
                    // 用户关闭对话框后的处理
                    print("用户已关闭权限提示")
                }
            }
        }
    }
}