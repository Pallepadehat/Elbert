//
//  LauncherExtensionHost.swift
//  Elbert
//

import SwiftUI

struct LauncherExtensionHost: View {
    let registry: LauncherExtensionRegistry
    let context: LauncherExtensionContext
    let enabledExtensionIDs: Set<String>

    var body: some View {
        let trailingExtensions = registry.extensions(
            for: .floatingBottomTrailing,
            context: context,
            enabledIDs: enabledExtensionIDs
        )

        ZStack(alignment: .bottomTrailing) {
            ForEach(trailingExtensions) { entry in
                entry.makeView(in: context)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}
