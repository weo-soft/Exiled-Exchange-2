---
title: Implementation checklist
---

# Implementation checklist

Step-by-step tasks to implement the [capture session model](./03-capture-session-model.md) and [event-driven watcher](./02-event-driven-clipboard.md).

Phases are ordered so each phase is shippable and testable on its own.

---

## Phase 0 — Preparation

- [ ] **0.1** Read baseline docs: [01-current-behavior](./01-current-behavior.md), [item-capture](/item-capture).
- [ ] **0.2** Add debug logging convention: `[CaptureQueue]`, `[CaptureSession]`, `[ClipboardWatcher]` prefixes (match existing `[ClipboardPoller]` style).
- [ ] **0.3** Decide queue overflow policy (recommended: max 5, drop oldest, log `warn`).

---

## Phase 1 — Extract utilities (no behavior change)

| Step | File | Task |
| ---- | ---- | ---- |
| 1.1 | `main/src/shortcuts/poe-clipboard.ts` | **New.** Export `isPoeItem(text)`, `LANGUAGE_DETECTOR`, `hashClipboardText(text)` (simple hash for change detection). |
| 1.2 | `main/src/shortcuts/HostClipboard.ts` | Import `isPoeItem` from `poe-clipboard.ts`; re-export if needed for tests. |
| 1.3 | `main/src/shortcuts/PollingClipboardWatcher.ts` | **New.** Implement `ClipboardWatcher` interface with adaptive polling (see [02-event-driven-clipboard](./02-event-driven-clipboard.md)). |
| 1.4 | `main/src/shortcuts/ClipboardWatcher.ts` | **New.** Export interface + `createClipboardWatcher()` factory (returns `PollingClipboardWatcher` for all platforms in v1). |
| 1.5 | `main/specs/` or `main/src/shortcuts/*.test.ts` | **New.** Unit tests for watcher: baseline filtering, timeout, abort signal, `text !== baseline` acceptance. |

**Exit criteria:** Watcher tests pass; existing app behavior unchanged (not wired yet).

---

## Phase 2 — Capture session + queue

| Step | File | Task |
| ---- | ---- | ---- |
| 2.1 | `main/src/shortcuts/CaptureSession.ts` | **New.** State machine: baseline read, conditional clear, watcher wait, generation check, result. |
| 2.2 | `main/src/shortcuts/CaptureQueue.ts` | **New.** FIFO queue, `enqueue()`, `processNext()`, generation counter, `isCaptureActive` getter. |
| 2.3 | `main/src/shortcuts/CaptureQueue.ts` | Inject dependencies: `Logger`, `ClipboardWatcher` factory, `pressKeysToCopyItemText` callback, restore setting. |
| 2.4 | `main/src/shortcuts/CaptureQueue.ts` | **Skip restore during capture:** all `writeText` for restore happen in `finally` after watcher stopped. |
| 2.5 | `main/src/shortcuts/CaptureQueue.ts` | **Defer clear:** only call `writeText("")` in narrow window immediately before copy when `isPoeItem(baseline)`. |
| 2.6 | `main/specs/CaptureQueue.test.ts` | Unit tests: serialized sessions, generation stale ignore, queue overflow, same-item re-check with conditional clear. |

**Exit criteria:** Queue + session tests pass in isolation with mocked clipboard.

---

## Phase 3 — Wire into Shortcuts

| Step | File | Task |
| ---- | ---- | ---- |
| 3.1 | `main/src/shortcuts/Shortcuts.ts` | Replace `copy-item` branch: build `CaptureRequest`, call `captureQueue.enqueue()`. |
| 3.2 | `main/src/shortcuts/Shortcuts.ts` | Move `pressKeysToCopyItemText()` invocation **from** hotkey callback **into** session (via injected callback). |
| 3.3 | `main/src/shortcuts/Shortcuts.ts` | On `enqueue().then(result)` → send `MAIN->CLIENT::item-text` with `result.clipboard` and original `position`. |
| 3.4 | `main/src/shortcuts/Shortcuts.ts` | Replace silent `.catch(() => {})` with optional debug log on reject (keep user-visible silence for timeout). |
| 3.5 | `main/src/shortcuts/Shortcuts.ts` | Construct `CaptureQueue` in `Shortcuts` constructor; pass `gameConfig.showModsKey`. |
| 3.6 | `main/src/shortcuts/HostClipboard.ts` | **Refactor** to thin facade: `restoreShortly()`, `updateOptions()`, `isCaptureActive` delegated to queue; remove old `readItemText()` poll loop OR keep as deprecated wrapper calling queue for one release. |

**Exit criteria:** Price check works on dev build; consecutive items show correct text + cursor pairing.

---

## Phase 4 — Macro / stash coordination

