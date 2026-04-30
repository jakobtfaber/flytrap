# Contributing

PRs are welcome. This is a personal-use app, so the bar is "would Jakob want this in his own daily workflow?", not "does this serve a wide user base?". Small focused changes land fastest.

## Before you open a PR

Run the test suite. Both invocations should print a passing summary:

```bash
swift test
```

```bash
xcodebuild \
  -project Flytrap.xcodeproj \
  -scheme Flytrap \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

CI will run both on push, but it's faster to find issues locally first.

## Code conventions

- Match the surrounding style. Most of the codebase is SwiftUI/AppKit hybrid with `@MainActor` isolation; if you're adding async work, prefer `MainActor.assumeIsolated { ... }` over `Task { @MainActor in ... }` inside Timer / completion-handler callbacks (see `AppState.swift` for the canonical pattern; the `Task` form trips Swift 6 strict concurrency).
- Don't change the on-disk format of daily notes (`<vault>/Captures/YYYY-MM-DD.md`). The exact format — `\n---\n\n` separator, `## H:mm a` time heading, `![[attachments/X|500]]` Obsidian wikilinks for media — is a contract with downstream consumers (Obsidian itself, and at least one author's Python pipeline). If you want to evolve it, open an issue first to discuss.
- Tests live in `FlytrapTests/`. New behaviour should land with new tests. Bugfixes should land with a regression test that fails on `main` and passes with the fix.

## What's likely to be merged

- Bugfixes (especially with a failing-test repro)
- New `CaptureItem` types (e.g. PDFs, audio files) with bundled-resource / serialization support
- Modernizations of the inherited Zoidberg patterns (e.g. `MainActor.assumeIsolated` rewrites, replacing Carbon `RegisterEventHotKey` with the modern `KeyboardShortcuts` API, etc.)
- macOS-version-specific UI polish (Tahoe / Sequoia behaviours)

## What's unlikely to land without discussion first

- New external dependencies. The dep graph is one package (`soffes/HotKey`) on purpose.
- Anything that replaces `UserDefaults` with a heavier persistence layer.
- Cross-platform ports (Linux/Windows). The app is intentionally macOS-only.
- Asset-catalog migrations. The current `PBXResourcesBuildPhase` + loose `.icns` / `MenubarIcon{,@2x}.png` setup works with both `xcodebuild` and SwiftPM; an Asset Catalog would only work with `xcodebuild`.

## Reporting bugs / requesting features

GitHub Issues. For security issues, see [`SECURITY.md`](SECURITY.md) — please don't file those publicly.
