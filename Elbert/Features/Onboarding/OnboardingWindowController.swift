//
//  OnboardingWindowController.swift
//  Elbert
//

import SwiftUI
import AppKit

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    func show() {
        let window = window ?? makeWindow()
        if self.window == nil {
            self.window = window
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.animationBehavior = .documentWindow
        window.delegate = self

        if let coordinator {
            let root = OnboardingView()
                .environmentObject(coordinator)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            window.contentView = NSHostingView(rootView: root)
        }

        return window
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            coordinator?.dismissOnboarding()
        }
    }
}
