//
//  AppCoordinator.swift
//  Elbert
//

import Foundation
import Combine
import AppKit

@MainActor
final class AppCoordinator: ObservableObject {
    enum ResultPrioritySource: String, CaseIterable, Identifiable {
        case app
        case file

        var id: String { rawValue }

        var title: String {
            switch self {
            case .app: "Apps"
            case .file: "Files"
            }
        }
    }

    @Published private(set) var state = LauncherState()
    @Published private(set) var hotkeyShortcut: HotkeyShortcut
    @Published private(set) var indexedRootPaths: [String]
    @Published private(set) var resultPriorityOrder: [ResultPrioritySource]
    @Published private(set) var isRebuildingIndex = false
    @Published private(set) var isBackgroundRefreshingIndex = false
    @Published private(set) var voiceCaptureState: VoiceCaptureState = .idle
    @Published private(set) var isVoiceModeEnabled: Bool
    @Published private(set) var voicePushToTalkModifier: VoicePushToTalkModifier
    @Published private(set) var voiceLocaleIdentifier: String
    @Published private(set) var voiceInputLevel: Double = 0
    @Published private(set) var voiceAvailabilityText: String = "Checking…"
    @Published private(set) var voicePermissionText: String = "Checking…"
    @Published private(set) var shouldShowVoicePermissionShortcut = false

    private let hotkeyStore: HotkeyStore
    private let hotkeyManager: HotkeyManager
    private let searchIndex: SearchIndex
    private let actionExecutor: ActionExecutor
    private let voiceModeService: VoiceModeService
    private let defaults: UserDefaults

    private var launcherWindowController: LauncherWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var didStart = false
    private var didConfigureVoiceMetering = false
    private var cancellables = Set<AnyCancellable>()
    private var backgroundRefreshTask: Task<Void, Never>?
    private var indexedRootBookmarks: [String: Data]
    private var activeSecurityScopedRoots: [String: URL] = [:]
    private let indexedRootPathsKey = "search.indexedRootPaths"
    private let indexedRootBookmarksKey = "search.indexedRootBookmarks"
    private let resultPriorityOrderKey = "search.priority.order"
    private let voiceModeEnabledKey = "voice.mode.enabled"
    private let voicePushToTalkModifierKey = "voice.pushToTalk.modifier"
    private let voiceLocaleIdentifierKey = "voice.locale.identifier"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let hotkeyStore = HotkeyStore(defaults: defaults)
        self.hotkeyStore = hotkeyStore
        self.hotkeyManager = HotkeyManager()
        self.searchIndex = SearchIndex()
        self.actionExecutor = ActionExecutor()
        let voicePushToTalkModifier = AppCoordinator.loadVoicePushToTalkModifier(from: defaults)
        let voiceLocaleIdentifier = AppCoordinator.loadVoiceLocaleIdentifier(from: defaults)
        self.voicePushToTalkModifier = voicePushToTalkModifier
        self.voiceLocaleIdentifier = voiceLocaleIdentifier
        let voiceCapabilityChecker = VoiceAvailabilityService(localeIdentifier: voiceLocaleIdentifier)
        let speechCapturer = SpeechCaptureService(localeIdentifier: voiceLocaleIdentifier)
        let transcriptRefiner = TranscriptRefinementService(capabilityChecker: voiceCapabilityChecker)
        self.voiceModeService = VoiceModeService(
            speechCapturer: speechCapturer,
            transcriptRefiner: transcriptRefiner,
            capabilityChecker: voiceCapabilityChecker
        )
        self.hotkeyShortcut = hotkeyStore.shortcut
        self.indexedRootPaths = AppCoordinator.loadIndexedRootPaths(from: defaults)
        self.indexedRootBookmarks = AppCoordinator.loadIndexedRootBookmarks(from: defaults)
        self.resultPriorityOrder = AppCoordinator.loadResultPriorityOrder(from: defaults)
        self.isVoiceModeEnabled = AppCoordinator.loadVoiceModeEnabled(from: defaults)
        self.restoreSecurityScopedRootAccess()

