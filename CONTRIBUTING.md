# Contributing to Elbert

Thanks for your interest in contributing to Elbert.

## Ground Rules

- Be kind and constructive in discussions and reviews.
- Keep changes focused and reasonably scoped.
- Prefer readability and maintainability over cleverness.
- Open an issue for large changes before starting implementation.

## Development Setup

1. Fork and clone the repository.
2. Open `Elbert.xcodeproj` in Xcode.
3. Build and run the `Elbert` target.
4. Verify onboarding, launcher, and settings flows still work.

## Code Style

- Use modern Swift and SwiftUI patterns.
- Keep architecture boundaries clear:
  - Coordination/state in `AppCoordinator`
  - Indexing/search in `SearchIndex`
  - Plugin loading in `PluginManager`
  - Action execution in `ActionExecutor`
- Use clear naming and small, testable units.

## Testing Checklist

Before opening a PR, verify:

- App builds cleanly in Xcode.
- Global shortcut registration still works.
- Launcher search works for apps and plugin commands.
- Plugin folder open/rebuild actions work.
- No obvious UI regressions in onboarding/settings/launcher.

## Pull Requests

Please include:

- A clear description of what changed and why.
- Screenshots/GIFs for UI changes when relevant.
- Manual test notes.
- Linked issue(s), if any.

## Plugin Contributions

If your PR adds plugin-related functionality:

- Document expected manifest format updates.
- Include migration guidance for existing manifests.
- Keep parser behavior explicit and backward compatible where possible.

## Reporting Bugs

Please include:

- macOS version
- Xcode version (if build related)
- Reproduction steps
- Expected behavior
- Actual behavior
- Logs or screenshots when helpful
