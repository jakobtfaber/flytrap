# Zoidberg — Mac Menu Bar Capture App

## Overview

Zoidberg is a macOS menu bar app for quick-capture note-taking that saves to an Obsidian vault. It accepts text input, voice dictation, and drag-and-drop media (images, videos, links), composing everything into a single markdown note per capture session. Claude API integration provides optional AI-powered cleanup, titling, and organization.

## Architecture

Single-process Swift + SwiftUI menu bar application. No background daemons, no Obsidian plugin dependency.

### Core Modules

- **MenuBarController** — Owns the `NSStatusItem`, manages the popover panel lifecycle. Displays a robot icon in the menu bar.
- **CapturePanel** — SwiftUI view: inline text input, dictation state indicator, drag & drop handling. Compact design (~320px wide), dark theme, content displayed as a vertical stream.
- **CaptureSession** — Model object accumulating all items (text blocks, media file references, URLs) during a session. Responsible for serializing to markdown. Persists across panel open/close until explicitly saved or discarded. Sessions are serialized to `~/Library/Application Support/Zoidberg/pending-session.json` so they survive app restarts and crashes. This file is deleted on successful save (Cmd+Enter) and on explicit discard (Escape hold).
- **TranscriptionService** — Protocol-based wrapper around macOS built-in dictation. Designed with a protocol interface so the implementation can be swapped for local Whisper in the future without changing consumers.
- **VaultWriter** — Takes a completed `CaptureSession`, copies media files to the vault's attachments folder, and writes the composed markdown note. Target vault: `~/Documents/Obsidian Vault/`. Validates vault path exists and is writable before attempting saves. On write failure (path missing, disk full, permissions), shows an error toast in the panel: "Failed to save — check vault path in settings" and keeps the session active so no data is lost.
- **ClaudeService** — Optional async layer for Claude API calls. Disabled gracefully when no API key is configured. Two modes:
  - **On capture (automatic):** Clean up dictated text (punctuation, formatting), generate note title and determine target folder.
  - **On demand (user-triggered):** Summarize, reorganize, or tag existing notes. (Future scope — not in initial build.)
- **HotkeyManager** — Registers two global keyboard shortcuts via `CGEvent` taps or a library like HotKey. Requires macOS Accessibility permission. On first launch, the app prompts for Accessibility access. If denied, hotkeys are non-functional and the app shows a setup prompt guiding the user to System Settings > Privacy > Accessibility.
- **SettingsView** — Configure vault path, Claude API key, hotkey bindings, launch at login.

### Data Flow

```
Input (text / dictation / drag-drop)
  → CapturePanel (accumulates in CaptureSession)
  → User hits Cmd+Enter (save)
  → Immediate write: VaultWriter saves to Captures/<date-stamped>.md with raw content
  → Toast shown: "✓ Saved to vault", panel closes
  → Background (if Claude enabled): ClaudeService cleans up text, generates title/folder
  → Background: VaultWriter moves/renames file to Claude-determined title and folder
  → If Claude call fails: file stays in Captures/ with date-stamped name (the fallback)
```

This "write-first, enhance-async" strategy means the UI never blocks on Claude. The user sees instant confirmation. The note is safe on disk immediately, and Claude enrichment happens in the background. If Claude is slow or fails, the raw capture is already saved.

## UI Design

### Panel Layout (Compact, ~320px wide)

- **Header:** Robot icon (left), mic button and save checkmark (right). No title text.
- **Content area:** Vertical stream of captured items — text, image thumbnails, link pills — in capture order. Text input is inline, cursor active immediately on open.
- **No footer/drop hint bar.** The entire panel is a drop target.

### Panel States

1. **Empty/Idle** — Placeholder text: "Type or dictate something, or drop a file..." Cursor active.
2. **Dictating** — Red pulsing dot + "Listening" label replace the mic icon. Text appears in real-time. Red blinking cursor at insertion point.
3. **Drag Over** — Blue border around entire panel, existing content fades slightly, dashed drop zone appears in content area.
4. **Saved** — Green toast at bottom: "✓ Saved to vault". Panel auto-closes after ~1 second.

### Interactions

| Action | Behavior |
|--------|----------|
| **Hotkey 1** (toggle panel) | Opens/closes panel. Opening starts a new session if none active. |
| **Hotkey 2** (dictate) | Opens panel if closed, toggles dictation on/off. |
| **Cmd+Enter** | Save session to vault. Shows toast, auto-closes. |
| **Escape (tap)** | Minimize panel. Session persists for next open. |
| **Escape (hold ~1.5s)** | Discard session with red flash feedback. Discarded session is kept in a single-slot "last discarded" buffer for 30 seconds. On next panel open, a subtle "Undo discard" button appears at the top of the empty panel for 30 seconds. Clicking it restores the session. This avoids overloading Cmd+Z, which remains standard text undo within the input field. |
| **Click away** | Same as Escape tap — minimize, session persists. |

