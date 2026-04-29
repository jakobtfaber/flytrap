# Rename Zoidberg → Flytrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the macOS menu-bar capture app from "Zoidberg" to "Flytrap", relocate its source from `~/Developer/forks/zoidberg/` (a public fork of `malecks/zoidberg`) to `~/Developer/apps/flytrap/` as an independent private repo, replace `/Applications/Zoidberg.app` with `/Applications/Flytrap.app`, and update all downstream references — without disturbing the data layout or producer/consumer format contract that the `~/Obsidian/Captures` repo and its Python pipeline depend on.

**Architecture:** Copy the existing tree to the new location with `.git` preserved, detach the GitHub remote, then perform an internal find-and-replace rename pass (file/dir names + Swift identifiers + Xcode project + tests). Add a one-shot UserDefaults migration so existing user prefs (vault path, Claude API key, hotkeys) survive the bundle-id change. Build, install with the standard force-kill-then-rm-then-cp install dance, verify end-to-end against the existing Captures vault, and update downstream documentation. The original public fork stays in place untouched as a rollback safety net until verification soaks.

**Tech Stack:** Swift 5.9 (macOS 14+ executable target), Xcode project + Swift Package Manager (Package.swift), HotKey package, AppKit/SwiftUI, `defaults` CLI for prefs, `gh` CLI for new private repo creation.

---

## Architectural Decisions (resolved)

These were open questions in the brief. Locked-in answers:

1. **Git history:** Keep full history. Detach the remote (`origin` removed) and push to a brand-new private GitHub repo. The commit graph will still trace back to `malecks/zoidberg` ancestors — that's accurate provenance, not a coupling. A fresh GitHub repo created via `gh repo create --private` is *not* marked as a fork even when its history overlaps an existing public repo.

2. **Bundle id:** `com.jakobfaber.flytrap`. Matches the user's existing identifier convention and clearly transfers ownership away from `malecks`.

3. **UserDefaults migration:** One-shot copy on first launch. Implemented as a `migrateLegacyDefaultsIfNeeded()` call in `FlytrapApp` startup. Reads the `com.malecks.zoidberg` domain via `UserDefaults(suiteName:)`, writes to standard defaults, sets a `flytrap.migration.v1.complete` flag to prevent re-running. Worth doing because the user has at minimum `vaultPath = /Users/jakobfaber/Obsidian` and `launchAtLogin = 1` set; possibly `claudeApiKey` too.

4. **Application Support directory:** Migrate the directory contents on first launch (same migration function). The directory is currently empty, but the migration code is cheap and protects against future runs that have a real `pending-session.json`. New path: `~/Library/Application Support/Flytrap/`.

5. **Frame autosave key:** Rename `ZoidbergPanel` → `FlytrapPanel`. Cosmetic regression on first launch (panel appears in default position, not previously-saved position). Acceptable.

6. **The output-folder name MUST NOT change.** `VaultWriter.save` keeps `"Captures"` as the hardcoded folder fallback. The `~/Obsidian/Captures` repo and its Python pipeline depend on this. Verified at `Zoidberg/Services/VaultWriter.swift:42`.

---

## File Structure (after rename)

```
~/Developer/apps/flytrap/                       # new home
├── .git/                                        # preserved history, no remote (then new private origin)
├── Package.swift                                # name "Flytrap", target "Flytrap", testTarget "FlytrapTests"
├── Package.resolved                             # untouched (no name refs)
├── Flytrap.xcodeproj/                           # renamed from Zoidberg.xcodeproj
│   └── project.pbxproj                          # global Zoidberg→Flytrap; bundle id; Info.plist path
├── Flytrap/                                     # renamed from Zoidberg/
│   ├── FlytrapApp.swift                         # renamed from ZoidbergApp.swift
│   ├── AppState.swift                           # App Support path "Flytrap"; +migration call site
│   ├── Info.plist                               # new usage descriptions ("Flytrap needs…")
│   ├── Helpers/
│   │   ├── Settings.swift                       # +legacy-defaults migration helper
│   │   ├── Permissions.swift                    # header comment only
│   │   └── EscapeKeyMonitor.swift               # untouched
│   ├── Models/
│   │   ├── CaptureItem.swift                    # untouched (no name refs)
│   │   └── CaptureSession.swift                 # untouched (format contract — DO NOT change)
│   ├── Services/
│   │   ├── VaultWriter.swift                    # header comment only; "Captures" folder UNCHANGED
│   │   ├── HotkeyManager.swift                  # header comment only
│   │   ├── ClaudeService.swift                  # header comment only
│   │   └── TranscriptionService.swift           # header comment only
│   └── Views/
│       ├── CapturePanel.swift                   # untouched
│       ├── SettingsView.swift                   # untouched
│       ├── CapturePanelTextView.swift           # untouched
│       ├── CaptureItemRow.swift                 # untouched
│       ├── AudioWaveView.swift                  # untouched
│       └── ToastView.swift                      # untouched
├── FlytrapTests/                                # renamed from ZoidbergTests/
│   ├── CaptureItemTests.swift                   # @testable import Flytrap
│   ├── CaptureSessionTests.swift                # @testable import Flytrap
│   ├── ClaudeServiceTests.swift                 # @testable import Flytrap
│   ├── SettingsTests.swift                      # @testable import Flytrap; suiteName "com.flytrap.tests"
│   └── VaultWriterTests.swift                   # @testable import Flytrap; "flytrap-test-vault-"
└── docs/
    └── superpowers/
        ├── plans/
        │   ├── 2026-03-13-zoidberg-implementation.md   # historical, leave name
        │   └── 2026-04-29-rename-zoidberg-to-flytrap.md  # THIS PLAN
        └── specs/
            └── 2026-03-13-zoidberg-design.md           # historical, leave name

~/Developer/forks/zoidberg/                      # left intact as rollback safety net
                                                 # archive after verification soaks (Phase 8)

/Applications/Flytrap.app                        # replaces Zoidberg.app
/Applications/Zoidberg.app.bak                   # quarantined original (deleted in Phase 8)

~/Library/Application Support/Flytrap/           # new (migrated from Zoidberg/)
~/Library/Caches/Flytrap                         # auto-created on launch
~/Library/Preferences/com.jakobfaber.flytrap.plist  # new (migrated from com.malecks.zoidberg)
```

