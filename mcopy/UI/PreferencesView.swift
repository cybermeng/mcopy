import SwiftUI
import AppKit

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("maxHistoryItems") var maxHistoryItems: Int = 100
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("pollingInterval") var pollingInterval: Double = 0.5

    private init() {}

    static var launchAgentPlist: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.mcopy.launcher</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(Bundle.main.executablePath ?? "")</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
            <key>StandardOutPath</key>
            <string>/tmp/mcopy.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/mcopy.err</string>
        </dict>
        </plist>
        """
    }

    static var launchAgentPath: String {
        let home = NSHomeDirectory()
        return "\(home)/Library/LaunchAgents/com.mcopy.launcher.plist"
    }

    static func updateLaunchAtLogin(_ enable: Bool) {
        let path = launchAgentPath

        if enable {
            do {
                let plistContent = launchAgentPlist
                try plistContent.write(toFile: path, atomically: true, encoding: .utf8)
                print("LaunchAgent installed at: \(path)")
            } catch {
                print("Failed to write LaunchAgent plist: \(error)")
            }
        } else {
            do {
                if FileManager.default.fileExists(atPath: path) {
                    try FileManager.default.removeItem(atPath: path)
                    print("LaunchAgent removed")
                }
            } catch {
                print("Failed to remove LaunchAgent plist: \(error)")
            }
        }
    }

    static func syncLaunchAtLoginState() -> Bool {
        let exists = FileManager.default.fileExists(atPath: launchAgentPath)
        return exists
    }
}

struct PreferencesView: View {
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("General") {
                Stepper(
                    "Max history items: \(settings.maxHistoryItems)",
                    value: $settings.maxHistoryItems,
                    in: 10...500,
                    step: 10
                )

                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { oldValue, newValue in
                        AppSettings.updateLaunchAtLogin(newValue)
                    }
            }

            Section("Performance") {
                Slider(
                    value: $settings.pollingInterval,
                    in: 0.2...2.0,
                    step: 0.1
                ) {
                    Text("Polling interval: \(String(format: "%.1f", settings.pollingInterval))s")
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 280)
    }
}