        // LauncherState is a nested ObservableObject. SwiftUI only observes
        // the coordinator's objectWillChange, so we forward state changes up.
        state.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func start() {
        guard !didStart else { return }
        didStart = true

        launcherWindowController = LauncherWindowController(coordinator: self)
        onboardingWindowController = OnboardingWindowController(coordinator: self)
        hotkeyManager.onHotkeyPressed = { [weak self] in
            self?.toggleLauncher()
        }

        if !state.isOnboardingComplete {
            onboardingWindowController?.show()
        }

        Task {
            configureVoiceMeteringIfNeeded()
            await rebuildIndexAndSearch()
            registerCurrentShortcut()
            await refreshVoiceAvailability()
            await search()
        }
    }

    func toggleLauncher() {
        guard let launcherWindowController else { return }
        if launcherWindowController.isVisible {
            dismissLauncher()
        } else {
            state.query = ""
            state.statusMessage = nil
            Task { await search() }
            launcherWindowController.show()
            state.isLauncherVisible = true
        }
    }

    func dismissLauncher() {
        cancelVoiceCapture()
        launcherWindowController?.hide()
        state.isLauncherVisible = false
    }

    func updateQuery(_ value: String) {
        state.query = value
        Task { await search() }
    }

    func runSelectedResult() {
        guard let selectedID = state.selectedResultID ?? state.results.first?.id,
              let result = state.results.first(where: { $0.id == selectedID }) else {
            return
        }
        run(result: result)
    }

    func run(result: SearchResultItem) {
        Task {
            do {
                try await actionExecutor.execute(result.action)
                await MainActor.run {
                    state.statusMessage = nil
                    launcherWindowController?.hide()
                    state.isLauncherVisible = false
                }
            } catch {
                await MainActor.run {
                    state.statusMessage = error.localizedDescription
                }
            }
        }
    }

    func completeOnboarding() {
        defaults.set(true, forKey: "onboarding.complete")
        state.isOnboardingComplete = true
        dismissOnboarding()
    }

    func dismissOnboarding() {
        onboardingWindowController?.hide()
    }

    func showOnboardingForDebug(resetCompletion: Bool) {
        if resetCompletion {
            defaults.set(false, forKey: "onboarding.complete")
            state.isOnboardingComplete = false
        }
        onboardingWindowController?.show()
    }

    func rebuildIndexFromSettings() {
        Task { await rebuildIndexAndSearch() }
    }