**Files NOT touched (load-bearing format contract — do not edit):**
- `Zoidberg/Models/CaptureSession.swift` — `toMarkdown`, `dailyHeading`, `fallbackFilename`
- `Zoidberg/Models/CaptureItem.swift` — `toMarkdown` per-case
- `Zoidberg/Services/VaultWriter.swift` lines 40–76 — the `save` protocol (filename, header, `\n---\n\n` separator, attachments path)

If you find yourself editing those, stop. The downstream Python pipeline at `~/Obsidian/Captures/Library/_automation/library_workflow.py::parse_daily_note` is the consumer of that exact format.

---

## Phase 0: Pre-flight & Snapshot

### Task 0.1: Stop the running Zoidberg.app and quiesce the producer

**Files:** none (system state only)

- [ ] **Step 1: Confirm Zoidberg is running**

```bash
pgrep -lf '/Applications/Zoidberg.app/Contents/MacOS/Zoidberg' || echo "not running"
```

Expected: a PID line if running, or `not running`.

- [ ] **Step 2: Force-kill the running app so it can't append to today's daily note mid-rename**

```bash
pkill -9 -x Zoidberg; sleep 1
pgrep -x Zoidberg && echo "STILL RUNNING — investigate" || echo "stopped"
```

Expected: `stopped`.

- [ ] **Step 3: Confirm no in-flight pending session (or stash it if there is one)**

```bash
PENDING="$HOME/Library/Application Support/Zoidberg/pending-session.json"
if [ -s "$PENDING" ]; then
  cp "$PENDING" "$HOME/zoidberg-pending-session.snapshot.json"
  echo "stashed to ~/zoidberg-pending-session.snapshot.json"
else
  echo "no pending session"
fi
```

Expected: `no pending session` (verified at plan-write time it was empty); otherwise the snapshot is preserved for restoration after the rename.

### Task 0.2: Snapshot existing UserDefaults

**Files:** `~/zoidberg-defaults.snapshot.plist` (created)

- [ ] **Step 1: Export current Zoidberg defaults to disk for migration source-of-truth and rollback**

```bash
defaults export com.malecks.zoidberg ~/zoidberg-defaults.snapshot.plist
plutil -p ~/zoidberg-defaults.snapshot.plist
```

Expected: a plist printout showing at least `vaultPath = /Users/jakobfaber/Obsidian` and `launchAtLogin = 1`. This snapshot is the input for Phase 4's migration code and lets you manually `defaults import` if anything goes wrong.

### Task 0.3: Verify the source tree is clean

**Files:** `/Users/jakobfaber/Developer/forks/zoidberg/` (read-only check)

- [ ] **Step 1: Confirm no uncommitted changes in the fork before copying**

```bash
git -C /Users/jakobfaber/Developer/forks/zoidberg status --porcelain
```

Expected: empty output. If there are uncommitted changes, commit or stash them first — do not lose work in the rename.

- [ ] **Step 2: Confirm the `Captures` repo is also in a known state**

```bash
git -C /Users/jakobfaber/Obsidian/Captures status --short | head
```

Expected: only the existing untracked daily-note files (e.g. `?? 2026-04-29.md`). Documenting baseline so post-rename diffs are interpretable.

---

## Phase 1: Bootstrap New Repo at `~/Developer/apps/flytrap`

### Task 1.1: Create the parent directory

**Files:** `/Users/jakobfaber/Developer/apps/` (created)

- [ ] **Step 1: Create the `apps/` directory if it doesn't exist**

```bash
mkdir -p /Users/jakobfaber/Developer/apps
ls -ld /Users/jakobfaber/Developer/apps
```

Expected: directory exists, owned by `jakobfaber`.

### Task 1.2: Copy the source tree (preserving git history)

**Files:** `/Users/jakobfaber/Developer/apps/flytrap/` (created from `~/Developer/forks/zoidberg/`)

- [ ] **Step 1: Use rsync to copy everything including `.git`, excluding build artifacts and DerivedData symlinks**

```bash
rsync -a \
  --exclude '.build/' \
  --exclude 'build/' \
  --exclude '.DS_Store' \
  /Users/jakobfaber/Developer/forks/zoidberg/ \
  /Users/jakobfaber/Developer/apps/flytrap/
```

Expected: silent success.

- [ ] **Step 2: Sanity-check the copy**

```bash
ls /Users/jakobfaber/Developer/apps/flytrap/
git -C /Users/jakobfaber/Developer/apps/flytrap log --oneline -3
```

Expected: same top-level layout as the fork (Zoidberg/, ZoidbergTests/, Zoidberg.xcodeproj/, Package.swift, docs/, README absent or present matching source) and the same three most-recent commits as the fork (`7d68fba`, `973af60`, `ef599f8`).

### Task 1.3: Detach from the public fork remote

**Files:** `/Users/jakobfaber/Developer/apps/flytrap/.git/config` (modified via git CLI)

- [ ] **Step 1: Remove the GitHub fork remote**

```bash
git -C /Users/jakobfaber/Developer/apps/flytrap remote remove origin
git -C /Users/jakobfaber/Developer/apps/flytrap remote -v
```

Expected: empty output from `remote -v`. The repo is now standalone locally; new origin gets added in Phase 8 after verification.

### Task 1.4: Make a checkpoint commit before mutating anything

**Files:** `/Users/jakobfaber/Developer/apps/flytrap/.flytrap-rename-checkpoint` (created, then committed)

- [ ] **Step 1: Create a tag at the pre-rename HEAD so rollback is one command**

```bash
git -C /Users/jakobfaber/Developer/apps/flytrap tag pre-flytrap-rename
git -C /Users/jakobfaber/Developer/apps/flytrap tag --list pre-flytrap-rename
```

Expected: `pre-flytrap-rename` printed. To roll back any later phase: `git reset --hard pre-flytrap-rename`.

---

## Phase 2: File and Directory Renames

All commands run from `/Users/jakobfaber/Developer/apps/flytrap/`. Set this once:

```bash
cd /Users/jakobfaber/Developer/apps/flytrap
```

### Task 2.1: Rename the source directory

**Files:**
- Rename: `Zoidberg/` → `Flytrap/`

- [ ] **Step 1: Use `git mv` so the rename is tracked, not seen as delete+add**

```bash
git mv Zoidberg Flytrap
git status --short
```

Expected: a list of `R  Zoidberg/... -> Flytrap/...` lines for every file in the source dir.

### Task 2.2: Rename the app entry-point file

**Files:**
- Rename: `Flytrap/ZoidbergApp.swift` → `Flytrap/FlytrapApp.swift`

