//
//  AppCoordinator.swift
//  Elbert
//

import Foundation
import Combine
import AppKit

@MainActor
final class AppCoordinator: ObservableObject {
    @Published private(set) var state = LauncherState()
    @Published private(set) var hotkeyShortcut: HotkeyShortcut
    @Published private(set) var pluginDirectoryPath: String = ""
    @Published private(set) var isRebuildingIndex = false

    private let hotkeyStore: HotkeyStore
    private let hotkeyManager: HotkeyManager
    private let searchIndex: SearchIndex
    private let actionExecutor: ActionExecutor
    private let pluginManager: PluginManager
    private let defaults: UserDefaults

    private var launcherWindowController: LauncherWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var didStart = false
    private var cancellables = Set<AnyCancellable>()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let hotkeyStore = HotkeyStore(defaults: defaults)
        self.hotkeyStore = hotkeyStore
        self.hotkeyManager = HotkeyManager()
        self.searchIndex = SearchIndex()
        self.actionExecutor = ActionExecutor()
        self.pluginManager = PluginManager()
        self.hotkeyShortcut = hotkeyStore.shortcut

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
            await reloadPluginsAndIndex()
            registerCurrentShortcut()
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

    func reloadPluginsAndIndexFromSettings() {
        Task { await reloadPluginsAndIndex() }
    }

    func openPluginsFolder() {
        let url = pluginManager.pluginDirectoryURL()
        let opened = NSWorkspace.shared.open(url)
        if !opened {
            state.statusMessage = "Could not open plugins folder."
        }
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

    private func reloadPluginsAndIndex() async {
        isRebuildingIndex = true
        defer { isRebuildingIndex = false }
        let plugins = await pluginManager.reloadPlugins()
        let commands = plugins.flatMap(\.commands)
        await searchIndex.rebuildIndex(pluginCommands: commands)
        pluginDirectoryPath = pluginManager.pluginDirectoryURL().path
        await search()
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
}
