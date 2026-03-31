//
//  ClipboardHistoryStore.swift
//  Elbert
//

import Foundation
import AppKit
import Combine

struct ClipboardHistoryEntry: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), text: String, createdAt: Date = .now) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

@MainActor
final class ClipboardHistoryStore: ObservableObject {
    @Published private(set) var entries: [ClipboardHistoryEntry]

    private let defaults: UserDefaults
    private let storageKey = "clipboard.history.entries"
    private let maxEntries: Int

    private var monitorTimer: Timer?
    private var lastChangeCount: Int

    init(defaults: UserDefaults = .standard, maxEntries: Int = 200) {
        self.defaults = defaults
        self.maxEntries = max(1, maxEntries)
        self.entries = ClipboardHistoryStore.loadEntries(from: defaults)
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func startMonitoring() {
        guard monitorTimer == nil else { return }

        lastChangeCount = NSPasteboard.general.changeCount
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.captureLatestPasteboardStringIfNeeded()
            }
        }

        if let monitorTimer {
            RunLoop.main.add(monitorTimer, forMode: .common)
        }
    }

    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    func search(_ query: String) -> [ClipboardHistoryEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }

        let lookup = normalize(trimmed)
        return entries.filter { normalize($0.text).contains(lookup) }
    }

    private func captureLatestPasteboardStringIfNeeded() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard let value = pasteboard.string(forType: .string) else { return }
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if entries.first?.text == value {
            return
        }

        entries.insert(ClipboardHistoryEntry(text: value), at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        persistEntries()
    }

    private func persistEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func loadEntries(from defaults: UserDefaults) -> [ClipboardHistoryEntry] {
        guard let data = defaults.data(forKey: "clipboard.history.entries"),
              let parsed = try? JSONDecoder().decode([ClipboardHistoryEntry].self, from: data) else {
            return []
        }

        return parsed.sorted { $0.createdAt > $1.createdAt }
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}