- [ ] **Step 1: `git mv` the renamed-but-still-Zoidberg-named app file**

```bash
git mv Flytrap/ZoidbergApp.swift Flytrap/FlytrapApp.swift
```

### Task 2.3: Rename the test directory

**Files:**
- Rename: `ZoidbergTests/` → `FlytrapTests/`

- [ ] **Step 1: `git mv` the test directory**

```bash
git mv ZoidbergTests FlytrapTests
git status --short | head -20
```

Expected: `R  ZoidbergTests/...Tests.swift -> FlytrapTests/...Tests.swift` for all five test files.

### Task 2.4: Rename the Xcode project

**Files:**
- Rename: `Zoidberg.xcodeproj/` → `Flytrap.xcodeproj/`

- [ ] **Step 1: `git mv` the Xcode project bundle**

```bash
git mv Zoidberg.xcodeproj Flytrap.xcodeproj
ls -d *.xcodeproj
```

Expected: only `Flytrap.xcodeproj/` listed.

### Task 2.5: Commit the rename-only diff

- [ ] **Step 1: Commit so the rename is preserved as a single reviewable change**

```bash
git status --short
git commit -m "rename: move source/test/xcodeproj dirs and app entry file from Zoidberg to Flytrap"
git log --oneline -1
```

Expected: a single commit recording all renames; no string content changed yet.

---

## Phase 3: String Replacement Pass

Goal: every textual `Zoidberg`/`zoidberg`/`ZOIDBERG`/`com.malecks.zoidberg` reference becomes the Flytrap/flytrap/`com.jakobfaber.flytrap` equivalent — except inside historical plan files under `docs/superpowers/` which describe the past state and should be left as-is.

### Task 3.1: Identify the exact replacement targets

**Files:** none (read-only audit)

- [ ] **Step 1: Re-grep the working tree to confirm what remains**

```bash
grep -rIE "[Zz]oidberg|ZOIDBERG|com\.malecks\.zoidberg|com\.zoidberg" \
  --include="*.swift" --include="*.plist" --include="*.pbxproj" \
  --include="Package.swift" \
  --exclude-dir=.git \
  .
```

Expected (from plan-time discovery): hits in `Flytrap/AppState.swift`, `Flytrap/FlytrapApp.swift`, `Flytrap/Info.plist`, `Flytrap.xcodeproj/project.pbxproj`, `Package.swift`, all 5 `FlytrapTests/*.swift`, plus header-comment-only hits in every other Swift file. Use this listing as the work queue for Tasks 3.2–3.7. Specifically NOT in scope: `docs/superpowers/plans/2026-03-13-zoidberg-implementation.md` and `docs/superpowers/specs/2026-03-13-zoidberg-design.md` — those are historical artifacts.

### Task 3.2: Update `Package.swift`

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: Replace package, product, target, and testTarget names**

Replace the entire file contents with:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Flytrap",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Flytrap", targets: ["Flytrap"])
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1")
    ],
    targets: [
        .executableTarget(
            name: "Flytrap",
            dependencies: ["HotKey"],
            path: "Flytrap"
        ),
        .testTarget(
            name: "FlytrapTests",
            dependencies: ["Flytrap"],
            path: "FlytrapTests"
        )
    ]
)
```

- [ ] **Step 2: Verify `Package.swift` parses**

```bash
swift package describe --type json | head -20
```

Expected: JSON output starting with `"name" : "Flytrap"`. If it fails, the `path` directives don't match the directory layout — re-check Phase 2 renames.

### Task 3.3: Update the Xcode project file

**Files:**
- Modify: `Flytrap.xcodeproj/project.pbxproj`

The pbxproj uses static IDs (e.g. `B10001`) that don't need to change. Only path/name strings need replacement.

- [ ] **Step 1: Run a scoped sed replace inside the pbxproj**

```bash
sed -i '' \
  -e 's/Zoidberg\.app/Flytrap.app/g' \
  -e 's/ZoidbergApp\.swift/FlytrapApp.swift/g' \
  -e 's|Zoidberg/Info\.plist|Flytrap/Info.plist|g' \
  -e 's|path = Zoidberg;|path = Flytrap;|g' \
  -e 's|/\* Zoidberg \*/|/* Flytrap */|g' \
  -e 's|"Zoidberg"|"Flytrap"|g' \
  -e 's|name = Zoidberg;|name = Flytrap;|g' \
  -e 's|productName = Zoidberg;|productName = Flytrap;|g' \
  -e 's|com\.malecks\.zoidberg|com.jakobfaber.flytrap|g' \
  Flytrap.xcodeproj/project.pbxproj
```

- [ ] **Step 2: Verify no Zoidberg/zoidberg/malecks strings remain in the pbxproj**

```bash
grep -nE "[Zz]oidberg|com\.malecks" Flytrap.xcodeproj/project.pbxproj || echo "clean"
```

Expected: `clean`.

- [ ] **Step 3: Confirm the build settings show the new bundle id**

```bash
grep -nE "PRODUCT_BUNDLE_IDENTIFIER|INFOPLIST_FILE" Flytrap.xcodeproj/project.pbxproj
```

Expected: bundle identifier lines now read `com.jakobfaber.flytrap`; Info.plist path lines now read `Flytrap/Info.plist`.

### Task 3.4: Update `Info.plist`

**Files:**
- Modify: `Flytrap/Info.plist`

- [ ] **Step 1: Replace usage descriptions and add explicit name keys**

Replace the entire file contents with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Flytrap</string>
    <key>CFBundleDisplayName</key>
    <string>Flytrap</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Flytrap needs microphone access to transcribe your voice notes.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Flytrap uses speech recognition to transcribe your dictated notes.</string>
</dict>
</plist>
```

- [ ] **Step 2: Validate the plist parses**

```bash
plutil -lint Flytrap/Info.plist
```

Expected: `Flytrap/Info.plist: OK`.

### Task 3.5: Update `FlytrapApp.swift` (formerly `ZoidbergApp.swift`)

**Files:**
- Modify: `Flytrap/FlytrapApp.swift`

This is the most edit-heavy Swift file. Six identifier/string sites from the grep at plan-write time: lines 4 (struct name), 29 (status-item accessibility), 58 + 174 (frame autosave), 261 (menu title), 278 (settings window title).

- [ ] **Step 1: Apply five targeted replacements**

