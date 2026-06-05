---
title: Command-line options
---

# Command-line options


- `--no-overlay`
  Disables the creation of the Overlay Window completely.
  Opens the UI in your default browser instead. Useful on Linux when the transparent overlay does not work.
  Hotkeys and clipboard capture still run in the Electron main process.

- `--listen=[host][:port]`
  Changes the listening address for the built-in HTTP/WebSocket server.
  Useful when a VPN client blocks connections to `127.0.0.1`, or when you need a fixed port.
  Use `--listen=0.0.0.0` to bind all interfaces (see [Architecture → Security](/architecture#security-and-trust-boundaries)).
  In production, the port defaults to **ephemeral** (`0`) unless specified — use e.g. `--listen=127.0.0.1:8584` to bookmark the browser UI in `--no-overlay` mode.

- `--no-updates` Disables automatic downloading of updates and, consequently,
their installation.

Since this tool is built on top of Electron/Chromium,
it also inherits all [their command-line options](https://www.electronjs.org/docs/latest/api/command-line-switches).
