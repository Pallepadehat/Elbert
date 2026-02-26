//
//  HotkeyStore.swift
//  Elbert
//

import Foundation
import Combine

@MainActor
final class HotkeyStore: ObservableObject {
    @Published private(set) var shortcut: HotkeyShortcut

    private let defaults: UserDefaults
    private let storageKey = "launcher.hotkey.shortcut"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.shortcut = HotkeyStore.loadShortcut(from: defaults) ?? .default
    }

    func update(_ shortcut: HotkeyShortcut) {
        self.shortcut = shortcut
        save(shortcut)
    }

    private func save(_ shortcut: HotkeyShortcut) {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func loadShortcut(from defaults: UserDefaults) -> HotkeyShortcut? {
        guard let data = defaults.data(forKey: "launcher.hotkey.shortcut") else { return nil }
        return try? JSONDecoder().decode(HotkeyShortcut.self, from: data)
    }
}