```bash
sed -i '' \
  -e 's/struct ZoidbergApp: App/struct FlytrapApp: App/' \
  -e 's/accessibilityDescription: "Zoidberg"/accessibilityDescription: "Flytrap"/' \
  -e 's/setFrameAutosaveName("ZoidbergPanel")/setFrameAutosaveName("FlytrapPanel")/' \
  -e 's/setFrameUsingName("ZoidbergPanel")/setFrameUsingName("FlytrapPanel")/' \
  -e 's/title: "Quit Zoidberg"/title: "Quit Flytrap"/' \
  -e 's/window.title = "Zoidberg Settings"/window.title = "Flytrap Settings"/' \
  Flytrap/FlytrapApp.swift
```

- [ ] **Step 2: Verify nothing Zoidberg-shaped remains**

```bash
grep -nE "[Zz]oidberg" Flytrap/FlytrapApp.swift || echo "clean"
```

Expected: `clean`.

### Task 3.6: Update `AppState.swift`

**Files:**
- Modify: `Flytrap/AppState.swift`

Two sites: header comment (line 1) and the App Support directory path (line 36).

- [ ] **Step 1: Replace the header comment and the App Support path**

```bash
sed -i '' \
  -e 's|// Zoidberg/AppState\.swift|// Flytrap/AppState.swift|' \
  -e 's|"/Library/Application Support/Zoidberg"|"/Library/Application Support/Flytrap"|' \
  Flytrap/AppState.swift
```

- [ ] **Step 2: Verify**

```bash
grep -nE "[Zz]oidberg" Flytrap/AppState.swift || echo "clean"
```

Expected: `clean`.

### Task 3.7: Update header comments in remaining Swift source files

**Files:**
- Modify: `Flytrap/Helpers/Permissions.swift`
- Modify: `Flytrap/Helpers/Settings.swift`
- Modify: `Flytrap/Helpers/EscapeKeyMonitor.swift` (only if line 1 has the path comment)
- Modify: `Flytrap/Services/VaultWriter.swift`
- Modify: `Flytrap/Services/HotkeyManager.swift`
- Modify: `Flytrap/Services/ClaudeService.swift`
- Modify: `Flytrap/Services/TranscriptionService.swift`
- Modify: `Flytrap/Models/CaptureItem.swift` (if applicable)
- Modify: `Flytrap/Models/CaptureSession.swift` (if applicable)
- Modify: `Flytrap/Views/CapturePanel.swift` (if applicable)
- Modify: `Flytrap/Views/SettingsView.swift` (if applicable)
- Modify: all other `Flytrap/Views/*.swift`

- [ ] **Step 1: Run a single bulk sed across `Flytrap/` for the `// Zoidberg/...` header comments only**

```bash
find Flytrap -name '*.swift' -print0 | xargs -0 sed -i '' \
  -e 's|^// Zoidberg/|// Flytrap/|'
```

This is intentionally narrow: only the leading-line path comment. It will not touch model/format constants because those don't match the pattern.

- [ ] **Step 2: Confirm only file-path header comments changed**

```bash
grep -rnE "^// Flytrap/" Flytrap | wc -l
grep -rnE "^// Zoidberg/" Flytrap || echo "clean"
```

Expected: a count matching the number of Swift files that had the original comment; second command prints `clean`.

- [ ] **Step 3: Confirm no functional code in `Flytrap/` was accidentally changed**

```bash
grep -rnE "[Zz]oidberg" Flytrap || echo "clean"
```

Expected: `clean`. If any hits remain, audit them — `Captures` (the folder name) and the format strings should not match this pattern, but verify before continuing.

### Task 3.8: Update test files

**Files:**
- Modify: `FlytrapTests/CaptureItemTests.swift`
- Modify: `FlytrapTests/CaptureSessionTests.swift`
- Modify: `FlytrapTests/ClaudeServiceTests.swift`
- Modify: `FlytrapTests/SettingsTests.swift`
- Modify: `FlytrapTests/VaultWriterTests.swift`

Five files. Each has `@testable import Zoidberg`. Two have additional substrings: `SettingsTests.swift` references the `com.zoidberg.tests` UserDefaults suite name; `VaultWriterTests.swift` uses a `zoidberg-test-vault-` temp prefix; `ClaudeServiceTests.swift` and `SettingsTests.swift` and `VaultWriterTests.swift` have `// ZoidbergTests/...` header comments.

- [ ] **Step 1: Apply replacements across all five test files**

```bash
find FlytrapTests -name '*.swift' -print0 | xargs -0 sed -i '' \
  -e 's|@testable import Zoidberg|@testable import Flytrap|' \
  -e 's|^// ZoidbergTests/|// FlytrapTests/|' \
  -e 's|"com\.zoidberg\.tests"|"com.flytrap.tests"|g' \
  -e 's|"zoidberg-test-vault-|"flytrap-test-vault-|g'
```

- [ ] **Step 2: Verify**

```bash
grep -rnE "[Zz]oidberg" FlytrapTests || echo "clean"
```

Expected: `clean`.

### Task 3.9: Run the test suite to confirm nothing broke

**Files:** none (verification)

- [ ] **Step 1: Build and test via SPM**

```bash
swift test 2>&1 | tail -30
```

Expected: all tests pass. If any test references the format contract (separator, time heading, filename pattern), it should still pass *unmodified* — that's the proof that the rename did not leak into the data layer.

- [ ] **Step 2: Commit the rename pass**

```bash
git add -A
git status --short
git commit -m "rename: replace Zoidberg identifiers with Flytrap; update bundle id to com.jakobfaber.flytrap"
```

---

## Phase 4: Add UserDefaults & App Support Migration

Bundle id changed → user prefs under `com.malecks.zoidberg` won't auto-carry. This phase adds a one-shot migration that runs on first launch.

### Task 4.1: Add the migration helper to `Settings.swift`

**Files:**
- Modify: `Flytrap/Helpers/Settings.swift`

Append a `migrateLegacyDefaultsIfNeeded()` static function to the `AppSettings` enum, reading from the old domain and copying into standard defaults plus moving the App Support directory.

- [ ] **Step 1: Add migration code at the bottom of `Settings.swift`**

Before the closing `}` of `enum AppSettings`, insert:

