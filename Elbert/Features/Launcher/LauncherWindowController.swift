//
//  LauncherWindowController.swift
//  Elbert
//

import SwiftUI
import AppKit

@MainActor
final class LauncherWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func show() {
        let panel = panel ?? makePanel()
        if self.panel == nil {
            self.panel = panel
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 520),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.animationBehavior = .utilityWindow
        panel.delegate = self

        if let coordinator {
            let launcherView = LauncherView()
                .environmentObject(coordinator)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            panel.contentView = NSHostingView(rootView: launcherView)
        }

        return panel
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowDidResignKey(_ notification: Notification) {
        Task { @MainActor in
            coordinator?.dismissLauncher()
        }
    }
}