## Markdown Output Format

Each capture session produces a single markdown note:

```markdown
# Auth Flow Investigation

Notes captured on 2026-03-13 at 2:34 PM

---

Need to look into the auth flow for the new onboarding. The current
implementation has a race condition when the user clicks through too
quickly.

![screenshot-auth-flow.png](attachments/screenshot-auth-flow.png)

[https://docs.example.com/auth-flow](https://docs.example.com/auth-flow)
```

- **Title:** Claude-generated from content (when enabled), or date-stamped fallback (e.g., `2026-03-13-capture.md`).
- **Folder:** Claude-determined based on content (when enabled), or flat `Captures/` folder as fallback.
- **Media:** Copied to `attachments/` subfolder relative to the note (standard Obsidian convention).
- **Order:** Items appear in the order they were captured.
- **Dictation cleanup:** When Claude is enabled, dictated text gets light processing (punctuation, paragraph breaks).
- **Unique filenames:** Fallback filenames use timestamp with seconds: `2026-03-13-143422-capture.md`. This eliminates collision windows when Claude is asynchronously renaming a previous capture.

## Claude Integration

### Design Principles

- **Pluggable:** App fully functional without an API key. AI features activate when key is provided.
- **Cost-conscious:** Use Haiku for automatic on-capture processing (cheapest), Sonnet for on-demand tasks.
- **Write-first, enhance-async:** Note is saved immediately with fallback naming. Claude processing happens in the background and updates the file in place (rename + move). UI never blocks on Claude.

### On-Capture Processing (Automatic)

When a session is saved with Claude enabled:
1. Note is written immediately to `Captures/<date-stamped>.md` with raw content.
2. In background: ClaudeService cleans up dictated text (punctuation, formatting, paragraph breaks).
3. In background: ClaudeService analyzes content to generate a descriptive title and determine target folder.
4. In background: VaultWriter writes the enhanced note to a temp file in the target folder, then performs an atomic `rename()` to the final path. The original file in `Captures/` is deleted only after the atomic move succeeds. This ensures Obsidian's file watcher never sees a partially-written file.
5. If Claude API call fails or times out (30s): note stays in `Captures/` with date-stamped name. No user disruption — the raw capture is already safe.

### On-Demand Processing (Future Scope)

Not included in initial build. Planned capabilities:
- Summarize long notes
- Reorganize and tag notes
- Cross-reference related notes in the vault

## Speech-to-Text

### Initial Implementation

macOS built-in dictation via `SFSpeechRecognizer` or the system dictation API. Free, decent quality, works offline.

**Permissions:** `SFSpeechRecognizer` requires the Speech Recognition entitlement and a runtime authorization prompt. On first use of the dictate hotkey:
1. System permission dialog appears requesting Speech Recognition access.
2. If denied: mic button shows a disabled state (greyed out, tooltip: "Speech recognition permission required"). Tapping it opens System Settings > Privacy > Speech Recognition.
3. The app also requires Microphone access — same flow applies.
4. Permission state is checked each time dictation is activated, not just on first launch.

### Future: Local Whisper

The `TranscriptionService` protocol allows swapping in a local Whisper model (via `whisper.cpp` or similar) without changing any consumers. This is not in scope for the initial build but the architecture supports it.

## Settings

Accessible via right-click on the menu bar icon.

- **Obsidian vault path** — File picker, defaults to `~/Documents/Obsidian Vault`
- **Claude API key** — Password field with status indicator (connected / not configured)
- **Hotkey bindings** — Two configurable shortcut fields. Defaults: **Ctrl+Space** (toggle panel), **Ctrl+Shift+Space** (dictate)
- **Launch at login** — Checkbox

## Technology Stack

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Platform:** macOS (menu bar app, `NSStatusItem` + `NSPopover`)
- **Global hotkeys:** `CGEvent` taps or HotKey library
- **Speech-to-text:** macOS built-in dictation
- **AI:** Claude API (Haiku for auto-processing, Sonnet for on-demand)
- **File I/O:** Foundation `FileManager` for vault writes

## Out of Scope (Initial Build)

- On-demand Claude commands (summarize, reorganize, tag)
- Local Whisper integration
- Link content fetching/summarization
- Obsidian plugin
- iOS/iPad companion
- Sync across devices