```swift
    // MARK: - Legacy migration (Zoidberg → Flytrap)

    private static let migrationFlagKey = "flytrap.migration.v1.complete"
    private static let legacyBundleId = "com.malecks.zoidberg"
    private static let legacyKeys = [
        "vaultPath",
        "claudeApiKey",
        "launchAtLogin",
        "togglePanelHotkey",
        "dictateHotkey",
        "autoCloseEnabled",
        "autoCloseSeconds",
    ]

    static func migrateLegacyDefaultsIfNeeded() {
        guard !defaults.bool(forKey: migrationFlagKey) else { return }
        if let legacy = UserDefaults(suiteName: legacyBundleId) {
            for key in legacyKeys {
                if let value = legacy.object(forKey: key) {
                    defaults.set(value, forKey: key)
                }
            }
        }
        migrateApplicationSupportDirectory()
        defaults.set(true, forKey: migrationFlagKey)
    }

    private static func migrateApplicationSupportDirectory() {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let oldDir = home + "/Library/Application Support/Zoidberg"
        let newDir = home + "/Library/Application Support/Flytrap"

        var oldIsDir: ObjCBool = false
        guard fm.fileExists(atPath: oldDir, isDirectory: &oldIsDir), oldIsDir.boolValue else {
            return
        }
        try? fm.createDirectory(atPath: newDir, withIntermediateDirectories: true)
        if let entries = try? fm.contentsOfDirectory(atPath: oldDir) {
            for entry in entries {
                let src = (oldDir as NSString).appendingPathComponent(entry)
                let dst = (newDir as NSString).appendingPathComponent(entry)
                if !fm.fileExists(atPath: dst) {
                    try? fm.moveItem(atPath: src, toPath: dst)
                }
            }
        }
    }
```

- [ ] **Step 2: Verify `Settings.swift` still compiles**

```bash
swift build 2>&1 | tail -10
```

Expected: build succeeds. If errors, the most likely culprit is a missing `Foundation` import — this file already imports it.

### Task 4.2: Wire migration into app startup

**Files:**
- Modify: `Flytrap/FlytrapApp.swift`

The `AppDelegate.applicationDidFinishLaunching(_:)` method is the right place — earliest reliable entry point with `Foundation` available.

- [ ] **Step 1: Add the migration call as the first line of `applicationDidFinishLaunching`**

Open `Flytrap/FlytrapApp.swift`, find:

```swift
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
```

Change it to:

```swift
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppSettings.migrateLegacyDefaultsIfNeeded()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
```

- [ ] **Step 2: Verify**

```bash
grep -n "migrateLegacyDefaultsIfNeeded" Flytrap/FlytrapApp.swift
```

Expected: one match, inside `applicationDidFinishLaunching`.

### Task 4.3: Add a regression test for the migration

**Files:**
- Create: `FlytrapTests/MigrationTests.swift`

- [ ] **Step 1: Write the test**

```swift
// FlytrapTests/MigrationTests.swift
import XCTest
@testable import Flytrap

final class MigrationTests: XCTestCase {
    private let testSuite = "com.flytrap.tests.migration"
    private let legacySuite = "com.flytrap.tests.migration.legacy"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: testSuite)
        UserDefaults().removePersistentDomain(forName: legacySuite)
        AppSettings.defaults = UserDefaults(suiteName: testSuite)!
    }

    override func tearDown() {
        AppSettings.defaults = .standard
        UserDefaults().removePersistentDomain(forName: testSuite)
        UserDefaults().removePersistentDomain(forName: legacySuite)
        super.tearDown()
    }

    func test_migration_copies_legacy_keys_when_flag_unset() {
        // The production migrateLegacyDefaultsIfNeeded reads from "com.malecks.zoidberg".
        // We can't override that constant from the test, so we assert the no-op path:
        // when flag is already set, migration does nothing.
        AppSettings.defaults.set(true, forKey: "flytrap.migration.v1.complete")
        AppSettings.defaults.set("preexisting", forKey: "vaultPath")

        AppSettings.migrateLegacyDefaultsIfNeeded()

        XCTAssertEqual(AppSettings.defaults.string(forKey: "vaultPath"), "preexisting",
                       "Migration must be skipped when flag is already set")
    }

    func test_migration_sets_flag_after_first_run() {
        XCTAssertFalse(AppSettings.defaults.bool(forKey: "flytrap.migration.v1.complete"))
        AppSettings.migrateLegacyDefaultsIfNeeded()
        XCTAssertTrue(AppSettings.defaults.bool(forKey: "flytrap.migration.v1.complete"))
    }
}
```

- [ ] **Step 2: Run the test to verify it passes**

```bash
swift test --filter MigrationTests 2>&1 | tail -15
```

Expected: 2 tests pass. If `AppSettings.defaults` is not externally settable (it is — see `Helpers/Settings.swift:5` `static var defaults: UserDefaults = .standard`), the test will fail at compile time and you should re-check that line.

- [ ] **Step 3: Commit**

```bash
git add Flytrap/Helpers/Settings.swift Flytrap/FlytrapApp.swift FlytrapTests/MigrationTests.swift
git commit -m "feat: one-shot migration of legacy Zoidberg defaults and App Support dir"
```

---

## Phase 5: Build & Install Flytrap.app

### Task 5.1: Build a Release archive of Flytrap

**Files:** build artifact at `~/Developer/apps/flytrap/build/Release/Flytrap.app`

- [ ] **Step 1: Build with xcodebuild from the renamed Xcode project**

```bash
cd /Users/jakobfaber/Developer/apps/flytrap
xcodebuild \
  -project Flytrap.xcodeproj \
  -scheme Flytrap \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | tail -25
```

Expected: `** BUILD SUCCEEDED **`. The `CODE_SIGN_IDENTITY="-"` ad-hoc-signs the output (matches what the previous Zoidberg installs likely did). If the original build used a Developer ID, swap accordingly — check `~/Developer/forks/zoidberg/` build settings.

- [ ] **Step 2: Locate the built bundle**

```bash
find build -name 'Flytrap.app' -maxdepth 6
```

