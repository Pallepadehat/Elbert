//
//  HotkeyManager.swift
//  Elbert
//

import Foundation
import AppKit
import ApplicationServices

enum HotkeyRegistrationError: Error, LocalizedError {
    case invalidShortcut
    case accessibilityPermissionRequired
    case installTapFailed

    var errorDescription: String? {
        switch self {
        case .invalidShortcut:
            return "Shortcut must include at least one modifier key."
        case .accessibilityPermissionRequired:
            return "Enable Accessibility permission for Elbert in System Settings > Privacy & Security > Accessibility."
        case .installTapFailed:
            return "Could not install global hotkey listener. Check Accessibility/Input Monitoring permissions."
        }
    }
}

@MainActor
final class HotkeyManager {
    var onHotkeyPressed: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var currentShortcut: HotkeyShortcut?
    private var shortcutConflictCache: ShortcutConflictCache?

    private struct ShortcutConflictCache {
        let pid: pid_t
        let keyCode: UInt32
        let modifiersRawValue: UInt
        let result: Bool
        let timestamp: Date
    }

    func register(shortcut: HotkeyShortcut) throws {
        guard shortcut.isValid else {
            throw HotkeyRegistrationError.invalidShortcut
        }

        guard hasAccessibilityPermission(promptIfNeeded: true) else {
            throw HotkeyRegistrationError.accessibilityPermissionRequired
        }

        currentShortcut = shortcut
        try installEventTapIfNeeded()
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    func unregister() {
        currentShortcut = nil
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
    }

    private func installEventTapIfNeeded() throws {
        guard eventTap == nil else { return }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            return manager.handleEvent(proxy: proxy, type: type, event: event)
        }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw HotkeyRegistrationError.installTapFailed
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.eventTap = eventTap
        self.runLoopSource = source
    }

    private func teardownTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown,
              let shortcut = currentShortcut else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let pressedModifiers = modifierFlags(from: event.flags)
        let requiredModifiers = shortcut.modifiers

        guard keyCode == shortcut.keyCode,
              pressedModifiers == requiredModifiers else {
            return Unmanaged.passUnretained(event)
        }

