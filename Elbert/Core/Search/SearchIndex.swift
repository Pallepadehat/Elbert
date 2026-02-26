//
//  SearchIndex.swift
//  Elbert
//

import Foundation

actor SearchIndex {
    private struct IndexedApp: Sendable {
        let name: String
        let url: URL
    }

    private var indexedApps: [IndexedApp] = []
    private var indexedPluginCommands: [SearchResultItem] = []

    func rebuildIndex(pluginCommands: [PluginCommand]) async {
        async let appItems = indexApplications()
        async let pluginItems = indexPluginCommands(pluginCommands)
        indexedApps = await appItems
        indexedPluginCommands = await pluginItems
    }

    func search(query: String) -> [SearchResultItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return (appSuggestions() + indexedPluginCommands)
                .sorted { $0.score > $1.score }
                .prefix(24)
                .map { $0 }
        }

        let queryKey = normalizedQuery.lowercased()
        let appMatches = indexedApps.compactMap { app -> SearchResultItem? in
            let score = matchScore(query: queryKey, candidate: app.name.lowercased())
            guard score > 0 else { return nil }
            return SearchResultItem(
                title: app.name,
                subtitle: app.url.path,
                source: "App",
                score: score,
                action: .openApplication(app.url)
            )
        }

        let pluginMatches = indexedPluginCommands.compactMap { item -> SearchResultItem? in
            let titleScore = matchScore(query: queryKey, candidate: item.title.lowercased())
            let subtitleScore = matchScore(query: queryKey, candidate: item.subtitle.lowercased()) / 2
            let score = max(titleScore, subtitleScore)
            guard score > 0 else { return nil }
            return SearchResultItem(
                id: item.id,
                title: item.title,
                subtitle: item.subtitle,
                source: item.source,
                score: score + 100,
                action: item.action
            )
        }

        return (appMatches + pluginMatches)
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.title < rhs.title
                }
                return lhs.score > rhs.score
            }
            .prefix(40)
            .map { $0 }
    }

    private func indexApplications() -> [IndexedApp] {
        let fm = FileManager.default
        let urls = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        var items: [IndexedApp] = []
        for baseURL in urls where fm.fileExists(atPath: baseURL.path) {
            let enumerator = fm.enumerator(
                at: baseURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            while let item = enumerator?.nextObject() as? URL {
                guard item.pathExtension.lowercased() == "app" else { continue }
                let name = item.deletingPathExtension().lastPathComponent
                items.append(IndexedApp(name: name, url: item))
            }
        }

        let deduplicated = Dictionary(grouping: items, by: \.name)
            .compactMap { $0.value.first }
        return deduplicated.sorted { $0.name < $1.name }
    }

    private func indexPluginCommands(_ commands: [PluginCommand]) -> [SearchResultItem] {
        commands.compactMap { command in
            let lowerType = command.action.type.lowercased()
            switch lowerType {
            case "url":
                guard let url = URL(string: command.action.value) else { return nil }
                return SearchResultItem(
                    title: command.title,
                    subtitle: command.subtitle,
                    source: "Plugin",
                    score: 400,
                    action: .openURL(url)
                )
            case "shell":
                return SearchResultItem(
                    title: command.title,
                    subtitle: command.subtitle,
                    source: "Plugin",
                    score: 350,
                    action: .runShellCommand(command.action.value)
                )
            default:
                return nil
            }
        }
    }

    private func appSuggestions() -> [SearchResultItem] {
        indexedApps.prefix(12).map { app in
            SearchResultItem(
                title: app.name,
                subtitle: app.url.path,
                source: "App",
                score: 120,
                action: .openApplication(app.url)
            )
        }
    }

    private func matchScore(query: String, candidate: String) -> Int {
        let normalizedQuery = normalize(query)
        let normalizedCandidate = normalize(candidate)
        guard !normalizedQuery.isEmpty, !normalizedCandidate.isEmpty else { return 0 }

        if normalizedCandidate == normalizedQuery { return 1200 }
        if normalizedCandidate.hasPrefix(normalizedQuery) { return 1000 - normalizedCandidate.count }
        if wordPrefixMatch(query: normalizedQuery, candidate: normalizedCandidate) {
            return 860 - normalizedCandidate.count
        }
        if normalizedCandidate.contains(normalizedQuery) { return 760 - normalizedCandidate.count }

        let subsequence = subsequenceScore(query: normalizedQuery, candidate: normalizedCandidate)
        if subsequence > 0 {
            return subsequence
        }

        // Typo tolerance for short-medium queries.
        if normalizedQuery.count <= 24, normalizedCandidate.count <= 64 {
            let distance = levenshteinDistance(from: normalizedQuery, to: normalizedCandidate)
            if distance <= 2 {
                return 520 - (distance * 120) - normalizedCandidate.count
            }
        }

        return 0
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func wordPrefixMatch(query: String, candidate: String) -> Bool {
        candidate.split(separator: " ").contains { $0.hasPrefix(query) }
    }

    private func subsequenceScore(query: String, candidate: String) -> Int {
        let queryChars = Array(query)
        let candidateChars = Array(candidate)
        guard !queryChars.isEmpty, !candidateChars.isEmpty else { return 0 }

        var qIndex = 0
        var cIndex = 0
        var lastMatch = -1
        var gaps = 0

        while qIndex < queryChars.count, cIndex < candidateChars.count {
            if queryChars[qIndex] == candidateChars[cIndex] {
                if lastMatch >= 0 {
                    gaps += max(0, cIndex - lastMatch - 1)
                }
                lastMatch = cIndex
                qIndex += 1
            }
            cIndex += 1
        }

        guard qIndex == queryChars.count else { return 0 }
        return 620 - (gaps * 7) - candidateChars.count
    }

    private func levenshteinDistance(from lhs: String, to rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        var current = Array(repeating: 0, count: b.count + 1)

        for (i, aChar) in a.enumerated() {
            current[0] = i + 1
            for (j, bChar) in b.enumerated() {
                let substitutionCost = aChar == bChar ? 0 : 1
                current[j + 1] = min(
                    previous[j + 1] + 1,
                    current[j] + 1,
                    previous[j] + substitutionCost
                )
            }
            swap(&previous, &current)
        }

        return previous[b.count]
    }
}
