//
//  LauncherExtensionSDK.swift
//  Elbert
//

import SwiftUI

enum LauncherExtensionPlacement: Hashable {
    case floatingBottomTrailing
}

struct LauncherExtensionActions {
    let runSelectedResult: () -> Void
    let clearQuery: () -> Void
    let rebuildIndex: () -> Void
    let dismissLauncher: () -> Void
    let openSettings: () -> Void
}

struct LauncherExtensionContext {
    let query: String
    let hasResults: Bool
    let selectedResult: SearchResultItem?
    let actions: LauncherExtensionActions
}

struct AnyLauncherExtension: Identifiable {
    let id: String
    let name: String
    let summary: String
    let author: String
    let version: String
    let defaultEnabled: Bool
    let placement: LauncherExtensionPlacement
    let order: Int
    private let isEnabledClosure: (LauncherExtensionContext) -> Bool
    private let makeViewClosure: (LauncherExtensionContext) -> AnyView

    init<Content: View>(
        id: String,
        name: String,
        summary: String,
        author: String = "Community",
        version: String = "1.0.0",
        defaultEnabled: Bool = true,
        placement: LauncherExtensionPlacement,
        order: Int = 0,
        isEnabled: @escaping (LauncherExtensionContext) -> Bool = { _ in true },
        @ViewBuilder makeView: @escaping (LauncherExtensionContext) -> Content
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.author = author
        self.version = version
        self.defaultEnabled = defaultEnabled
        self.placement = placement
        self.order = order
        self.isEnabledClosure = isEnabled
        self.makeViewClosure = { context in AnyView(makeView(context)) }
    }

    func isEnabled(in context: LauncherExtensionContext) -> Bool {
        isEnabledClosure(context)
    }

    func makeView(in context: LauncherExtensionContext) -> AnyView {
        makeViewClosure(context)
    }
}

struct LauncherExtensionRegistry {
    let entries: [AnyLauncherExtension]

    func extensions(
        for placement: LauncherExtensionPlacement,
        context: LauncherExtensionContext,
        enabledIDs: Set<String>
    ) -> [AnyLauncherExtension] {
        entries
            .filter { enabledIDs.contains($0.id) && $0.placement == placement && $0.isEnabled(in: context) }
            .sorted { $0.order < $1.order }
    }

    var sortedEntries: [AnyLauncherExtension] {
        entries.sorted { $0.order < $1.order }
    }

    static let `default` = LauncherExtensionRegistry(
        entries: [
            ActionsLauncherExtension.make()
        ]
    )
}
