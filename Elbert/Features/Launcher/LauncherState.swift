//
//  LauncherState.swift
//  Elbert
//

import Foundation
import Combine

@MainActor
final class LauncherState: ObservableObject {
    @Published var query: String = ""
    @Published var results: [SearchResultItem] = []
    @Published var selectedResultID: SearchResultItem.ID?
    @Published var isLauncherVisible = false
    @Published var statusMessage: String?
    @Published var isOnboardingComplete: Bool

    init(defaults: UserDefaults = .standard) {
        isOnboardingComplete = defaults.bool(forKey: "onboarding.complete")
    }
}
