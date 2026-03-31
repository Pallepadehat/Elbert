# Elbert

Elbert is a fast macOS launcher built with SwiftUI. It helps you find and open apps, search indexed files, and stay in flow with a global shortcut.

## Preview

![Elbert Preview](Elbert/Assets.xcassets/PreviewImage.imageset/PreviewImage.png)

## Why Elbert

- Fast, keyboard-first launcher experience
- Native SwiftUI macOS app
- Configurable folder indexing for file search
- Fuzzy search with typo tolerance

## Current Features

- **Global shortcut launcher**: Open Elbert from anywhere (default: `Cmd + Shift + Space`).
- **Non-Carbon global shortcut backend**: Event-tap based shortcut capture for reliable use across apps (requires Accessibility permission).
- **Application indexing**: Indexes apps from `/Applications`, `/Applications/Utilities`, `/System/Applications`, `/System/Applications/Utilities`, and `~/Applications`.
- **File indexing**: Index selected folders and search files by name, extension, and path tokens.
- **Clipboard history command mode**: Type `clipboard`, `clip`, or `cliboard` to open a dedicated clipboard history list.
- **Clipboard paste handoff**: Press `Enter` on a clipboard item to copy, paste into your previous app (`Cmd+V`), and close Elbert.
- **Launcher copy shortcuts**: `Cmd+C` copies selected value and closes Elbert, `Cmd+Shift+C` keeps copy-path for file results.
- **Configurable search matching**: Toggle fuzzy mode in Settings (fuzzy with typo tolerance or strict matching only).
- **Result match highlighting**: Query-matched title segments are highlighted when fuzzy mode is enabled.
- **Local voice mode**: Push-to-talk voice query capture in launcher with real-time audio visualizer.
- **Voice controls in settings**: Configure voice mode, push-to-talk modifier key, and speech locale/language.
- **Voice availability and permissions checks**: Built-in status + shortcut to system settings when permissions are denied.
- **Onboarding and settings**: First-run onboarding, hotkey recorder, indexed folder management, and index rebuild.

## Latest Merged PRs

- **PR #4**: Added fuzzy mode toggle, strict matching mode, and query-highlighted launcher results.
- **PR #3**: Added local Apple voice mode foundation with configurable push-to-talk and reactive visualizer.

## Upcoming Features

These are planned features for future releases:

1. **Currency conversion**
   - Quick currency conversions from natural input.
   - Cached rates with background refresh.

2. **Clipboard history sync (future extension)**
   - Optional CloudKit sync across your Apple devices.

## Development

### Requirements

- macOS (latest stable recommended)
- Xcode (latest stable recommended)

### Run locally

1. Clone the repository.
2. Open `Elbert.xcodeproj` in Xcode.
3. Select the `Elbert` target/scheme.
4. Build and run.

### Permissions and distribution

- Elbert is configured for direct distribution (not App Store sandboxed).
- Global shortcut and automated paste require macOS Accessibility permission for Elbert.
- Voice mode still requires microphone and speech recognition permissions.

### Architecture (high level)

- `AppCoordinator`: App state and orchestration.
- `SearchIndex`: Application and indexed file search + ranking.
- `ActionExecutor`: Executes selected actions (app, URL, shell).
- `Features/*`: UI for launcher, onboarding, settings, and menu bar.

## Open Source

Contributions are welcome. To get started, read:

- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`
- `ROADMAP.md`

## License

This project is licensed under the `MIT License` (see `LICENSE`).
