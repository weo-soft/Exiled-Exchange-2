---
title: Development
---

# Development guide

This guide covers local setup, day-to-day development, testing, building, and extending Exiled Exchange 2. For system design, see [Architecture](/architecture).

## Prerequisites

| Tool | Version | Notes |
| ---- | ------- | ----- |
| Node.js | 24.x | Matches CI (`.github/workflows/`) |
| npm | bundled | `npm ci` in both `renderer/` and `main/` |
| Electron | ~40.x | Declared in `main/package.json`; native addons compile against this ABI |
| Python | 3.10+ | Only for `dataParser/` (see [Data pipeline](#data-pipeline)) |
| Git | any recent | |
| pre-commit | optional | Recommended locally; required in CI (see [Code quality](#code-quality)) |

Use **`npm ci`** for reproducible installs (matches CI). `npm install` is fine for casual local dev when lockfiles are unchanged.

Platform-specific requirements for running the overlay:

- **Windows** — no extra setup
- **Linux** — X11/Wayland display server; Wine paths if testing log watching
- **macOS** — accessibility permission for global hotkeys

## Project structure

EE2 is a monorepo with two runnable Node packages and a Python data tool:

```
renderer/     Vue 3 + Vite frontend (also runs standalone in dev)
main/         Electron main process + packaging
ipc/          Shared TypeScript types
dataParser/   Python pipeline for game/trade static data
docs/         VitePress documentation site (this site)
```

The renderer and main processes are **tightly coupled**: the renderer expects the main process HTTP/WebSocket server for IPC, config, and proxying. They are developed as two terminal sessions.

## Initial setup

```bash
# Terminal 1 — renderer
cd renderer
npm ci
npm run make-index-files
npm run dev

# Terminal 2 — main (Electron)
cd main
npm ci
npm run dev
```

`make-index-files` generates binary-search index files used by `renderer/src/assets/data/`. Run it again after updating ndjson data files.

In dev mode:

- Vite serves the UI (typically `http://localhost:5173`)
- Electron loads that URL via `VITE_DEV_SERVER_URL`
- WebSocket IPC connects to port **8584** on localhost

In production (or without `VITE_DEV_SERVER_URL`), the HTTP server uses an **ephemeral port** unless you pass `--listen=127.0.0.1:8584`. See [Command-line options](/cmd-flags).

## Development workflow

### Renderer hot reload

Vite provides HMR for Vue components and TypeScript. Changes to `renderer/src/` reload automatically in the overlay.

### Main process rebuild

The main process is bundled with esbuild (`main/build/script.mjs`). `npm run dev` watches and rebuilds; restart Electron if you change main-process code that runs only at startup.

### Debugging

- **Vue DevTools** — auto-installed in dev mode (`main/src/main.ts`)
- **Renderer DevTools** — detached DevTools open automatically in dev
- **Main process logs** — appear in the terminal running `npm run dev` in `main/`
- **In-app log viewer** — enable debug settings to stream `MAIN->CLIENT::log-entry` in the overlay
- **Main process attach** — restart `npm run dev` in `main/` after startup-only changes; watch the terminal for `[Shortcuts]`, `[ClipboardPoller]`, and `info`/`error` lines from `RemoteLogger`
- **WebSocket IPC** — with `--listen=127.0.0.1:8584`, you can inspect `/config` and connect a WebSocket client to `ws://127.0.0.1:8584/events` to observe event traffic

### Configuration during development

Config is read from the host `userData` path even in dev:

| OS | Path |
| -- | ---- |
| Windows | `%APPDATA%\exiled-exchange-2\apt-data\config.json` |
| Linux | `~/.config/exiled-exchange-2/apt-data/config.json` |
| macOS | `~/Library/Application Support/exiled-exchange-2/apt-data/config.json` |

In dev, saves to disk are skipped (`ConfigStore` returns early when `VITE_DEV_SERVER_URL` is set), but config still loads from the file if present.

### Useful command-line flags

See [Command-line options](/cmd-flags). Common dev flags:

```bash
# Browser-only mode (no overlay window)
electron . --no-overlay

# Fixed listen address
electron . --listen=127.0.0.1:8584

# Disable auto-update
electron . --no-updates
```

## Code quality

### Linting and formatting

```bash
# Renderer
cd renderer
npm run lint
npm run format

# Main
cd main
npm run lint
npm run format
```

CI runs [pre-commit](https://pre-commit.com/) hooks via `.github/workflows/test.yml`. Install locally to catch issues before pushing:

```bash
pip install pre-commit
pre-commit install
```

Hooks cover trailing whitespace, version consistency, lint/format, and type checks for `main/` and `renderer/`. The `dataParser/` tree has its own hooks in `dataParser/.pre-commit-config.yaml` when run repo-wide.

### Type checking

```bash
cd renderer && npm run check-types
cd main && npm run check-types
```

Build scripts run type checks as part of `npm run build`.

## Testing

Tests live in `renderer/specs/` and use [Vitest](https://vitest.dev/).

```bash
cd renderer
npm run make-index-files   # required before tests
npm run test
```

Notable test areas:

| Path | Covers |
| ---- | ------ |
| `specs/Parser/` | Item text parsing |
| `specs/web/` | Trade filters, client log, prices |
| `specs/web/price-check/` | Filter generation |

There are no automated tests for the Electron main process. Use the checklist below after main-process changes.

### dataParser tests

```bash
cd dataParser
pip install -r requirements.txt
pytest
```

The `dataParser/` tree also runs through pre-commit (ruff, bandit) when hooks are installed repo-wide.

### Main process manual test checklist

After changes to `main/` or `ipc/types.ts`:

- [ ] Overlay attaches to PoE2 window (correct **window title** in settings)
- [ ] Price-check hotkey copies item text with advanced mods (show-mods key matches game config)
- [ ] Hotkeys do nothing when game is unfocused, work again on refocus
- [ ] Overlay key (`Shift + Space`) toggles click-through vs interactable UI
- [ ] `--no-overlay` opens browser UI; WebSocket IPC still works
- [ ] Restore clipboard setting preserves prior clipboard content
- [ ] Client log tailing finds `Client.txt` (set path manually on Linux/Proton if needed)
- [ ] Trade proxy returns results when logged in on pathofexile.com via built-in browser

## Building for production

Native addons in `main/` compile against **Electron ~40.x** (not your system Node). If you change the Electron version in `main/package.json`, delete `main/node_modules` and run `npm ci` again.

```bash
# 1. Build renderer
cd renderer
npm ci
npm run make-index-files
npm run build          # outputs to renderer/dist/

# 2. Build and package main
cd ../main
npm ci
npm run build          # outputs to main/dist/
npm run package        # electron-builder installers in main/dist/
```

Platform-specific output:

| OS | Artifact (in `main/dist/`) |
| -- | -------------------------- |
| Linux | `exiled-exchange-2-<version>.AppImage` |
| Windows | `exiled-exchange-2-Setup-<version>.exe`, portable `.exe` |
| macOS | `exiled-exchange-2-<version>-universal.dmg` |

**Linux and Arch Linux:** prerequisites (FUSE, `base-devel`, native modules), running the AppImage, Steam/Proton paths, and Wayland notes are documented in [Building for Linux](/building-linux).

Signed Windows builds require a code-signing certificate:

```bash
CSC_NAME="Certificate name in Keychain" npm run package
```

### Local release dry-run

```bash
sh testUpdate.sh
```

Read the script before running — it simulates an update/build cycle.

## Data pipeline

Game and trade static data is **not** fetched at runtime for core parsing. It is pre-built and committed under `renderer/public/data/`.

### Python environment

Run commands from the `dataParser/` directory. Third-party packages used by the pipeline include:

- `pandas`, `numpy`, `tqdm`
- `cloudscraper`, `requests` (trade API access)
- `murmurhash2`

Install dependencies (or use a virtualenv):

```bash
cd dataParser
pip install -r requirements.txt
```

### Regenerating data

```bash
cd dataParser
python ./src/main.py --help
```

Typical workflow:

```bash
# Pull latest from PoE APIs (slow; optional)
python ./src/main.py --pull

# Build output for all languages
python ./src/main.py

# Copy output into renderer (adjust --main-repo-path if needed)
python ./src/main.py --push --main-repo-path=..
```

The default `--main-repo-path` is `../exiled-exchange-2` (lowercase). On case-sensitive filesystems, pass the actual clone path (e.g. `--main-repo-path=..` from inside this monorepo).

After pushing new data:

```bash
cd renderer
npm run make-index-files
```

Output artifacts per language:

- `items.ndjson` — item base types and properties
- `stats.ndjson` — trade stat ids and text matchers
- `client_strings.js` — in-game string templates for the parser

The dataParser README notes that active development sometimes happens in a private repo; if the tooling looks stale, file an issue.

## Extending the application

### Adding a widget

1. **Create the Vue component** in `renderer/src/web/<feature>/`
2. **Define the widget spec** — export a `widget` object on the component:

```ts
import type { WidgetSpec } from "@/web/overlay/interfaces";

export const widget: WidgetSpec = {
  type: "my-widget",
  instances: "single",       // or "multi"
  trNameKey: "widget.my_widget",
  initInstance: () => ({
    wmId: 0,
    wmType: "my-widget",
    wmTitle: "My Widget",
    wmWants: "hide",
    wmZorder: null,
    wmFlags: [],
    // ... widget-specific fields
  }),
};
```

3. **Register** in `renderer/src/web/overlay/widget-registry.ts`
4. **Add config types** — extend `Config` in `renderer/src/web/Config.ts` with your widget interface
5. **Add settings UI** (optional) — settings panel component linked from the widget or settings window
6. **Add i18n keys** in `renderer/public/data/en/app_i18n.json` (and other languages via Weblate)

### Adding a hotkey action

1. Extend `ShortcutAction` in `ipc/types.ts`
2. Handle the action in `main/src/shortcuts/Shortcuts.ts`
3. Add UI to configure it in `renderer/src/web/settings/hotkeys.vue`

### Adding an IPC event

1. Add the event type to `IpcEvent` in `ipc/types.ts`
2. Emit/handle in `main/src/server.ts` or the relevant main module
3. Subscribe via `Host.onEvent()` in the renderer

Keep payloads JSON-serializable — WebSocket messages are `JSON.stringify`'d.

### Parser changes

When PoE2 adds new item sections or modifier formats:

1. Update section parsers in `renderer/src/parser/Parser.ts`
2. Add/adjust modifier logic in `advanced-mod-desc.ts` / `modifiers.ts`
3. Update static data if new base types or stats are needed (`dataParser/`)
4. Add tests under `renderer/specs/Parser/`

### Trade filter changes

Trade query construction lives in:

- `renderer/src/web/price-check/filters/create-item-filters.ts`
- `renderer/src/web/price-check/filters/create-stat-filters.ts`
- `renderer/src/web/price-check/filters/pseudo/` — special-case rules

Update tests in `renderer/specs/web/price-check/filters/`.

## Documentation site

The `docs/` folder is a [VitePress](https://vitepress.dev/) site published to GitHub Pages.

```bash
cd docs
npm install
npm run dev      # local preview (default port 5173)
npm run build    # static site → docs/.vitepress/dist
```

**Port conflict:** the renderer dev server also defaults to port **5173**. If you run app dev and docs preview together, use a different port for one of them:

```bash
# docs on 5174 while renderer uses 5173
npm run dev -- --port 5174
```

CI deploys with `npx vitepress build` (see `.github/workflows/pages.yml`). Mermaid diagrams render via `vitepress-plugin-mermaid` in `docs/.vitepress/config.js`. The displayed app version is read from `main/package.json` automatically.

User-facing pages (download, FAQ, feature guides) and developer pages (architecture, development) share the same site. Sidebar navigation is configured in `docs/.vitepress/config.js`.

## Contributing

1. Fork the repository and create a branch from `master` (or `dev` for larger in-progress work).
2. Run `npm ci`, lint, and tests locally before opening a PR (see [Code quality](#code-quality) and [Testing](#testing)).
3. Keep changes focused — parser, trade filters, and IPC contracts often need matching updates on both `main/` and `renderer/`.
4. Open a pull request against `master` with a short description and test notes. CI runs pre-commit hooks and renderer Vitest on PRs.

**CI scope:** pushes that only touch `docs/**` or `README.md` trigger the docs deploy workflow (`.github/workflows/pages.yml`) but **not** the app build (`.github/workflows/main.yml` uses `paths-ignore` for those paths). Code changes should still run tests locally.

There is no separate `CONTRIBUTING.md`; this section and the linked architecture docs are the contributor reference.

## Release process

CI builds installers on every **`master` push**. Tag pushes do **not** trigger CI (`tags-ignore: '**'` in `.github/workflows/main.yml`). Publishing to GitHub Releases uses electron-builder's `onTagOrDraft` mode — artifacts attach to a **draft release or tag that already exists** when the CI job runs.

Recommended sequence:

1. Commit all feature/fix changes to `master` (or merge via PR).
2. Bump version in `main/package.json`.
3. `npm i` in `renderer/` and `main/` (refresh lockfiles if needed).
4. `npm run build` in both packages; fix any failures.
5. Commit the version bump.
6. On GitHub, create a **draft release** for tag `vX.Y.Z` matching the new `main/package.json` version (create the tag as part of the draft release).
7. `git push origin master` — triggers CI; the package job uploads installers to that draft release.
8. Verify Windows/Linux/macOS artifacts on the draft release, then publish it.

Pushing a git tag alone (`git push origin vX.Y.Z`) will not re-run CI. The draft release (or pre-existing tag) must be in place **before or when** the version-bump commit lands on `master`.

Signed Windows installers require a local certificate (`CSC_NAME`); CI builds are unsigned unless signing secrets are configured.

## Troubleshooting development

| Problem | Likely cause | Fix |
| ------- | ------------ | --- |
| Black overlay on Linux | GPU/compositor issue | Known workaround: 1 s delay in `main.ts`; try `--no-overlay` |
| Hotkeys not working | Game window not focused / wrong title | Set `windowTitle` to match PoE2 window title in settings |
| WebSocket disconnects | Port conflict | Use `--listen=127.0.0.1:8584` |
| Parser can't find item | Stale `items.ndjson` | Regenerate data, run `make-index-files` |
| Trade API 401/403 | Not logged in on PoE website | Log in via the built-in browser widget; cookies flow through proxy |
| Types out of sync | `ipc/types.ts` changed | Rebuild both packages; restart dev servers |

## Related documentation

- [Architecture](/architecture) — system design and component interactions
- [Building for Linux](/building-linux) — AppImage build, Arch deps, running the artifact
- [Item capture from game](/item-capture) — how item text is retrieved on hotkey
- [Client Log Parser](/client-log-parser) — log event schema
- [Item Data](/item-data) — experimental crafting data collection
- [DEVELOPING.md](https://github.com/Kvan7/Exiled-Exchange-2/blob/master/DEVELOPING.md) — quick reference in the repo root
