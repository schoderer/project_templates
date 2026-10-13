# __NAME__

TypeScript command line tool (Node `node:util` parseArgs), built with nixpkgs
`buildNpmPackage`.

```sh
__NAME__ greet           # Hello, world!
__NAME__ greet --shout nix
__NAME__ version
```

## Commands

Inside this folder (standalone flake):

```sh
nix develop                # node, tsc, biome
nix build                  # binary -> result/bin/__NAME__ (runs tsc + node --test)
nix run . -- greet nix
nix flake check            # biome, build + tests
```

From the repo root: `nix build .#__NAME__`, `nix run .#__NAME__ -- greet`.

In the dev shell: `npm install` once, then `npm run build`, `npm test` and
`npm run check` work as usual. `tsc` and `biome` come from nixpkgs, not npm.

## Adding a dependency

`npm install <package>` in the dev shell and commit the updated
`package-lock.json`. Nix reads the lock file directly, so there is no hash to
update.

## Files

- `nix/default.nix`: all build logic (binary, checks, dev shell)
- `flake.nix`: thin standalone wrapper around `nix/default.nix`
- `package-lock.json`: generated when the project was scaffolded; commit it
