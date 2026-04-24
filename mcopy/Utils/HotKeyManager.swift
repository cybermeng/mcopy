import Foundation
import AppKit
import Carbon

class HotKeyManager {
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var action: (() -> Void)?

    func registerHotKey(keyCode: Int, modifierFlags: NSEvent.ModifierFlags, action: @escaping () -> Void) {
        self.action = action

        // Register Carbon hotkey
        var gMyHotKeyID = EventHotKeyID()
        gMyHotKeyID.id = 1
        gMyHotKeyID.signature = OSType(bitPattern: 0x6D636F70) // "mcop"

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)

        // Install event handler
        let callback: EventHandlerUPP = { _, eventRef, userData -> OSStatus in
            guard let eventRef = eventRef else { return noErr }

            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if hotKeyID.id == 1 {
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData!).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.action?()
                }
            }

            return noErr
        }

        let userData = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            1,
            &eventType,
            userData,
            &eventHandler
        )

        if status != noErr {
            print("Failed to install event handler: \(status)")
            return
        }

        // Register the hotkey
        var carbonModifiers: UInt32 = 0
        if modifierFlags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if modifierFlags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifierFlags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if modifierFlags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }

        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            gMyHotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            print("Failed to register hotkey: \(registerStatus)")
        } else {
            print("Hotkey Option+V registered successfully")
        }
    }

    func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    deinit {
        unregisterHotKey()
    }
}