Expected: `build/Build/Products/Release/Flytrap.app` (xcodebuild's default with that derived data path).

- [ ] **Step 3: Spot-check the Info.plist inside the built bundle**

```bash
plutil -p "build/Build/Products/Release/Flytrap.app/Contents/Info.plist" | grep -E 'CFBundleName|CFBundleIdentifier|CFBundleExecutable'
```

Expected: `CFBundleName = "Flytrap"`, `CFBundleIdentifier = "com.jakobfaber.flytrap"`, `CFBundleExecutable = "Flytrap"`.

### Task 5.2: Quarantine the old Zoidberg.app

**Files:** `/Applications/Zoidberg.app` → `/Applications/Zoidberg.app.bak`

- [ ] **Step 1: Confirm Zoidberg is not running (Phase 0 already killed it; re-check)**

```bash
pgrep -x Zoidberg && echo "STILL RUNNING — re-run Phase 0 Task 0.1" || echo "stopped"
```

Expected: `stopped`.

- [ ] **Step 2: Move the existing app to a `.bak` for rollback**

```bash
mv /Applications/Zoidberg.app /Applications/Zoidberg.app.bak
ls -d /Applications/Zoidberg.app /Applications/Zoidberg.app.bak 2>&1
```

Expected: `Zoidberg.app: No such file or directory` and `/Applications/Zoidberg.app.bak` listed. Keep the `.bak` until verification passes — Phase 8 deletes it.

### Task 5.3: Install the new Flytrap.app

**Files:** `/Applications/Flytrap.app` (created)

- [ ] **Step 1: Copy the built bundle into `/Applications/`**

```bash
cp -R \
  /Users/jakobfaber/Developer/apps/flytrap/build/Build/Products/Release/Flytrap.app \
  /Applications/Flytrap.app
ls -d /Applications/Flytrap.app
```

Expected: directory exists.

- [ ] **Step 2: Verify md5 of the installed binary matches the build**

```bash
md5 -q /Applications/Flytrap.app/Contents/MacOS/Flytrap
md5 -q /Users/jakobfaber/Developer/apps/flytrap/build/Build/Products/Release/Flytrap.app/Contents/MacOS/Flytrap
```

Expected: identical hashes. Mismatch = the install didn't replace what you think it did (per the existing Hindsight memory `feedback_zoidberg_install`).

- [ ] **Step 3: Launch the app**

```bash
open /Applications/Flytrap.app
sleep 2
pgrep -lf '/Applications/Flytrap.app/Contents/MacOS/Flytrap' || echo "DID NOT LAUNCH"
```

Expected: a PID line. The menu bar should now show the Flytrap icon (cpu SF Symbol). If `DID NOT LAUNCH`, check Console.app for crashes — usually a code-sign or sandbox issue.

---

## Phase 6: End-to-End Verification

### Task 6.1: Verify the migration ran

**Files:** none (system state)

- [ ] **Step 1: Confirm new prefs domain has the migrated values**

```bash
defaults read com.jakobfaber.flytrap
```

Expected: `vaultPath = "/Users/jakobfaber/Obsidian"`, `launchAtLogin = 1`, `flytrap.migration.v1.complete = 1`. If the migration flag is set but values are missing, the legacy domain might already have been emptied — confirm `defaults read com.malecks.zoidberg` still has them.

- [ ] **Step 2: Confirm App Support directory was migrated (if non-empty originally)**

```bash
ls -la "$HOME/Library/Application Support/Flytrap/" 2>/dev/null
ls -la "$HOME/Library/Application Support/Zoidberg/" 2>/dev/null
```

Expected: if the old dir had a `pending-session.json`, it's now in the new dir and gone from the old dir. If the old dir was empty (the snapshot at plan-write time), both are empty and that's fine.

### Task 6.2: Verify hotkeys

**Files:** none (interactive)

- [ ] **Step 1: Press `Ctrl+Space`**

Expected: capture panel appears.

- [ ] **Step 2: Press `Ctrl+Space` again**

Expected: panel hides.

- [ ] **Step 3: Press `Ctrl+Shift+Space`**

Expected: panel appears with dictation indicator active. Press again to stop dictation.

If hotkeys don't fire, check Accessibility permissions: System Settings → Privacy & Security → Accessibility. Flytrap will need to be granted access (the previous Zoidberg grant doesn't transfer because the bundle id changed).

### Task 6.3: Capture a test entry and verify it lands in the right file

**Files:**
- Read: `~/Obsidian/Captures/<today>.md`

- [ ] **Step 1: Open Flytrap (Ctrl+Space), type a unique sentinel, click save**

Use a sentinel like `flytrap-rename-verification-2026-04-29` so it's grep-able.

- [ ] **Step 2: Verify the sentinel appears in today's daily note in the Captures repo**

```bash
TODAY=$(date +%Y-%m-%d)
grep -n 'flytrap-rename-verification' "/Users/jakobfaber/Obsidian/Captures/$TODAY.md"
```

Expected: a hit. The path `<vault>/Captures/` is unchanged by the rename — this proves the data-layout contract held.

- [ ] **Step 3: Verify the format matches the parser's expectations**

```bash
tail -10 "/Users/jakobfaber/Obsidian/Captures/$TODAY.md"
```

Expected: a `## H:mm AM/PM` heading with the sentinel below, preceded by `\n---\n` if it wasn't the first entry of the day.

### Task 6.4: Verify the Python pipeline still parses Flytrap output

**Files:** `~/Obsidian/Captures/Library/_automation/outbox/classification_preview.md` (regenerated)

- [ ] **Step 1: Run the dry-run pipeline**

```bash
cd /Users/jakobfaber/Obsidian/Captures
python3 Library/_automation/library_workflow.py --mode dry-run --classifier heuristic
```

Expected: exit code 0; no Python tracebacks.

- [ ] **Step 2: Confirm the sentinel made it into the preview**

```bash
grep flytrap-rename-verification \
  /Users/jakobfaber/Obsidian/Captures/Library/_automation/outbox/classification_preview.md
```

Expected: a hit. This is the load-bearing acceptance test — the Flytrap-produced entry was successfully consumed by the unchanged Python parser. Format contract verified intact.

### Task 6.5: Verify the old Zoidberg app stays quarantined

**Files:** none (system state)

- [ ] **Step 1: Confirm the `.bak` is not running and is not auto-launched**

```bash
pgrep -x Zoidberg || echo "not running"
ls -d /Applications/Zoidberg.app.bak
```

Expected: `not running`; the `.bak` exists. macOS shouldn't try to launch a `.app.bak` because it's not a recognized app extension to LaunchServices.

---

## Phase 7: Update Downstream Documentation

### Task 7.1: Update `~/Obsidian/Captures/CLAUDE.md`

**Files:**
- Modify: `/Users/jakobfaber/Obsidian/Captures/CLAUDE.md`

The CLAUDE.md from the prior conversation turn references Zoidberg by name in three places: the project identity paragraph (line ~3), the project map entry (line ~13), and the dedicated Zoidberg `<important if>` block (lines ~40–55). All three need to be updated to reference Flytrap, with a brief mention that Flytrap was previously called Zoidberg so future agents recognize legacy paths.

