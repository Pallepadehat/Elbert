//
//  MenuBarContentView.swift
//  Elbert
//

import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                coordinator.toggleLauncher()
            } label: {
                Label("Open Launcher", systemImage: "command")
            }
            .keyboardShortcut(.space, modifiers: [.command, .shift])

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }

            Divider()

            Button(role: .destructive) {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Elbert", systemImage: "power")
            }
        }
        .padding(8)
        .frame(minWidth: 220)
    }
}