        let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) == 1
        if !isAutorepeat && !frontmostAppOwnsShortcut(shortcut) {
            onHotkeyPressed?()
        }

        return Unmanaged.passUnretained(event)
    }

    private func modifierFlags(from eventFlags: CGEventFlags) -> NSEvent.ModifierFlags {
        var result: NSEvent.ModifierFlags = []
        if eventFlags.contains(.maskCommand) { result.insert(.command) }
        if eventFlags.contains(.maskAlternate) { result.insert(.option) }
        if eventFlags.contains(.maskControl) { result.insert(.control) }
        if eventFlags.contains(.maskShift) { result.insert(.shift) }
        return result
    }

    private func frontmostAppOwnsShortcut(_ shortcut: HotkeyShortcut) -> Bool {
        guard hasAccessibilityPermission(promptIfNeeded: false) else {
            return false
        }

        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return false
        }

        let now = Date()
        if let cache = shortcutConflictCache,
           cache.pid == app.processIdentifier,
           cache.keyCode == shortcut.keyCode,
           cache.modifiersRawValue == shortcut.modifiers.rawValue,
           now.timeIntervalSince(cache.timestamp) < 1.0 {
            return cache.result
        }

        let owns = appDefinesMenuShortcut(pid: app.processIdentifier, shortcut: shortcut)
        shortcutConflictCache = ShortcutConflictCache(
            pid: app.processIdentifier,
            keyCode: shortcut.keyCode,
            modifiersRawValue: shortcut.modifiers.rawValue,
            result: owns,
            timestamp: now
        )
        return owns
    }

    private func hasAccessibilityPermission(promptIfNeeded: Bool) -> Bool {
        if promptIfNeeded {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    private func appDefinesMenuShortcut(pid: pid_t, shortcut: HotkeyShortcut) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        guard let menuBar = copyAXElement(appElement, attribute: kAXMenuBarAttribute as CFString) else {
            return false
        }

        var queue: [AXUIElement] = [menuBar]
        var visited = 0
        let maxVisited = 2_500

        while !queue.isEmpty && visited < maxVisited {
            let element = queue.removeFirst()
            visited += 1

            if menuItem(element, matches: shortcut) {
                return true
            }

            queue.append(contentsOf: copyAXElements(element, attribute: kAXChildrenAttribute as CFString))
        }

        return false
    }

    private func menuItem(_ element: AXUIElement, matches shortcut: HotkeyShortcut) -> Bool {
        guard let role = copyAXString(element, attribute: kAXRoleAttribute as CFString),
              role == kAXMenuItemRole as String else {
            return false
        }

        guard let menuModifiers = copyAXInt(element, attribute: "AXMenuItemCmdModifiers" as CFString) else {
            return false
        }

        if !modifiersMatchShortcut(menuModifiers: menuModifiers, shortcutModifiers: shortcut.modifiers) {
            return false
        }

        if let virtualKey = copyAXInt(element, attribute: "AXMenuItemCmdVirtualKey" as CFString),
           UInt32(virtualKey) == shortcut.keyCode {
            return true
        }

        guard let keyChar = copyAXString(element, attribute: "AXMenuItemCmdChar" as CFString)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !keyChar.isEmpty,
              let shortcutChar = keyCharacter(for: shortcut.keyCode) else {
            return false
        }

        return keyChar == shortcutChar
    }

    private func modifiersMatchShortcut(menuModifiers: Int, shortcutModifiers: NSEvent.ModifierFlags) -> Bool {
        let shiftBit = 1 << 0
        let optionBit = 1 << 1
        let controlBit = 1 << 2
        let noCommandBit = 1 << 3

        let hasShift = (menuModifiers & shiftBit) != 0
        let hasOption = (menuModifiers & optionBit) != 0
        let hasControl = (menuModifiers & controlBit) != 0
        let hasCommand = (menuModifiers & noCommandBit) == 0

        return hasShift == shortcutModifiers.contains(.shift) &&
            hasOption == shortcutModifiers.contains(.option) &&
            hasControl == shortcutModifiers.contains(.control) &&
            hasCommand == shortcutModifiers.contains(.command)
    }

    private func keyCharacter(for keyCode: UInt32) -> String? {
        switch Int(keyCode) {
        case KeyboardKeyCode.a: return "a"
        case KeyboardKeyCode.b: return "b"
        case KeyboardKeyCode.c: return "c"
        case KeyboardKeyCode.d: return "d"
        case KeyboardKeyCode.e: return "e"
        case KeyboardKeyCode.f: return "f"
        case KeyboardKeyCode.g: return "g"
        case KeyboardKeyCode.h: return "h"
        case KeyboardKeyCode.i: return "i"
        case KeyboardKeyCode.j: return "j"
        case KeyboardKeyCode.k: return "k"
        case KeyboardKeyCode.l: return "l"
        case KeyboardKeyCode.m: return "m"
        case KeyboardKeyCode.n: return "n"
        case KeyboardKeyCode.o: return "o"
        case KeyboardKeyCode.p: return "p"
        case KeyboardKeyCode.q: return "q"
        case KeyboardKeyCode.r: return "r"
        case KeyboardKeyCode.s: return "s"
        case KeyboardKeyCode.t: return "t"
        case KeyboardKeyCode.u: return "u"
        case KeyboardKeyCode.v: return "v"
        case KeyboardKeyCode.w: return "w"
        case KeyboardKeyCode.x: return "x"
        case KeyboardKeyCode.y: return "y"
        case KeyboardKeyCode.z: return "z"
        case KeyboardKeyCode.zero: return "0"
        case KeyboardKeyCode.one: return "1"
        case KeyboardKeyCode.two: return "2"
        case KeyboardKeyCode.three: return "3"
        case KeyboardKeyCode.four: return "4"
        case KeyboardKeyCode.five: return "5"
        case KeyboardKeyCode.six: return "6"
        case KeyboardKeyCode.seven: return "7"
        case KeyboardKeyCode.eight: return "8"
        case KeyboardKeyCode.nine: return "9"
        case KeyboardKeyCode.space: return " "
        default: return nil
        }
    }

    private func copyAXElement(_ element: AXUIElement, attribute: CFString) -> AXUIElement? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success, let value else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func copyAXElements(_ element: AXUIElement, attribute: CFString) -> [AXUIElement] {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success, let value else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private func copyAXString(_ element: AXUIElement, attribute: CFString) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success else { return nil }
        return value as? String
    }

    private func copyAXInt(_ element: AXUIElement, attribute: CFString) -> Int? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success else { return nil }

        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }
}