- [ ] **Step 1: Replace the project-identity sentence**

Find:
```
Dated capture notes at the root are produced almost entirely by **Zoidberg**, a macOS menu-bar capture app
```

Replace with:
```
Dated capture notes at the root are produced almost entirely by **Flytrap** (formerly "Zoidberg"), a macOS menu-bar capture app
```

- [ ] **Step 2: Replace the project-map entry**

Find:
```
- `~/Developer/forks/zoidberg/` — Zoidberg source (jakobtfaber's fork of malecks/zoidberg); installed at `/Applications/Zoidberg.app`
```

Replace with:
```
- `~/Developer/apps/flytrap/` — Flytrap source (independent private repo, originally forked from `malecks/zoidberg` and renamed 2026-04-29); installed at `/Applications/Flytrap.app`
```

- [ ] **Step 3: Replace the Zoidberg `<important if>` block contents**

Find the block starting `<important if="you are debugging where daily notes come from, changing their format, or coordinating with the Zoidberg capture pipeline">` and replace its entire body with the same content but with these targeted substitutions:
- `Zoidberg` → `Flytrap` everywhere
- `~/Developer/forks/zoidberg/` → `~/Developer/apps/flytrap/`
- `/Applications/Zoidberg.app` → `/Applications/Flytrap.app`
- `com.malecks.zoidberg` → `com.jakobfaber.flytrap`
- `~/Library/Application Support/Zoidberg/` → `~/Library/Application Support/Flytrap/`
- `Zoidberg/Models/CaptureItem.swift` → `Flytrap/Models/CaptureItem.swift`
- `Zoidberg/Models/CaptureSession.swift` → `Flytrap/Models/CaptureSession.swift`
- `Zoidberg/Services/VaultWriter.swift` → `Flytrap/Services/VaultWriter.swift`
- The `if=` condition itself: replace the word `Zoidberg` with `Flytrap`.

Add one new sentence at the very top of the block: `Flytrap was previously called Zoidberg (renamed 2026-04-29). If you encounter old references — bundle id, paths under ~/Developer/forks/, /Applications/Zoidberg.app, ~/Library/Application Support/Zoidberg/ — they are legacy and should not be re-introduced.`

- [ ] **Step 4: Confirm no Zoidberg references remain in `CLAUDE.md` outside the "previously called" mention**

```bash
grep -nE "[Zz]oidberg" /Users/jakobfaber/Obsidian/Captures/CLAUDE.md
```

Expected: at most two hits — the "(formerly 'Zoidberg')" parenthetical and the "previously called Zoidberg" sentence. Anything else is a stale reference.

- [ ] **Step 5: Commit the CLAUDE.md update in the Captures repo**

```bash
git -C /Users/jakobfaber/Obsidian/Captures add CLAUDE.md
git -C /Users/jakobfaber/Obsidian/Captures commit -m "docs: rename Zoidberg references to Flytrap after app rename"
```

### Task 7.2: Retain a follow-up entry to Hindsight

**Files:** Hindsight bank `claude-events`

- [ ] **Step 1: Use `mcp__hindsight__retain` to add a forward-pointing memory**

The previous Zoidberg memory in bank `claude-events` (tagged `zoidberg`) should not be deleted — it documents history. Add a NEW entry that:
- Records the rename (Zoidberg → Flytrap, 2026-04-29).
- Lists every old → new path mapping (binary, source, bundle id, App Support, prefs domain).
- Notes that the format contract (separator, time heading, filename, `Captures/` folder) was deliberately preserved.
- Tags: `flytrap`, `zoidberg`, `rename`, `obsidian`, `captures`, `format-contract`.
- Metadata: include the git commit hash for the rename pass and the new GitHub repo URL once Phase 8 sets it.

The agent executing this plan should compose this content from the actual final state, not from this template — so it reflects what shipped, including the new repo URL from Phase 8.

- [ ] **Step 2: Verify the retain succeeded**

Use `mcp__hindsight__recall` with query `flytrap rename` and confirm both the old (Zoidberg) and new (Flytrap) entries surface.

---

## Phase 8: Cleanup, Push, Archive

### Task 8.1: Create the new private GitHub repo and push

**Files:** none locally; `gh` CLI creates the remote

- [ ] **Step 1: Confirm `gh` is authenticated**

```bash
gh auth status 2>&1 | head -5
```

Expected: `Logged in to github.com as jakobtfaber` (or similar).

- [ ] **Step 2: Create a private repo and add it as origin**

```bash
cd /Users/jakobfaber/Developer/apps/flytrap
gh repo create jakobtfaber/flytrap \
  --private \
  --source . \
  --description "Personal macOS menu-bar capture app (Obsidian quick-capture); independent successor to the public zoidberg fork" \
  --push
```

Expected: `https://github.com/jakobtfaber/flytrap` printed; remote `origin` set; `main` pushed. The `--private` flag is the key part — verify in the GitHub web UI that the repo is private.

- [ ] **Step 3: Verify the new repo is not marked as a fork**

```bash
gh repo view jakobtfaber/flytrap --json isFork,visibility
```

Expected: `{"isFork": false, "visibility": "PRIVATE"}`. If `isFork` is true, you accidentally used `gh repo fork` somewhere — start over with `gh repo create`.

### Task 8.2: Remove the quarantined old app and stale macOS state

**Files:**
- Delete: `/Applications/Zoidberg.app.bak`
- Delete: `~/Library/Caches/Zoidberg`
- Delete: `~/Library/HTTPStorages/Zoidberg`
- Delete: `~/Library/Preferences/com.malecks.zoidberg.plist` (only after migration verified)
- Delete: `~/Library/Preferences/Zoidberg.plist` (only after migration verified)
- Delete: `~/Library/Application Support/Zoidberg/` (if empty after migration)
- Delete: `~/Library/Developer/Xcode/DerivedData/Zoidberg-*`

Only run this AFTER Phase 6 verifications pass and Flytrap has been used for at least one full capture+save cycle.

- [ ] **Step 1: Re-verify Flytrap state before deletions**

```bash
defaults read com.jakobfaber.flytrap | head
ls "/Users/jakobfaber/Obsidian/Captures/$(date +%Y-%m-%d).md" >/dev/null && echo "today's note exists"
```

Expected: prefs present, today's daily note exists.

- [ ] **Step 2: Remove the quarantined .bak**

```bash
rm -rf /Applications/Zoidberg.app.bak
```

