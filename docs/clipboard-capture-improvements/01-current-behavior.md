---
title: Current clipboard behavior
---

# Current clipboard behavior

Baseline reference for the redesign. Source of truth today: `main/src/shortcuts/HostClipboard.ts`.

## Flow on `copy-item` hotkey

`Shortcuts.ts` runs two operations **in parallel**:

1. `clipboard.readItemText()` — async poll
2. `pressKeysToCopyItemText()` — simulated `Ctrl + showMods + C`

There is no ordering guarantee between them beyond both starting in the same synchronous callback.

## `readItemText()` steps

1. If `pollPromise` exists → await the **same** promise (second hotkey does not get its own capture).
2. Read `textBefore = clipboard.readText()`.
3. If `textBefore` looks like a PoE item → set `textBefore = ""` and `clipboard.writeText("")`.
4. Poll every **48 ms**, up to **500 ms**:
   - If clipboard is PoE item text → resolve immediately.
   - On success with **Restore clipboard** enabled → `writeText(textBefore)` **before** resolving.
   - On timeout → optionally restore, reject with `"Reading clipboard timed out"`.

## `restoreShortly()` (chat macros, stash search)

Used by `text-box.ts` for `paste-in-chat` and `stash-search`:

1. Save current clipboard.
2. Run callback that writes macro/search text and simulates paste.
3. After **120 ms**, restore saved text if restore setting is enabled.

This path is independent of item capture but shares the same Electron `clipboard` API and the global restore setting.

## Pain points mapped to code

| Pain point | Location |
| ---------- | -------- |
| Shared poll across hotkeys | `HostClipboard.ts` lines 32–34 |
| Accept first PoE text without “new since baseline” check | `HostClipboard.ts` lines 44–51 |
| Early clipboard clear | `HostClipboard.ts` lines 37–40 |
| Restore inside poll loop | `HostClipboard.ts` lines 47–48, 57–58 |
| Copy and read not tied to one session | `Shortcuts.ts` lines 216–240 |
| Errors swallowed | `Shortcuts.ts` line 233 `.catch(() => {})` |

## Constraints to preserve

- **ToS-safe model** — still rely on PoE writing item text to the clipboard; no game memory access.
- **Restore clipboard setting** — user-facing option in Settings → General (`restoreClipboard`).
- **Show-mods key** — still read from `GameConfig` / `poe2_production_Config.ini`.
- **Concurrent macro paste** — `restoreShortly` must not corrupt an in-flight item capture (needs coordination in the new design).
- **All supported client languages** — `LANGUAGE_DETECTOR` / `isPoeItem()` prefixes must remain.

## IPC contract (unchanged)

Successful capture sends `MAIN->CLIENT::item-text`:

```ts
{
  target: string;
  clipboard: string;
  position: { x: number; y: number };
  focusOverlay: boolean;
}
```

The redesign should not require renderer changes for basic operation.
