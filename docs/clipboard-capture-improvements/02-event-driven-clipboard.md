---
title: Event-driven clipboard watching
---

# Event-driven clipboard watching

## Does Electron expose clipboard change events?

**No — not as a stable cross-platform API today.**

- Electron’s [`clipboard`](https://www.electronjs.org/docs/latest/api/clipboard) module provides `readText()`, `writeText()`, etc., but **no** `on('change')` or equivalent.
- [electron/electron#2280](https://github.com/electron/electron/issues/2280) has been open for years; Chromium added partial Linux/X11 support internally, but Electron has not shipped a unified clipboard-change event for all platforms.
- Community packages (`electron-clipboard-extended`, `clipboard-event`, etc.) implement “events” by **polling** under the hood.

### Platform summary

| Platform | Native change notification | Practical approach for EE2 |
| -------- | -------------------------- | --------------------------- |
| **Windows** | Yes — `AddClipboardFormatListener` (Win32 API) | **Phase 1:** adaptive polling. **Phase 2 (optional):** small native addon or maintained npm binding. |
| **Linux (X11)** | Yes — `QClipboard::dataChanged`, X selection owner changes | **Phase 1:** adaptive polling (works under XWayland too). **Phase 2:** optional X11-specific watcher if profiling shows need. |
| **Linux (Wayland)** | Via compositor/protocol; not uniformly exposed to Electron | Polling fallback; same as today but driven by session watcher, not ad-hoc `setTimeout` loops. |
| **macOS** | `NSPasteboard` change notifications exist | **Phase 1:** polling only (Electron/macOS clipboard reads are already relatively fast). Native addon possible later. |

**Answer for Windows:** event-driven capture **can** work on Windows, but **not through Electron alone**. You either poll, or add a native listener. The redesign should use a **`ClipboardWatcher` abstraction** so Windows can swap in a real listener later without changing capture session logic.

## Recommended design: hybrid watcher

Introduce `main/src/shortcuts/ClipboardWatcher.ts`:

```ts
interface ClipboardWatcher {
  /** Begin watching; idempotent per capture session. */
  start(): void;
  /** Stop watching and release timers/listeners. */
  stop(): void;
  /**
   * Resolves when clipboard text is a PoE item AND differs from baseline.
   * Rejects on timeout or abort signal.
   */
  waitForNewPoEItem(options: {
    baseline: string;
    timeoutMs: number;
    signal: AbortSignal;
  }): Promise<string>;
}
```

### Phase 1 implementation — `PollingClipboardWatcher`

Default on **all platforms**:

| Property | Value | Rationale |
| -------- | ----- | --------- |
| Initial interval | 16–24 ms after copy trigger | Faster reaction than today’s 48 ms fixed delay |
| Max interval | 48 ms | Cap CPU use during long waits |
| Timeout | 500 ms (configurable constant) | Match current behavior |
| Change detection | `readText()` only when `hash(text) !== lastHash` | Skip work if clipboard unchanged |
| Accept condition | `isPoeItem(text) && text !== baseline` | Generation/baseline model (see [session model](./03-capture-session-model.md)) |

This is **event-driven in spirit** (react only when content changes) even though the trigger is implemented via polling.

### Phase 2 implementation — platform backends (optional)

| Backend | When to add | Notes |
| ------- | ----------- | ----- |
| `WindowsClipboardWatcher` | If Phase 1 profiling shows missed captures or high CPU on Windows | `AddClipboardFormatListener` → wake poll loop or read immediately |
| `LinuxX11ClipboardWatcher` | Low priority; CachyOS/XWayland users may still be on polling path | Only if running under X11/XWayland and measurable win |
| Electron upstream API | If Electron ever ships `clipboard.on('changed')` | Delegate from `PollingClipboardWatcher` |

**Do not block** the session/queue/generation work on Phase 2. Ship Phase 1 first.

## Watcher lifecycle per capture session

```text
session.start()
  → watcher.start()
  → record baseline (read only)
  → trigger simulated copy
  → await watcher.waitForNewPoEItem({ baseline, timeout, signal })
  → watcher.stop()
  → session.end() → optional restore (outside watcher)
```

Only **one** watcher instance should be active (enforced by serialized queue).

## Interaction with clipboard managers

Event-driven / change-detection helps but does not fully solve history managers:

- Pasting from history **is** a clipboard change → watcher fires.
- Mitigation remains: **`text !== baseline`** plus **serialized captures** so only the active session consumes the change.
- Optional future setting: “ignore clipboard changes in first N ms after copy” to ignore user history paste during capture (not in initial scope).

## Logging and diagnostics

Add debug logs behind existing key-log / remote logger patterns:

```text
debug [ClipboardWatcher] platform=polling baselineLen=42 timeout=500
debug [ClipboardWatcher] change detected len=891 isPoe=true differsFromBaseline=true
warn  [ClipboardWatcher] timeout after 500ms lastLen=0
```

Include `captureGeneration` in log lines when session model is implemented.

## Files to add / change

| File | Action |
| ---- | ------ |
| `main/src/shortcuts/ClipboardWatcher.ts` | **New** — interface + factory |
| `main/src/shortcuts/PollingClipboardWatcher.ts` | **New** — Phase 1 default |
| `main/src/shortcuts/HostClipboard.ts` | **Refactor** — delegate to watcher + session (or split into `ItemCaptureService`) |

## Testing notes

- Unit-test `waitForNewPoEItem` with injected `readText` mock (no OS clipboard).
- Manual matrix: Windows 10/11, Linux X11, Linux Wayland + XWayland, macOS if available.
- Scenarios: consecutive items, same item twice, empty hover (timeout), clipboard manager history paste during capture.