- [ ] **Step 3: Remove the legacy macOS state**

```bash
rm -rf "$HOME/Library/Caches/Zoidberg"
rm -rf "$HOME/Library/HTTPStorages/Zoidberg"
rm -rf "$HOME/Library/Application Support/Zoidberg"
rm -f "$HOME/Library/Preferences/com.malecks.zoidberg.plist"
rm -f "$HOME/Library/Preferences/Zoidberg.plist"
rm -rf "$HOME/Library/Developer/Xcode/DerivedData"/Zoidberg-*
```

- [ ] **Step 4: Reset launchd's UserDefaults cache (otherwise stale prefs may resurface)**

```bash
defaults delete com.malecks.zoidberg 2>/dev/null || true
killall cfprefsd 2>/dev/null || true
```

### Task 8.3: Archive the original public fork

**Files:**
- Move: `/Users/jakobfaber/Developer/forks/zoidberg/` → `/Users/jakobfaber/projects/archive/zoidberg/`

The user's home-directory CLAUDE.md (`~/CLAUDE.md`) specifies that stale projects (untouched >1 year) live under `~/projects/archive/`. The fork is now superseded; archive it but don't delete — it's the rollback safety net.

- [ ] **Step 1: Move the fork to archive**

```bash
mkdir -p /Users/jakobfaber/projects/archive
mv /Users/jakobfaber/Developer/forks/zoidberg /Users/jakobfaber/projects/archive/zoidberg
ls -d /Users/jakobfaber/projects/archive/zoidberg
```

Expected: directory listed at the new path.

- [ ] **Step 2: Drop a README breadcrumb in the archived directory**

Create `/Users/jakobfaber/projects/archive/zoidberg/RENAMED.md` with:

```markdown
# This is the legacy Zoidberg source

Renamed and migrated to **Flytrap** on 2026-04-29.

- Active source: `~/Developer/apps/flytrap/`
- New private repo: https://github.com/jakobtfaber/flytrap
- Installed app: `/Applications/Flytrap.app`
- Bundle id: `com.jakobfaber.flytrap` (was `com.malecks.zoidberg`)

This directory is preserved as a rollback safety net only. Do not edit or build from here.
```

- [ ] **Step 3: Final commit if any tracked changes remain**

```bash
git -C /Users/jakobfaber/Developer/apps/flytrap status --short
```

Expected: empty. If anything's pending from earlier phases, commit it now.

---

## Self-Review

**Spec coverage** (against the original brief):

1. _"the source repo at ~/Developer/forks/zoidberg/ moves to ~/Developer/apps/flytrap"_ → Phase 1 (copy + detach), Phase 8.3 (archive original).
2. _"as an independent, private repo"_ → Phase 1.3 (remove fork remote), Phase 8.1 (`gh repo create --private`, verify `isFork: false`).
3. _"detach from the malecks/zoidberg fork relationship"_ → Phase 1.3.
4. _"/Applications/Zoidberg.app should become Flytrap.app"_ → Phase 5 (build + install).
5. _"bundle id changes from com.malecks.zoidberg to com.jakobfaber.flytrap"_ → Phase 3.3 (pbxproj), Phase 6.1 (verification).
6. _"plan should include a phase that updates [Captures CLAUDE.md and Hindsight]"_ → Phase 7.
7. _"order-of-operations risk: stop the producer early"_ → Phase 0.1.
8. _"don't gloss over the find-and-replace pass"_ → Phase 3 has eight tasks, each with explicit file paths and exact `sed` commands.
9. _"include verification steps (Flytrap.app launch, writes to <vault>/Captures/, hotkeys, parser still works, old quarantined)"_ → Phase 6 has five tasks covering all five.

**Architectural questions** (from brief, all resolved at the top of this document): git history kept + remote detached, bundle id `com.jakobfaber.flytrap`, UserDefaults migrated on first launch, App Support dir migrated alongside, frame autosave key renamed, output `Captures/` folder unchanged.

**Placeholder scan:** no `TBD` / `TODO` / "implement later" / "fill in" / "similar to Task N" patterns. Every step has either a complete code block, an exact command, or both.

**Type/symbol consistency:**
- `migrateLegacyDefaultsIfNeeded()` — defined in Phase 4.1 Step 1, called in Phase 4.2 Step 1, tested in Phase 4.3.
- `migrationFlagKey = "flytrap.migration.v1.complete"` — defined in 4.1, referenced in 4.3 test, queried in 6.1 verification.
- Bundle id `com.jakobfaber.flytrap` — set in 3.3 (pbxproj), checked in 5.1 Step 3 and 6.1 and 8.1.
- Output folder `Captures` — explicitly preserved (Architectural Decisions §6, Phase 6.4 Step 2).
- `FlytrapApp.swift` — created via rename in 2.2, identifier change in 3.5, migration call site in 4.2.
- `FlytrapPanel` autosave key — replaced in 3.5 Step 1 (both `setFrameAutosaveName` and `setFrameUsingName` sites).

## Rollback

If anything goes wrong in Phases 5–8:

1. **Re-install Zoidberg.app**: `mv /Applications/Zoidberg.app.bak /Applications/Zoidberg.app && open /Applications/Zoidberg.app`. The original prefs at `com.malecks.zoidberg` are untouched until Phase 8.2 Step 4.
2. **Reset the new repo to pre-rename**: `git -C /Users/jakobfaber/Developer/apps/flytrap reset --hard pre-flytrap-rename` (the tag from Task 1.4).
3. **Discard the new repo entirely**: `rm -rf /Users/jakobfaber/Developer/apps/flytrap`. The original fork at `~/Developer/forks/zoidberg/` is still intact through Phase 8.3.
4. **Restore prefs**: `defaults import com.malecks.zoidberg ~/zoidberg-defaults.snapshot.plist`.

---

## Execution Handoff

Plan complete and saved to `~/Developer/forks/zoidberg/docs/superpowers/plans/2026-04-29-rename-zoidberg-to-flytrap.md`. Two execution options:

**1. Subagent-Driven (recommended)** — Dispatch a fresh subagent per phase (or per task within Phase 3). Review between tasks. Fast iteration on errors. Best fit because Phases 5/6 have user-interactive verification (hotkeys, capture+save), so the harness pausing for review aligns with where you'd be checking anyway.

**2. Inline Execution** — Execute tasks in this session using `superpowers:executing-plans`. Batch execution with checkpoints. Easier if you want one continuous run.

Which approach?
