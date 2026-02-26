# Elbert Roadmap

This roadmap focuses on the next major feature set for Elbert.

## Milestone 1 - Core File Indexing (Spotlight-style, fast)

**Goal:** Search files from configured root folders with near-instant results.

### Scope

- Add configurable root folders in settings.
- Build a file metadata index (path, name, extension, modified date, size).
- Add incremental indexing and lightweight background refresh.
- Add result actions (open file, reveal in Finder, copy path).

### Exit Criteria

- Index startup on a medium project folder completes quickly.
- Query latency feels instant for normal usage.
- Rebuild and incremental refresh are stable and predictable.

## Milestone 2 - Clipboard History + CloudKit Sync

**Goal:** Make clipboard snippets searchable and optionally synced across devices.

### Scope

- Local clipboard history store with configurable retention limit.
- Clipboard result category in launcher search.
- Pin/favorite important clipboard entries.
- Optional iCloud/CloudKit sync toggle in settings.
- Conflict-safe merge behavior for cross-device updates.

### Exit Criteria

- Clipboard entries are captured reliably.
- History is searchable and fast.
- CloudKit sync can be enabled/disabled safely without data loss.

## Milestone 3 - Calculator

**Goal:** Provide instant calculations directly in the launcher.

### Scope

- Parse and evaluate common expressions (`+`, `-`, `*`, `/`, `%`, parentheses).
- Show result preview while typing.
- Enter to copy result and optional quick action to paste.
- Safe, deterministic parser behavior with clear error messages.

### Exit Criteria

- Correct results for common arithmetic expressions.
- Fast evaluation with no UI stutter.
- Clear handling of invalid expressions.

## Milestone 4 - Currency Conversion

**Goal:** Convert currencies from natural queries with reliable rates.

### Scope

- Query patterns like `100 usd to dkk` and `eur -> gbp`.
- Background exchange-rate fetch with cache and staleness handling.
- Fallback behavior when offline.
- Optional preferred currencies in settings.

### Exit Criteria

- Accurate conversions with clear rate timestamp.
- Graceful offline behavior using cached rates.
- Predictable and testable query parsing.

## Milestone 5 - OSS Readiness and Contributor Experience

**Goal:** Make Elbert easy to adopt and contribute to as a public project.

### Scope

- Finalize repository docs and governance.
- Add issue labels and triage workflow.
- Add CI checks (build + basic tests/linting).
- Expand docs for plugin authoring and architecture.

### Exit Criteria

- New contributors can run and submit a PR with minimal friction.
- Core checks run automatically on pull requests.
- Public roadmap and contribution path are clear.
