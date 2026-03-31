//
//  LauncherModels.swift
//  Elbert
//

import Foundation
import AppKit

struct HotkeyShortcut: Codable, Hashable {
    let keyCode: UInt32
    let modifierFlagsRawValue: UInt64

    private static let persistedModifierMask: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    static let `default` = HotkeyShortcut(
        keyCode: UInt32(KeyboardKeyCode.space),
        modifiers: [.command, .shift]
    )

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        let normalized = modifiers
            .intersection(.deviceIndependentFlagsMask)
            .intersection(Self.persistedModifierMask)
        self.modifierFlagsRawValue = UInt64(normalized.rawValue)
    }

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: UInt(modifierFlagsRawValue))
            .intersection(Self.persistedModifierMask)
    }

    var isValid: Bool {
        !modifiers.isEmpty
    }

    var displayString: String {
        let glyphs = modifierGlyphs + keyGlyph
        return glyphs.isEmpty ? "Unassigned" : glyphs
    }

    private var modifierGlyphs: String {
        var output = ""
        if modifiers.contains(.command) { output += "⌘" }
        if modifiers.contains(.option) { output += "⌥" }
        if modifiers.contains(.control) { output += "⌃" }
        if modifiers.contains(.shift) { output += "⇧" }
        return output
    }

    private var keyGlyph: String {
        HotkeyShortcut.glyphsByKeyCode[Int(keyCode)] ?? "Key \(keyCode)"
    }

    static func from(event: NSEvent) -> HotkeyShortcut? {
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .intersection(persistedModifierMask)

        let shortcut = HotkeyShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        return shortcut.isValid ? shortcut : nil
    }

    private enum CodingKeys: String, CodingKey {
        case keyCode
        case modifierFlagsRawValue
        case carbonModifiers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let keyCode = try container.decode(UInt32.self, forKey: .keyCode)

        if let raw = try container.decodeIfPresent(UInt64.self, forKey: .modifierFlagsRawValue) {
            self.init(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: UInt(raw)))
            return
        }

        let carbonModifiers = try container.decodeIfPresent(UInt32.self, forKey: .carbonModifiers) ?? 0
        self.init(keyCode: keyCode, modifiers: Self.modifierFlagsFromCarbon(carbonModifiers))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifierFlagsRawValue, forKey: .modifierFlagsRawValue)
    }

    private static func modifierFlagsFromCarbon(_ carbon: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbon & 256 != 0 { flags.insert(.command) }
        if carbon & 2048 != 0 { flags.insert(.option) }
        if carbon & 4096 != 0 { flags.insert(.control) }
        if carbon & 512 != 0 { flags.insert(.shift) }
        return flags
    }

    private static let glyphsByKeyCode: [Int: String] = [
        KeyboardKeyCode.return: "↩",
        KeyboardKeyCode.tab: "⇥",
        KeyboardKeyCode.space: "Space",
        KeyboardKeyCode.delete: "⌫",
        KeyboardKeyCode.escape: "⎋",
        KeyboardKeyCode.a: "A",
        KeyboardKeyCode.b: "B",
        KeyboardKeyCode.c: "C",
        KeyboardKeyCode.d: "D",
        KeyboardKeyCode.e: "E",
        KeyboardKeyCode.f: "F",
        KeyboardKeyCode.g: "G",
        KeyboardKeyCode.h: "H",
        KeyboardKeyCode.i: "I",
        KeyboardKeyCode.j: "J",
        KeyboardKeyCode.k: "K",
        KeyboardKeyCode.l: "L",
        KeyboardKeyCode.m: "M",
        KeyboardKeyCode.n: "N",
        KeyboardKeyCode.o: "O",
        KeyboardKeyCode.p: "P",
        KeyboardKeyCode.q: "Q",
        KeyboardKeyCode.r: "R",
        KeyboardKeyCode.s: "S",
        KeyboardKeyCode.t: "T",
        KeyboardKeyCode.u: "U",
        KeyboardKeyCode.v: "V",
        KeyboardKeyCode.w: "W",
        KeyboardKeyCode.x: "X",
        KeyboardKeyCode.y: "Y",
        KeyboardKeyCode.z: "Z",
        KeyboardKeyCode.zero: "0",
        KeyboardKeyCode.one: "1",
        KeyboardKeyCode.two: "2",
        KeyboardKeyCode.three: "3",
        KeyboardKeyCode.four: "4",
        KeyboardKeyCode.five: "5",
        KeyboardKeyCode.six: "6",
        KeyboardKeyCode.seven: "7",
        KeyboardKeyCode.eight: "8",
        KeyboardKeyCode.nine: "9"
    ]
}

enum LauncherAction: Hashable, Sendable {
    case openApplication(URL)
    case openFile(URL)
    case revealInFinder(URL)
    case openURL(URL)
    case runShellCommand(String)
    case copyToClipboard(String)
    case pasteClipboardEntry(String)
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
