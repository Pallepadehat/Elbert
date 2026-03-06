//
//  SearchIndex.swift
//  Elbert
//

import Foundation

actor SearchIndex {
    private static let ignoredDirectoryNames: Set<String> = [
        "node_modules",
        "bower_components",
        "vendor",
        "dist",
        "build",
        "out",
        "target",
        ".next",
        ".nuxt",
        ".turbo",
        ".cache",
        ".parcel-cache",
        ".svelte-kit",
        ".angular",
        ".gradle",
        ".mvn",
        ".terraform",
        ".serverless",
        ".aws-sam",
        ".dart_tool",
        "deriveddata",
        "pods",
        "carthage",
        ".build",
        "bin",
        "obj",
        ".venv",
        "venv",
        "__pycache__",
        ".pytest_cache",
        ".mypy_cache"
    ]

    private static let ignoredFileExtensions: Set<String> = [
        "o", "obj", "class", "pyc", "pyo", "a", "dylib", "so", "dll", "tmp"
    ]

    struct RankingPreferences: Sendable {
        let appBoost: Int
        let pluginBoost: Int
        let fileBoost: Int

        static let `default` = RankingPreferences(
            appBoost: 220,
            pluginBoost: 100,
            fileBoost: 0
        )
    }

    private struct IndexedApp: Sendable {
        let name: String
        let url: URL
    }

    private struct IndexedFile: Sendable {
        let url: URL
        let path: String
        let name: String
        let baseName: String
        let fileExtension: String
        let modifiedDate: Date
        let size: Int64
        let normalizedName: String
        let normalizedPath: String
        let normalizedBaseName: String
        let normalizedExtension: String
    }

    private struct FileQuery: Sendable {
        let text: String
        let tokens: [String]
        let extensionFilter: String?
        let pathFilter: String?
    }

    private var indexedApps: [IndexedApp] = []
    private var indexedPluginCommands: [SearchResultItem] = []
    private var indexedFilesByPath: [String: IndexedFile] = [:]
    private var indexedFiles: [IndexedFile] = []
    private var indexedRoots: Set<String> = []
    private var rankingPreferences: RankingPreferences = .default

    func updateRankingPreferences(_ preferences: RankingPreferences) {
        rankingPreferences = preferences
    }

    func rebuildIndex(pluginCommands: [PluginCommand], fileRoots: [String]) async {
        async let appItems = indexApplications()
        async let pluginItems = indexPluginCommands(pluginCommands)
        indexedApps = await appItems
        indexedPluginCommands = await pluginItems
        await rebuildFileIndex(rootPaths: fileRoots)
    }

    func refreshFileIndexIncrementally(rootPaths: [String]) async {
        let rootURLs = normalizedRootURLs(from: rootPaths)
        let rootKey = Set(rootURLs.map(\.path))

        if rootKey != indexedRoots {
            await rebuildFileIndex(rootPaths: rootPaths)
            return
        }

        let refreshed = enumerateFiles(at: rootURLs, previous: indexedFilesByPath)
        indexedFilesByPath = refreshed
        indexedFiles = refreshed.values.sorted { lhs, rhs in
            if lhs.name == rhs.name {
                return lhs.path < rhs.path
            }
            return lhs.name < rhs.name
        }
    }

    func search(query: String) async -> [SearchResultItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return (appSuggestions() + indexedPluginCommands)
                .sorted { $0.score > $1.score }
                .prefix(40)
                .map { $0 }
        }

        if isLikelyCalculatorQuery(normalizedQuery) {
            if let calcResult = await calculatorResult(for: normalizedQuery) {
                return [calcResult]
            }
            return []
        }

        let queryKey = normalizedQuery.lowercased()
        let fileQuery = parseFileQuery(queryKey)

        let appMatches = indexedApps.compactMap { app -> SearchResultItem? in
            let score = matchScore(query: queryKey, candidate: app.name.lowercased())
            guard score > 0 else { return nil }
            return SearchResultItem(
                title: app.name,
                subtitle: app.url.path,
                source: "App",
                score: score + rankingPreferences.appBoost,
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
                score: score + rankingPreferences.pluginBoost,
                action: item.action
            )
        }

        let fileMatches = indexedFiles.compactMap { file -> SearchResultItem? in
            let score = fileMatchScore(query: fileQuery, file: file)
            guard score > 0 else { return nil }
            return SearchResultItem(
                title: file.name,
                subtitle: file.path,
                source: "File",
                score: score + rankingPreferences.fileBoost,
                action: .openFile(file.url)
            )
        }

        return (appMatches + pluginMatches + fileMatches)
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.title < rhs.title
                }
                return lhs.score > rhs.score
            }
            .prefix(60)
            .map { $0 }
    }

    private func rebuildFileIndex(rootPaths: [String]) async {
        let rootURLs = normalizedRootURLs(from: rootPaths)
        let rebuilt = enumerateFiles(at: rootURLs, previous: [:])

        indexedRoots = Set(rootURLs.map(\.path))
        indexedFilesByPath = rebuilt
        indexedFiles = rebuilt.values.sorted { lhs, rhs in
            if lhs.name == rhs.name {
                return lhs.path < rhs.path
            }
            return lhs.name < rhs.name
        }
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

    private func calculatorResult(for query: String) async -> SearchResultItem? {
        let result = try? await MainActor.run {
            try CalculatorEvaluator.formattedResult(for: query)
        }
        guard let result else { return nil }

        return SearchResultItem(
            title: result,
            subtitle: "Press Enter to copy result and close",
            source: "Calc",
            score: 2_000,
            action: .copyToClipboard(result)
        )
    }

    private func isLikelyCalculatorQuery(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let allowedPattern = #"^=?[\d\.\s+\-*/^()]+$"#
        guard trimmed.range(of: allowedPattern, options: .regularExpression) != nil else {
            return false
        }

        let hasDigit = trimmed.rangeOfCharacter(from: .decimalDigits) != nil
        return hasDigit
    }

    private func parseFileQuery(_ query: String) -> FileQuery {
        let parts = query
            .split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var extensionFilter: String?
        var pathFilter: String?
        var freeText: [String] = []

        for part in parts {
            if part.hasPrefix("ext:") {
                let value = String(part.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    extensionFilter = normalize(value)
                }
                continue
            }

            if part.hasPrefix("in:") {
                let value = String(part.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    pathFilter = normalize(value)
                }
                continue
            }

            freeText.append(part)
        }

        let joinedText = freeText.joined(separator: " ")
        let normalizedText = normalize(joinedText)
        let tokens = normalizedText
            .split(separator: " ")
            .map(String.init)

        return FileQuery(
            text: normalizedText,
            tokens: tokens,
            extensionFilter: extensionFilter,
            pathFilter: pathFilter
        )
    }

    private func fileMatchScore(query: FileQuery, file: IndexedFile) -> Int {
        if let extensionFilter = query.extensionFilter,
           !file.normalizedExtension.hasPrefix(extensionFilter) {
            return 0
        }

        if let pathFilter = query.pathFilter,
           !file.normalizedPath.contains(pathFilter) {
            return 0
        }

        var score = 0

        if !query.text.isEmpty {
            let nameScore = matchScoreNormalized(query: query.text, candidate: file.normalizedName)
            let baseNameScore = matchScoreNormalized(query: query.text, candidate: file.normalizedBaseName)
            let pathScore = matchScoreNormalized(query: query.text, candidate: file.normalizedPath) / 2
            let extensionScore = matchScoreNormalized(query: query.text, candidate: file.normalizedExtension)
            score = max(nameScore + 220, baseNameScore + 180, pathScore, extensionScore + 90)
        } else if query.extensionFilter != nil || query.pathFilter != nil {
            score = 360
        } else {
            return 0
        }

        for token in query.tokens {
            if file.normalizedBaseName.hasPrefix(token) {
                score += 28
            } else if file.normalizedName.contains(token) {
                score += 18
            } else if file.normalizedPath.contains(token) {
                score += 10
            }
        }

        let recencyBonus = recencyBonus(for: file.modifiedDate)
        score += recencyBonus

        if file.size <= 0 {
            score -= 10
        }

        return score
    }

    private func recencyBonus(for modifiedDate: Date) -> Int {
        let age = Date().timeIntervalSince(modifiedDate)
        if age < 24 * 3600 { return 60 }
        if age < 7 * 24 * 3600 { return 36 }
        if age < 30 * 24 * 3600 { return 18 }
        return 0
    }

    private func normalizedRootURLs(from rootPaths: [String]) -> [URL] {
        var seen = Set<String>()
        var results: [URL] = []
        let fm = FileManager.default

        for path in rootPaths {
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let expanded = NSString(string: trimmed).expandingTildeInPath
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            let url = URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
            let key = url.path
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            results.append(url)
        }

        return results
    }

    private func enumerateFiles(
        at rootURLs: [URL],
        previous: [String: IndexedFile]
    ) -> [String: IndexedFile] {
        guard !rootURLs.isEmpty else { return [:] }

        let fm = FileManager.default
        var updated: [String: IndexedFile] = [:]

        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .nameKey,
            .pathKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]

        for rootURL in rootURLs {
            let enumerator = fm.enumerator(
                at: rootURL,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            )

            while let item = enumerator?.nextObject() as? URL {
                guard let values = try? item.resourceValues(forKeys: keys) else { continue }
                if values.isDirectory == true {
                    let directoryName = (values.name ?? item.lastPathComponent).lowercased()
                    if Self.ignoredDirectoryNames.contains(directoryName) {
                        enumerator?.skipDescendants()
                    }
                    continue
                }

                guard values.isRegularFile == true else { continue }

                let path = item.path
                let name = values.name ?? item.lastPathComponent
                let fileExtension = item.pathExtension.lowercased()
                if Self.ignoredFileExtensions.contains(fileExtension) {
                    continue
                }
                let baseName = item.deletingPathExtension().lastPathComponent
                let modifiedDate = values.contentModificationDate ?? .distantPast
                let size = Int64(values.fileSize ?? 0)

                if let existing = previous[path],
                   existing.modifiedDate == modifiedDate,
                   existing.size == size {
                    updated[path] = existing
                    continue
                }

                let normalizedName = normalize(name)
                let normalizedPath = normalize(path)
                let normalizedBaseName = normalize(baseName)
                let normalizedExtension = normalize(fileExtension)

                updated[path] = IndexedFile(
                    url: item,
                    path: path,
                    name: name,
                    baseName: baseName,
                    fileExtension: fileExtension,
                    modifiedDate: modifiedDate,
                    size: size,
                    normalizedName: normalizedName,
                    normalizedPath: normalizedPath,
                    normalizedBaseName: normalizedBaseName,
                    normalizedExtension: normalizedExtension
                )
            }
        }

        return updated
    }

    private func matchScore(query: String, candidate: String) -> Int {
        let normalizedQuery = normalize(query)
        let normalizedCandidate = normalize(candidate)
        return matchScoreNormalized(query: normalizedQuery, candidate: normalizedCandidate)
    }

    private func matchScoreNormalized(query normalizedQuery: String, candidate normalizedCandidate: String) -> Int {
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
