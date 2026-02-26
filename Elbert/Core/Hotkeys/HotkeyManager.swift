//
//  HotkeyManager.swift
//  Elbert
//

import Foundation
import Carbon

enum HotkeyRegistrationError: Error, LocalizedError {
    case invalidShortcut
    case installHandlerFailed(OSStatus)
    case registerFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidShortcut:
            return "Shortcut must include at least one modifier key."
        case .installHandlerFailed(let status):
            return "Could not install hotkey handler (OSStatus \(status))."
        case .registerFailed(let status):
            return "Could not register hotkey (OSStatus \(status)). Shortcut may already be taken."
        }
    }
}

final class HotkeyManager {
    var onHotkeyPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var currentShortcut: HotkeyShortcut?
    private let hotKeyID: EventHotKeyID

    init() {
        hotKeyID = EventHotKeyID(signature: HotkeyManager.signature, id: 1)
    }

    deinit {
        unregister()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func register(shortcut: HotkeyShortcut) throws {
        guard shortcut.isValid else {
            throw HotkeyRegistrationError.invalidShortcut
        }

        try installEventHandlerIfNeeded()
        unregisterCurrentHotkey()

        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            UInt32(shortcut.carbonModifiers),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            throw HotkeyRegistrationError.registerFailed(status)
        }

        currentShortcut = shortcut
    }

    func unregister() {
        unregisterCurrentHotkey()
        currentShortcut = nil
    }

    private func installEventHandlerIfNeeded() throws {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, eventRef, userData in
                guard let eventRef, let userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotkeyEvent(eventRef)
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard status == noErr else {
            throw HotkeyRegistrationError.installHandlerFailed(status)
        }
    }

    private func unregisterCurrentHotkey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func handleHotkeyEvent(_ eventRef: EventRef) {
        var pressedHotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &pressedHotKeyID
        )

        guard status == noErr else { return }
        guard pressedHotKeyID.signature == hotKeyID.signature && pressedHotKeyID.id == hotKeyID.id else { return }
        onHotkeyPressed?()
    }

    private static let signature: OSType = {
        let chars: [UInt8] = [69, 76, 66, 84] // "ELBT"
        return chars.reduce(0) { ($0 << 8) + OSType($1) }
    }()
}
