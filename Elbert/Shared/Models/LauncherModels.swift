//
//  LauncherModels.swift
//  Elbert
//

import Foundation
import Carbon
import AppKit

struct HotkeyShortcut: Codable, Hashable {
    let keyCode: UInt32
    let carbonModifiers: UInt32

    static let `default` = HotkeyShortcut(
        keyCode: UInt32(kVK_Space),
        carbonModifiers: UInt32(cmdKey | shiftKey)
    )

    var isValid: Bool {
        carbonModifiers != 0
    }

    var displayString: String {
        let glyphs = modifierGlyphs + keyGlyph
        return glyphs.isEmpty ? "Unassigned" : glyphs
    }

    private var modifierGlyphs: String {
        var output = ""
        if carbonModifiers & UInt32(cmdKey) != 0 { output += "⌘" }
        if carbonModifiers & UInt32(optionKey) != 0 { output += "⌥" }
        if carbonModifiers & UInt32(controlKey) != 0 { output += "⌃" }
        if carbonModifiers & UInt32(shiftKey) != 0 { output += "⇧" }
        return output
    }

    private var keyGlyph: String {
        switch Int(keyCode) {
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        default: return "Key \(keyCode)"
        }
    }

    static func from(event: NSEvent) -> HotkeyShortcut? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon: UInt32 = 0
        if modifiers.contains(.command) { carbon |= UInt32(cmdKey) }
        if modifiers.contains(.option) { carbon |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbon |= UInt32(controlKey) }
        if modifiers.contains(.shift) { carbon |= UInt32(shiftKey) }
        let shortcut = HotkeyShortcut(keyCode: UInt32(event.keyCode), carbonModifiers: carbon)
        return shortcut.isValid ? shortcut : nil
    }
}

enum LauncherAction: Hashable, Sendable {
    case openApplication(URL)
    case openURL(URL)
    case runShellCommand(String)
}

struct SearchResultItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String
    let source: String
    let score: Int
    let action: LauncherAction

    nonisolated init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        source: String,
        score: Int,
        action: LauncherAction
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.source = source
        self.score = score
        self.action = action
    }
}

struct PluginManifest: Sendable {
    let name: String
    let commands: [PluginCommand]

    nonisolated init(name: String, commands: [PluginCommand]) {
        self.name = name
        self.commands = commands
    }
}

struct PluginCommand: Hashable, Sendable {
    struct Action: Hashable, Sendable {
        let type: String
        let value: String

        nonisolated init(type: String, value: String) {
            self.type = type
            self.value = value
        }
    }

    let id: String
    let title: String
    let subtitle: String
    let action: Action

    nonisolated init(id: String, title: String, subtitle: String, action: Action) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }
}