| Step | File | Task |
| ---- | ---- | ---- |
| 4.1 | `main/src/shortcuts/HostClipboard.ts` | `restoreShortly()`: if `isCaptureActive`, defer or skip with log (choose defer queue if macros must not be lost). |
| 4.2 | `main/src/shortcuts/text-box.ts` | No changes expected if deferral lives in `HostClipboard`. |
| 4.3 | Manual test | Price check during stash search / chat macro does not corrupt clipboard. |

---

## Phase 5 — IPC and docs

| Step | File | Task |
| ---- | ---- | ---- |
| 5.1 | `ipc/types.ts` | Optional: add `captureGeneration?: number` to `IpcItemText` payload. |
| 5.2 | `docs/item-capture.md` | Update “Clipboard polling” section → “Capture session” + watcher description. |
| 5.3 | `docs/item-capture.md` | Update error cases: queued captures, stale result prevention. |
| 5.4 | `docs/architecture.md` | Update Shortcuts / HostClipboard summary table. |
| 5.5 | `docs/development.md` | Add manual test checklist entries for consecutive items + clipboard manager. |

---

## Phase 6 — Optional platform watcher (future)

| Step | File | Task |
| ---- | ---- | ---- |
| 6.1 | Research | Evaluate `clipboard-event` or native addon for Windows `AddClipboardFormatListener`. |
| 6.2 | `main/src/shortcuts/WindowsClipboardWatcher.ts` | **New.** Wake on native event, read text once. |
| 6.3 | `ClipboardWatcher.ts` factory | `win32` → try native watcher, fallback to polling. |
| 6.4 | Benchmark | Compare miss rate and CPU vs Phase 1 polling on Windows. |

**Not required for initial merge.**

---

## File change summary

| File | Phase | Change |
| ---- | ----- | ------ |
| `main/src/shortcuts/poe-clipboard.ts` | 1 | **New** |
| `main/src/shortcuts/ClipboardWatcher.ts` | 1 | **New** |
| `main/src/shortcuts/PollingClipboardWatcher.ts` | 1 | **New** |
| `main/src/shortcuts/CaptureSession.ts` | 2 | **New** |
| `main/src/shortcuts/CaptureQueue.ts` | 2 | **New** |
| `main/src/shortcuts/HostClipboard.ts` | 1–4 | **Refactor** |
| `main/src/shortcuts/Shortcuts.ts` | 3 | **Modify** |
| `main/src/shortcuts/text-box.ts` | 4 | Verify / minimal |
| `ipc/types.ts` | 5 | Optional field |
| `docs/item-capture.md` | 5 | **Update** |
| `docs/architecture.md` | 5 | **Update** |

---

## Manual test plan

### Core capture

- [ ] Single item in inventory — price check shows correct item.
- [ ] Single item in stash — panel side correct.
- [ ] Advanced mods present when show-mods key configured.
- [ ] Hover empty space — timeout, no crash; overlay keeps or clears per current UX.

### Consecutive items (primary regression target)

- [ ] Item A → immediately item B — B’s text, B’s cursor side.
- [ ] Three rapid hotkeys on A, B, C — three correct results in order (may queue delay).
- [ ] Same item twice in a row — second check still succeeds.

### Clipboard setting

- [ ] `restoreClipboard: false` — non-PoE clipboard not restored; behavior unchanged from user POV.
- [ ] `restoreClipboard: true` — password/non-PoE text restored after capture completes.

### Clipboard manager (Linux / CachyOS)

- [ ] Klipper / CopyQ / GPaste running — no wrong item when not touching history mid-capture.
- [ ] Paste from history **during** capture — document whether wrong item can still occur (known limitation) or mitigated by baseline check.

### Macros

- [ ] Chat macro during idle — still works.
- [ ] Chat macro during active capture — deferred or blocked cleanly.

### Platforms

- [ ] Windows 10/11
- [ ] Linux X11 or XWayland (CachyOS)
- [ ] macOS (if available)

---

## Rollout strategy

1. Merge Phases 1–3 behind no flag first (queue replaces old path entirely once stable).
2. Keep `[ClipboardPoller]` log tag as alias or migrate to `[ClipboardWatcher]` in same PR to avoid confusing existing debug guides.
3. Monitor issue tracker for “wrong item” / “nothing happens” reports after release.

---

## Open decisions (resolve during implementation)

| # | Question | Recommendation |
| - | -------- | -------------- |
| 1 | Queue max depth | 5, drop oldest |
| 2 | When queue full, log level | `warn` |
| 3 | Restore PoE baseline as `""` or full text | `""` (matches current stale clear semantics) |
| 4 | Defer `restoreShortly` or drop macro | Defer until capture ends |
| 5 | Increase timeout on Linux Wayland | Only if manual tests fail; try 750 ms as tunable constant |
