# Developing Exiled Exchange 2

The canonical developer documentation lives in the **VitePress docs site** (also in `docs/`):

- [Architecture](https://kvan7.github.io/Exiled-Exchange-2/architecture) — [`docs/architecture.md`](./docs/architecture.md)
- [Development guide](https://kvan7.github.io/Exiled-Exchange-2/development) — [`docs/development.md`](./docs/development.md)
- [Building for Linux (incl. Arch)](https://kvan7.github.io/Exiled-Exchange-2/building-linux) — [`docs/building-linux.md`](./docs/building-linux.md)
- [Item capture from game](https://kvan7.github.io/Exiled-Exchange-2/item-capture) — [`docs/item-capture.md`](./docs/item-capture.md)

## Quick start

Matches CI (Node 24, `npm ci`):

```shell
cd renderer
npm ci
npm run make-index-files
npm run dev

# second terminal
cd main
npm ci
npm run dev
```

Build and package: see [Development → Building for production](./docs/development.md#building-for-production) or run `sh testUpdate.sh` after reading the script.

Release process: see [Development → Release process](./docs/development.md#release-process).
