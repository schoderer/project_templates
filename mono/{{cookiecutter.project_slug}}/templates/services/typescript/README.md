# __NAME__

TypeScript HTTP service (Node `node:http`, no runtime dependencies), built with
nixpkgs `buildNpmPackage`.

| Route               | Response          |
| ------------------- | ----------------- |
| `GET /health`       | `ok`              |
| `GET /hello/{name}` | `Hello, {name}!`  |

The port comes from `PORT` (default `8080`).

## Commands

Inside this folder (standalone flake):

```sh
nix develop                # node, tsc, biome
nix build                  # binary -> result/bin/__NAME__ (runs tsc + node --test)
nix build .#docker         # image  -> result (tar.gz)
nix flake check            # biome, build + tests
```

From the repo root: `nix build .#__NAME__`, `nix build .#__NAME__-docker`, and
`just up` runs it with every other service on `localhost:__PORT__`.

In the dev shell: `npm install` once, then `npm run build`, `npm test` and
`npm run check` work as usual. `tsc` and `biome` come from nixpkgs, not npm.

## Adding a dependency

`npm install <package>` in the dev shell and commit the updated
`package-lock.json`. Nix reads the lock file directly, so there is no hash to
update.

## Files

- `nix/default.nix`: all build logic (binary, image, checks, dev shell)
- `flake.nix`: thin standalone wrapper around `nix/default.nix`
- `package-lock.json`: generated when the project was scaffolded; commit it
