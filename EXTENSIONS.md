# Elbert Extensions SDK

Elbert supports launcher extensions written in Swift. Extensions can add custom UI and behavior while users control enable/disable state in Settings.

## Current Model

- Extensions are regular Swift source files compiled into the app.
- Each extension registers metadata and a SwiftUI view.
- Users can enable or disable each installed extension in **Settings -> Extensions**.

## Build an Extension

1. Create a new Swift file in the app (for example: `Elbert/Features/Launcher/MyAwesomeExtension.swift`).
2. Return an `AnyLauncherExtension` from a factory.
3. Register it in `LauncherExtensionRegistry.default` in `LauncherExtensionSDK.swift`.

Example:

```swift
import SwiftUI

enum MyAwesomeExtension {
    static func make() -> AnyLauncherExtension {
        AnyLauncherExtension(
            id: "com.yourname.elbert.my-awesome-extension",
            name: "My Awesome Extension",
            summary: "Adds a custom launcher overlay.",
            author: "Your Name",
            version: "1.0.0",
            defaultEnabled: true,
            placement: .floatingBottomTrailing,
            order: 100
        ) { context in
            Text("Hello from extension")
                .padding(8)
                .background(.thinMaterial, in: Capsule())
        }
    }
}
```

Then add it to registry entries:

```swift
static let `default` = LauncherExtensionRegistry(
    entries: [
        ActionsLauncherExtension.make(),
        MyAwesomeExtension.make()
    ]
)
```

## Extension Context

`LauncherExtensionContext` gives extension authors runtime data and app actions:

- `query`: current launcher query.
- `hasResults`: whether search has results.
- `selectedResult`: currently selected result item.
- `actions`: app commands such as run selected result, clear query, rebuild index, dismiss launcher, and open settings.

## Community Sharing

Recommended sharing paths:

1. Open a PR to this repository with your extension file and registry entry.
2. Publish your extension source in a public repo so others can copy it into their Elbert build.
3. Keep IDs globally unique (`reverse.domain.name` style).

## Quality Checklist

- Keep IDs stable after release.
- Provide clear `summary`, `author`, and semantic `version`.
- Avoid blocking work on the main thread.
- Make UI responsive at different launcher sizes.
- Test enabled/disabled behavior from Settings.
