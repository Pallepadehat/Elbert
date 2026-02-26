# Elbert

Elbert is a fast macOS launcher built with SwiftUI. It helps you find and open apps, run plugin commands, and stay in flow with a global shortcut.

## Why Elbert

- Fast, keyboard-first launcher experience
- Native SwiftUI macOS app
- Plugin manifests powered by simple JSON files
- Fuzzy search with typo tolerance

## Current Features

- **Global shortcut launcher**: Open Elbert from anywhere (default: `Cmd + Shift + Space`).
- **Application indexing**: Indexes apps from `/Applications` and `~/Applications`.
- **Plugin commands**: Add URL and shell commands via JSON manifest files.
- **Fuzzy search ranking**: Prefix, contains, subsequence, and typo-tolerant matching.
- **Onboarding and settings**: First-run onboarding, hotkey recorder, plugin folder access, index rebuild.

## Upcoming Features

These are planned features for future releases:

1. **Root file indexing (Spotlight-style, faster)**
   - Index files in configured root folders for instant lookup.
   - Keep indexing incremental and lightweight for fast updates.

2. **Clipboard history with CloudKit sync**
   - Local clipboard timeline.
   - Optional CloudKit sync across your Apple devices.

3. **Calculator**
   - Inline expression evaluation from the launcher.
   - Fast copy of results.

4. **Currency conversion**
   - Quick currency conversions from natural input.
   - Cached rates with background refresh.

## Plugin Format

Plugins are JSON manifests stored in:

`~/Library/Application Support/Elbert/Plugins`

Example:

```json
{
  "name": "My Commands",
  "commands": [
    {
      "id": "open-apple",
      "title": "Open Apple",
      "subtitle": "https://apple.com",
      "action": {
        "type": "url",
        "value": "https://apple.com"
      }
    },
    {
      "id": "say-hello",
      "title": "Hello",
      "subtitle": "Run shell command",
      "action": {
        "type": "shell",
        "value": "echo hello"
      }
    }
  ]
}
```

Supported action types:

- `url` -> opens a URL
- `shell` -> runs a shell command via `zsh -lc`

## Development

### Requirements

- macOS (latest stable recommended)
- Xcode (latest stable recommended)

### Run locally

1. Clone the repository.
2. Open `Elbert.xcodeproj` in Xcode.
3. Select the `Elbert` target/scheme.
4. Build and run.

### Architecture (high level)

- `AppCoordinator`: App state and orchestration.
- `SearchIndex`: Application and plugin command indexing + ranking.
- `PluginManager`: Plugin manifest discovery/parsing.
- `ActionExecutor`: Executes selected actions (app, URL, shell).
- `Features/*`: UI for launcher, onboarding, settings, and menu bar.

## Community

Contributions are welcome. To get started, read:

- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`
- `ROADMAP.md`

## License

This project is licensed under the `Elbert Non-Commercial License v1.0` (see `LICENSE`).
This is a source-available license and is not OSI open source.
