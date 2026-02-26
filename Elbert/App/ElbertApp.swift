//
//  ElbertApp.swift
//  Elbert
//
//  Created by Patrick Jakobsen on 26/02/2026.
//

import SwiftUI

@main
struct ElbertApp: App {
    @StateObject private var coordinator: AppCoordinator

    init() {
        let coordinator = AppCoordinator()
        _coordinator = StateObject(wrappedValue: coordinator)
        coordinator.start()
    }

    var body: some Scene {
        MenuBarExtra {
                 MenuBarContentView()
                     .environmentObject(coordinator)
             } label: {
                 let image: NSImage = {
                     let ratio = $0.size.height / $0.size.width
                     $0.size.height = 25          // ønsket højde i menulinjen
                     $0.size.width = 25 / ratio   // bevar aspect ratio
                     return $0
                 }(NSImage(named: "AppImage")!)

                 Image(nsImage: image)
             }
        
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(coordinator)
        }
    }
}
