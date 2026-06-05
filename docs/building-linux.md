---
title: Building for Linux
---

# Building for Linux

Exiled Exchange 2 ships on Linux as an **AppImage** — a single portable executable built by [electron-builder](https://www.electron.build/). Official releases are built on **Ubuntu 22.04** in CI; the same steps work on any **x86_64** Linux distribution, including **Arch Linux** and derivatives (CachyOS, EndeavourOS, etc.). **ARM and other architectures are unsupported.**

This guide covers prerequisites, building from source, output artifacts, running the result, and Arch-specific notes.

## Distribution format

| Platform | Format | Config (`main/electron-builder.yml`) |
| -------- | ------ | ------------------------------------ |
| Linux | AppImage | `linux.target: [AppImage]` |
| Windows | NSIS installer + portable `.exe` | — |
| macOS | Universal DMG | — |

There is **no** native `.deb`, `.rpm`, Flatpak, or official AUR package in this repository. On Arch, use the AppImage directly or wrap it in your own PKGBUILD.

The AppImage is launched with `--sandbox` (see `appImage.executableArgs` in `electron-builder.yml`).

## Prerequisites (all Linux)

| Requirement | Version / notes |
| ----------- | --------------- |
| **Architecture** | x86_64 only (matches CI) |
| **Node.js** | 24.x (matches [CI](https://github.com/Kvan7/Exiled-Exchange-2/blob/master/.github/workflows/main.yml)) |
| **Electron** | ~40.x (from `main/package.json`; native modules compile against this, not system Node) |
| **npm** | Bundled with Node; use `npm ci` for reproducible installs |
| **Git** | To clone the repository |
| **Build toolchain** | C/C++ compiler and `make` — needed to compile native Node modules (`uiohook-napi`, `electron-overlay-window`) against Electron |
| **Disk space** | ~2 GB for `node_modules`, Electron download, and build artifacts |

### Native modules

`main/package.json` depends on two native addons:

- **`uiohook-napi`** — global keyboard/mouse hooks for hotkeys
- **`electron-overlay-window`** — transparent overlay attached to the game window

`electron-builder.yml` sets `npmRebuild: false`, so these **must** compile successfully during `npm ci` / `npm install` in `main/`. If they fail, fix your build environment before running `npm run package`.

Native addons must compile against **Electron's Node ABI**, not your system Node. `npm ci` in `main/` triggers the correct rebuild via `electron` as the runtime target. If you switch Electron versions, delete `main/node_modules` and reinstall.

### Optional: run without packaging

For day-to-day development you do not need an AppImage. See [Development](/development) — run `npm run dev` in `renderer/` and `main/` in two terminals.

## Build steps

The canonical build commands live in [Development → Building for production](/development#building-for-production). On Linux the result is an AppImage in `main/dist/`.

```bash
cd renderer && npm ci && npm run make-index-files && npm run build
cd ../main && npm ci && npm run build && npm run package
```

Or use the helper script (cleans previous `dist/` folders first):

```bash
sh testUpdate.sh
```

`testUpdate.sh` uses `npm install` (not `npm ci`) and runs a full package build. Read the script before running. For CI-identical installs, prefer the manual `npm ci` steps above.

### Build output

After a successful `npm run package` on Linux, expect artifacts in `main/dist/`:

| File | Purpose |
| ---- | ------- |
| `exiled-exchange-2-<version>.AppImage` | Runnable application |
| `latest-linux.yml` | electron-updater metadata (used by auto-update) |
| `builder-effective-config.yaml` | Resolved electron-builder config (debug) |

Version `<version>` comes from `main/package.json` (e.g. `0.15.4`).

### What gets bundled

electron-builder combines:

- `main/dist/main.js` and `main/dist/vision.js` (esbuild output)
- `renderer/dist/` (Vite production build — HTML, JS, CSS, game data)
- Electron runtime and declared dependencies

Static game data (`items.ndjson`, `stats.ndjson`, etc.) is already inside `renderer/dist/` from the renderer build step.

## Running the AppImage

```bash
chmod +x main/dist/exiled-exchange-2-*.AppImage
./main/dist/exiled-exchange-2-*.AppImage
```

### FUSE requirement

AppImages mount themselves via FUSE. You need FUSE available at runtime:

- **FUSE 2** (`libfuse2` / `fuse2`) — required by most Electron AppImages
- Alternatively, extract and run without FUSE: `./AppImage --appimage-extract` then `./squashfs-root/AppRun`

### User data and config

On Linux, settings are stored at:

```
~/.config/exiled-exchange-2/apt-data/config.json
```

Logs and uploads use the same `apt-data` directory under `userData`.

### Game file paths (Linux)

The app searches common locations for PoE2 files:

| File | Typical paths |
| ---- | ------------- |
| `Client.txt` | `~/.wine/.../Path of Exile 2/logs/Client.txt`, `~/.local/share/Steam/steamapps/common/Path of Exile 2/logs/Client.txt` |
| `poe2_production_Config.ini` | `~/Documents/My Games/Path of Exile 2/`, Steam Proton `compatdata/.../pfx/drive_c/users/steamuser/Documents/...` |

Steam/Proton installs may need manual paths in Settings → General.

### Display and compositor

- PoE2 must run in **Windowed** or **Windowed Fullscreen** (not exclusive fullscreen). See [Download → Requirements](/download).
- **X11** has the best overlay support today.
- **Wayland** has known issues ([#673](https://github.com/Kvan7/Exiled-Exchange-2/issues/673)); XWayland may work better.
- If the overlay is a **black rectangle**, see [Common issues → Linux](/issues). A 1 s startup delay in `main.ts` mitigates some compositor bugs.

### Browser-only fallback

If the overlay does not work on your setup:

```bash
./exiled-exchange-2-*.AppImage --no-overlay
```

Opens the UI in your default browser; hotkeys and clipboard capture still run in the Electron main process. See [Command-line options](/cmd-flags).

### Auto-update

Linux AppImages support automatic updates via `electron-updater` (unlike macOS DMG). Disable with `--no-updates`.

---

## Arch Linux

Arch and Arch-based distros follow the same build steps as above. Below are **pacman packages** and runtime notes specific to Arch.

### Build dependencies (Arch)

Install toolchain and Node:

```bash
sudo pacman -S --needed base-devel git nodejs npm
```

`base-devel` provides `gcc`, `make`, and other tools required by `node-gyp` when compiling `uiohook-napi` and `electron-overlay-window`.

If `npm ci` in `main/` fails on native compilation, ensure headers are available:

```bash
sudo pacman -S --needed libxtst libx11 libxkbfile libuv
```

Node 24 is in official Arch repos. For an exact CI match, you can use [nvm](https://github.com/nvm-sh/nvm) or [fnm](https://github.com/Schniz/fnm):

```bash
nvm install 24
nvm use 24
```

### Runtime dependencies (Arch)

For running the AppImage (not building):

```bash
# FUSE 2 — required to launch AppImages
sudo pacman -S --needed fuse2

# Tray icon (optional; often missing on minimal setups)
sudo pacman -S --needed libappindicator-gtk3
```

On systems where `fuse2` was removed in favor of FUSE3 only, install `fuse2` from official repos or use `--appimage-extract` as described above.

### Building on Arch — full example

```bash
git clone https://github.com/Kvan7/Exiled-Exchange-2.git
cd Exiled-Exchange-2

# Same steps as Development → Building for production
cd renderer && npm ci && npm run make-index-files && npm run build
cd ../main && npm ci && npm run build && npm run package

chmod +x main/dist/exiled-exchange-2-*.AppImage
./main/dist/exiled-exchange-2-*.AppImage
```

### Installing a release build (Arch)

Download the AppImage from [Download](/download) or [GitHub Releases](https://github.com/Kvan7/Exiled-Exchange-2/releases):

```bash
chmod +x ~/Downloads/exiled-exchange-2-*.AppImage
~/Downloads/exiled-exchange-2-*.AppImage
```

Optional: move to `~/.local/bin/` or `/opt/` and add a `.desktop` file for the application menu.

### AUR / PKGBUILD

This repository does **not** maintain an AUR package. Community packages may exist under names like `exiled-exchange-2` or `exiled-exchange-2-bin` — verify the packager and source URL before installing.

To create your own `PKGBUILD` for the pre-built AppImage:

1. Set `source` to the GitHub release `.AppImage` URL
2. Install to `/opt/exiled-exchange-2/` or `$pkgdir/opt/...`
3. Add a `.desktop` launcher executing the AppImage with `--sandbox`
4. Declare `depends=('fuse2')` and optionally `libappindicator-gtk3`

Building the AppImage inside a `PKGBUILD` is possible but slow (downloads Electron, compiles native modules); repackaging the official release AppImage is simpler.

### Arch + Steam + Proton

If PoE2 runs via Steam Proton:

- Set **window title** in EE2 settings to match the actual game window (often `Path of Exile 2`).
- Point **game config** and **client log** paths to the Proton prefix if auto-detection fails, e.g.:
  - `~/.local/share/Steam/steamapps/compatdata/2694490/pfx/drive_c/users/steamuser/Documents/My Games/Path of Exile 2/poe2_production_Config.ini` (PoE2 Steam app ID `2694490`)
  - `~/.local/share/Steam/steamapps/common/Path of Exile 2/logs/Client.txt` (native Linux install) or Wine path under `compatdata`

### Arch + Wayland (Hyprland, Sway, KDE Plasma)

- Prefer **XWayland** for PoE2 if the overlay misbehaves.
- Tray icon may not appear without `libappindicator-gtk3` and a compatible status tray (some Wayland bars need `xdg-desktop-portal` or legacy tray support).
- See [issue #673](https://github.com/Kvan7/Exiled-Exchange-2/issues/673) for ongoing Wayland discussion.

### CachyOS and other Arch derivatives

Same instructions apply. CachyOS ships recent kernels and toolchains; `base-devel` and `nodejs` from your distro's repos are sufficient. No separate documentation path is required.

---

## CI reference

Official Linux builds run in GitHub Actions:

```yaml
# .github/workflows/main.yml (simplified)
renderer:  ubuntu-latest  → npm ci, make-index-files, build → artifact
package:   ubuntu-22.04   → download artifact, main build, electron-builder package
```

To reproduce a release-identical build locally, use the same Node version (24) and the commands in [Build steps](#build-steps).

## Troubleshooting builds

| Problem | Likely cause | Fix |
| ------- | ------------ | --- |
| `uiohook-napi` compile error | Missing compiler or X11 headers | Install `base-devel`, `libxtst`, `libx11` |
| `electron-builder` download fails | Network / proxy | Set `ELECTRON_MIRROR` or retry; check firewall |
| `renderer/dist` not found | Skipped renderer build | Run renderer `npm run build` before `main/npm run package` |
| AppImage does not start | FUSE not installed | `sudo pacman -S fuse2` (Arch) or extract with `--appimage-extract` |
| AppImage starts, black overlay | Compositor / GPU | See [Linux issues](/issues); try X11 or `--no-overlay` |
| Wrong architecture | Building on non-x64 | CI targets x86_64 only; ARM is unsupported |

## Related documentation

- [Development](/development) — dev workflow, testing, release process
- [Architecture](/architecture) — build pipeline overview
- [Download](/download) — official release artifacts
- [Command-line options](/cmd-flags) — `--no-overlay`, `--listen`, `--no-updates`
- [Common issues](/issues) — Linux runtime problems