    func addIndexRootFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose folders to index"
        panel.prompt = "Add"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK else { return }
        mergeIndexedRootFolders(panel.urls)
        Task { await rebuildIndexAndSearch() }
    }

    func removeIndexRootFolder(_ path: String) {
        indexedRootPaths.removeAll { $0 == path }
        indexedRootBookmarks[path] = nil
        stopAccessingSecurityScopedRoot(path: path)
        persistIndexedRootPaths()
        persistIndexedRootBookmarks()
        Task { await rebuildIndexAndSearch() }
    }

    func openIndexedRootFolder(_ path: String) {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let opened = NSWorkspace.shared.open(url)
        if !opened {
            state.statusMessage = "Could not open folder."
        }
    }

    func revealFileInFinder(for result: SearchResultItem) {
        guard case .openFile(let url) = result.action else { return }
        Task {
            do {
                try await actionExecutor.execute(.revealInFinder(url))
            } catch {
                await MainActor.run {
                    state.statusMessage = error.localizedDescription
                }
            }
        }
    }

    func copyPath(for result: SearchResultItem) {
        guard case .openFile(let url) = result.action else { return }
        Task {
            do {
                try await actionExecutor.execute(.copyToClipboard(url.path))
                await MainActor.run {
                    state.statusMessage = "Copied path."
                }
            } catch {
                await MainActor.run {
                    state.statusMessage = error.localizedDescription
                }
            }
        }
    }

    func moveResultPriority(fromOffsets: IndexSet, toOffset: Int) {
        resultPriorityOrder = reordered(resultPriorityOrder, fromOffsets: fromOffsets, toOffset: toOffset)
        persistRankingPreferences()
        Task { await applyRankingPreferencesAndSearch() }
    }

    func updateShortcut(_ newShortcut: HotkeyShortcut) {
        let previous = hotkeyShortcut
        hotkeyStore.update(newShortcut)
        hotkeyShortcut = newShortcut

        do {
            try hotkeyManager.register(shortcut: newShortcut)
            state.statusMessage = nil
        } catch {
            hotkeyStore.update(previous)
            hotkeyShortcut = previous
            state.statusMessage = error.localizedDescription
        }
    }

    func setVoiceModeEnabled(_ isEnabled: Bool) {
        isVoiceModeEnabled = isEnabled
        defaults.set(isEnabled, forKey: voiceModeEnabledKey)
        if !isEnabled {
            cancelVoiceCapture()
            voiceCaptureState = .idle
            voiceInputLevel = 0
            state.statusMessage = nil
        }
    }

    func setVoicePushToTalkModifier(_ modifier: VoicePushToTalkModifier) {
        voicePushToTalkModifier = modifier
        defaults.set(modifier.rawValue, forKey: voicePushToTalkModifierKey)
    }

    func setVoiceLocaleIdentifier(_ identifier: String) {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        voiceLocaleIdentifier = trimmed
        defaults.set(trimmed, forKey: voiceLocaleIdentifierKey)

        Task {
            await voiceModeService.updateLocaleIdentifier(trimmed)
            await refreshVoiceAvailability()
        }
    }

    var voiceLocaleOptions: [String] {
        let seed = [
            voiceLocaleIdentifier,
            Locale.current.identifier,
            "en-US",
            "da-DK",
            "en-GB",
            "de-DE",
            "fr-FR",
            "es-ES"
        ]

        var seen = Set<String>()
        return seed
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    func refreshVoiceAvailabilityFromSettings() {
        Task { await refreshVoiceAvailability() }
    }

    func openVoicePermissionSettings() {
        let urls = [
            URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Microphone"),
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"),
            URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_SpeechRecognition"),
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
        ]

        for candidate in urls.compactMap({ $0 }) {
            if NSWorkspace.shared.open(candidate) {
                return
            }
        }
    }

    func startVoiceCapture() {
        guard state.isLauncherVisible else { return }
        guard isVoiceModeEnabled else { return }
        guard voiceCaptureState != .listening else { return }

        Task {
            let availability = await voiceModeService.prepareForCapture()
            await MainActor.run {
                applyVoiceAvailability(availability)
            }

            guard availability.isVoiceModeSupported else {
                await MainActor.run {
                    voiceCaptureState = .unavailable("Voice unavailable on this Mac")
                    state.statusMessage = "Voice unavailable on this Mac"
                }
                return
            }

            guard availability.authorization.isFullyAuthorized else {
                await MainActor.run {
                    voiceCaptureState = .error("Microphone and Speech permissions are required")
                    state.statusMessage = "Grant Microphone and Speech permissions in Settings."
                }
                return
            }

            do {
                try await voiceModeService.startCapture()
                await MainActor.run {
                    voiceCaptureState = .listening
                    state.statusMessage = "Listening…"
                }
            } catch {
                await MainActor.run {
                    voiceCaptureState = .error(error.localizedDescription)
                    state.statusMessage = error.localizedDescription
                }
            }
        }
    }

    func stopVoiceCaptureAndProcess() {
        guard voiceCaptureState == .listening else { return }
        voiceCaptureState = .processing
        state.statusMessage = "Processing…"

        Task {
            do {
                let result = try await voiceModeService.stopCaptureAndProcess()
                await MainActor.run {
                    state.query = result.finalQuery
                }
                await search()
                await MainActor.run {
                    voiceCaptureState = .idle
                    state.statusMessage = nil
                }
            } catch {
                await MainActor.run {
                    voiceCaptureState = .error(error.localizedDescription)
                    state.statusMessage = error.localizedDescription
                }
            }
        }
    }

    func cancelVoiceCapture() {
        Task {
            await voiceModeService.cancelCapture()
            await MainActor.run {
                if case .listening = voiceCaptureState {
                    voiceCaptureState = .idle
                    state.statusMessage = nil
                }
                voiceInputLevel = 0
            }
        }
    }

    private func rebuildIndexAndSearch() async {
        isRebuildingIndex = true
        defer { isRebuildingIndex = false }
        await applyRankingPreferences()
        await searchIndex.rebuildIndex(fileRoots: indexedRootPaths)
        await search()
        startBackgroundRefreshLoopIfNeeded()
    }

    private func registerCurrentShortcut() {
        do {
            try hotkeyManager.register(shortcut: hotkeyShortcut)
            state.statusMessage = nil
        } catch {
            state.statusMessage = error.localizedDescription
        }
    }

    private func search() async {
        let results = await searchIndex.search(query: state.query)
        await MainActor.run {
            state.results = results
            if state.selectedResultID == nil || !results.contains(where: { $0.id == state.selectedResultID }) {
                state.selectedResultID = results.first?.id
            }
        }
    }

    private func refreshVoiceAvailability() async {
        let availability = await voiceModeService.capabilityStatus()
        await MainActor.run {
            applyVoiceAvailability(availability)
            if !availability.isVoiceModeSupported {
                voiceCaptureState = .unavailable("Voice unavailable on this Mac")
            } else if case .unavailable = voiceCaptureState {
                voiceCaptureState = .idle
            }
        }
    }

    private func configureVoiceMeteringIfNeeded() {
        guard !didConfigureVoiceMetering else { return }
        didConfigureVoiceMetering = true

        Task {
            await voiceModeService.setLevelHandler { [weak self] level in
                Task { @MainActor [weak self] in
                    self?.voiceInputLevel = level
                }
            }
        }
    }

    private func applyVoiceAvailability(_ availability: VoiceCapabilityStatus) {
        voiceAvailabilityText = availability.availabilityText
        voicePermissionText = availability.permissionText
        shouldShowVoicePermissionShortcut = availability.hasDeniedPermission
    }

    private func applyRankingPreferencesAndSearch() async {
        await applyRankingPreferences()
        await search()
    }

    private func applyRankingPreferences() async {
        var boostBySource: [ResultPrioritySource: Int] = [:]
        for (index, source) in resultPriorityOrder.enumerated() {
            // Highest row gets the largest boost.
            boostBySource[source] = (resultPriorityOrder.count - index - 1) * 160
        }

        await searchIndex.updateRankingPreferences(
            .init(
                appBoost: boostBySource[.app] ?? 0,
                fileBoost: boostBySource[.file] ?? 0
            )
        )
    }

    private func startBackgroundRefreshLoopIfNeeded() {
        guard backgroundRefreshTask == nil else { return }
        backgroundRefreshTask = Task { [weak self] in
            while !(Task.isCancelled) {
                try? await Task.sleep(for: .seconds(15))
                guard let self else { return }
                await self.backgroundRefreshIndex()
            }
        }
    }

    private func backgroundRefreshIndex() async {
        guard !isRebuildingIndex, !indexedRootPaths.isEmpty else { return }
        isBackgroundRefreshingIndex = true
        defer { isBackgroundRefreshingIndex = false }
        await searchIndex.refreshFileIndexIncrementally(rootPaths: indexedRootPaths)
        await search()
    }

    private func mergeIndexedRootFolders(_ urls: [URL]) {
        var seen = Set<String>(indexedRootPaths)
        for url in urls {
            let standardized = url.standardizedFileURL
            let path = standardized.path
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if let bookmark = createSecurityScopedBookmark(for: standardized) {
                indexedRootBookmarks[trimmed] = bookmark
            }

            startAccessingSecurityScopedRoot(url: standardized)

            if seen.insert(trimmed).inserted {
                indexedRootPaths.append(trimmed)
            }
        }
        indexedRootPaths.sort()
        persistIndexedRootPaths()
        persistIndexedRootBookmarks()
    }

    private func persistIndexedRootPaths() {
        defaults.set(indexedRootPaths, forKey: indexedRootPathsKey)
    }

    private func persistIndexedRootBookmarks() {
        defaults.set(indexedRootBookmarks, forKey: indexedRootBookmarksKey)
    }

    private func persistRankingPreferences() {
        defaults.set(resultPriorityOrder.map(\.rawValue), forKey: resultPriorityOrderKey)
    }

    private static func loadResultPriorityOrder(from defaults: UserDefaults) -> [ResultPrioritySource] {
        guard let raw = defaults.array(forKey: "search.priority.order") as? [String] else {
            return [.app, .file]
        }

        let parsed = raw.compactMap(ResultPrioritySource.init(rawValue:))
        var seen = Set<ResultPrioritySource>()
        let unique = parsed.filter { seen.insert($0).inserted }
        let all = Set(ResultPrioritySource.allCases)
        let existing = Set(unique)
        let missing = ResultPrioritySource.allCases.filter { !existing.contains($0) }
        let completed = unique + missing
        return completed.filter { all.contains($0) }
    }

    private func reordered(
        _ items: [ResultPrioritySource],
        fromOffsets: IndexSet,
        toOffset: Int
    ) -> [ResultPrioritySource] {
        var result = items
        let moving = fromOffsets.map { result[$0] }
        for index in fromOffsets.sorted(by: >) {
            result.remove(at: index)
        }

        var insertionIndex = toOffset
        for index in fromOffsets where index < toOffset {
            insertionIndex -= 1
        }

        insertionIndex = max(0, min(insertionIndex, result.count))
        result.insert(contentsOf: moving, at: insertionIndex)
        return result
    }

    private static func loadIndexedRootPaths(from defaults: UserDefaults) -> [String] {
        if let stored = defaults.array(forKey: "search.indexedRootPaths") as? [String], !stored.isEmpty {
            return stored
                .map { NSString(string: $0).expandingTildeInPath }
                .map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL.path }
        }

        let fm = FileManager.default
        let defaultURL = fm.homeDirectoryForCurrentUser.appendingPathComponent("Documents", isDirectory: true)
        if fm.fileExists(atPath: defaultURL.path) {
            return [defaultURL.path]
        }

        return [fm.homeDirectoryForCurrentUser.path]
    }

    private static func loadIndexedRootBookmarks(from defaults: UserDefaults) -> [String: Data] {
        defaults.dictionary(forKey: "search.indexedRootBookmarks") as? [String: Data] ?? [:]
    }

    private static func loadVoiceModeEnabled(from defaults: UserDefaults) -> Bool {
        if defaults.object(forKey: "voice.mode.enabled") == nil {
            return true
        }
        return defaults.bool(forKey: "voice.mode.enabled")
    }

    private static func loadVoicePushToTalkModifier(from defaults: UserDefaults) -> VoicePushToTalkModifier {
        guard let raw = defaults.string(forKey: "voice.pushToTalk.modifier"),
              let modifier = VoicePushToTalkModifier(rawValue: raw) else {
            return .option
        }
        return modifier
    }

    private static func loadVoiceLocaleIdentifier(from defaults: UserDefaults) -> String {
        if let stored = defaults.string(forKey: "voice.locale.identifier"),
           !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return stored
        }
        if let preferred = Locale.preferredLanguages.first,
           !preferred.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return preferred
        }
        return "en-US"
    }

    private func createSecurityScopedBookmark(for url: URL) -> Data? {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            return nil
        }
    }

    private func restoreSecurityScopedRootAccess() {
        for path in indexedRootPaths {
            guard let bookmark = indexedRootBookmarks[path] else { continue }
            var stale = false

            guard let resolvedURL = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else { continue }

            let standardized = resolvedURL.standardizedFileURL
            startAccessingSecurityScopedRoot(url: standardized)

            if stale, let refreshed = createSecurityScopedBookmark(for: standardized) {
                indexedRootBookmarks[path] = refreshed
            }
        }

        persistIndexedRootBookmarks()
    }

    private func startAccessingSecurityScopedRoot(url: URL) {
        let path = url.path
        guard activeSecurityScopedRoots[path] == nil else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        activeSecurityScopedRoots[path] = url
    }

    private func stopAccessingSecurityScopedRoot(path: String) {
        guard let url = activeSecurityScopedRoots.removeValue(forKey: path) else { return }
        url.stopAccessingSecurityScopedResource()
    }

    private func stopAccessingAllSecurityScopedRoots() {
        for (_, url) in activeSecurityScopedRoots {
            url.stopAccessingSecurityScopedResource()
        }
        activeSecurityScopedRoots.removeAll()
    }
}
