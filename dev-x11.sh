#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# uiohook talks to X11 directly; Electron --ozone-platform=x11 still runs via XWayland
# on a Wayland session. DISPLAY must point at that XWayland server.
if [[ -z "${DISPLAY:-}" ]] && command -v systemctl >/dev/null 2>&1; then
  DISPLAY="$(systemctl --user show-environment 2>/dev/null | sed -n 's/^DISPLAY=//p' | head -1)"
  if [[ -n "$DISPLAY" ]]; then
    export DISPLAY
  fi
fi

if [[ -z "${DISPLAY:-}" ]]; then
  echo "DISPLAY is not set. uiohook cannot capture keyboard input without an X11 display." >&2
  echo "Start this script from a desktop terminal (Konsole), not a headless/SSH session." >&2
  exit 1
fi

REAL_SESSION_TYPE="${XDG_SESSION_TYPE:-}"
export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11

RENDERER_PID=""
MAIN_PID=""

cleanup() {
  if [[ -n "$MAIN_PID" ]]; then
    kill "$MAIN_PID" 2>/dev/null || true
    wait "$MAIN_PID" 2>/dev/null || true
  fi
  if [[ -n "$RENDERER_PID" ]]; then
    kill "$RENDERER_PID" 2>/dev/null || true
    wait "$RENDERER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

port_open() {
  node -e "
    const net = require('net');
    const port = Number(process.argv[1]);
    const hosts = ['127.0.0.1', '::1'];
    function tryHost(i) {
      if (i >= hosts.length) return process.exit(1);
      const s = net.connect(port, hosts[i], () => { s.end(); process.exit(0); });
      s.setTimeout(500);
      s.on('timeout', () => { s.destroy(); tryHost(i + 1); });
      s.on('error', () => tryHost(i + 1));
    }
    tryHost(0);
  " "$1"
}

wait_for_port() {
  local port=$1
  local label=$2
  local attempts=0
  while ! port_open "$port"; do
    attempts=$((attempts + 1))
    if (( attempts > 120 )); then
      echo "Timed out waiting for $label on port $port" >&2
      exit 1
    fi
    sleep 0.5
  done
  echo "$label ready on port $port"
}

echo "Session: real=${REAL_SESSION_TYPE:-unset} exported XDG_SESSION_TYPE=$XDG_SESSION_TYPE DISPLAY=$DISPLAY"
if [[ "${REAL_SESSION_TYPE:-}" == "wayland" ]]; then
  echo "Note: real session is Wayland; uiohook still needs a working XWayland DISPLAY." >&2
  echo "If hotkeys fail, install: sudo pacman -S --needed libxkbcommon-x11 libxkbfile libxtst" >&2
fi

# Start both processes. Vite proxies /config to the main process on :8584, so the
# Electron HTTP server must be up before the renderer page loads.
cd "$ROOT/main"
npm run dev -- --ozone-platform=x11 --force-device-scale-factor=1 &
MAIN_PID=$!

cd "$ROOT/renderer"
npm run dev &
RENDERER_PID=$!

wait_for_port 8584 "Electron IPC"
wait_for_port 5173 "Vite"

echo "Dev servers ready — Electron overlay should open shortly."
wait "$MAIN_PID"
