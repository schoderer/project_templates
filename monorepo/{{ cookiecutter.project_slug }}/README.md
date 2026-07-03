# Multi-service monorepo for {{ cookiecutter.project_name }} — flake-parts + import-tree

One flake, one `flake.lock`. Each service contributes a flake-parts module
(`services/<name>/nix.nix`) that is auto-discovered by import-tree.
Adding a service = adding a directory. No central file is ever edited.

## Commands

```
nix build .#api                # build one service
nix build .#all                # build everything (also .#default)
nix build .#docker-images      # build all dockerimages
nix develop .#billing          # focused shell for one service
nix develop                    # combined shell, all toolchains
nix fmt                        # format the whole repo (treefmt)
nix flake check                # CI entry point: builds all services + all checks
nix run .#api                  # run a service binary
```

## Conventions

- **Module discovery:** every `*.nix` under `nix/` and `services/` is loaded
  as a flake-parts module. Files or directories starting with `_` are skipped —
  use that prefix for `callPackage` files, snippets, WIP.
- **Source filtering:** each `_package.nix` uses `lib.fileset` so a service's
  derivation only depends on its own files. Changing one service never
  rebuilds another.
- **Cross-service references:** inside any `perSystem`, other services are
  reachable via `config.packages.<name>` / `config.devShells.<name>` —
  no exports, no plumbing.

## Adding a service

1. `mkdir services/frontend`
2. Write `services/frontend/nix.nix` with a `perSystem` contributing
   `packages.frontend` (+ optionally `devShells.frontend`, `checks.*`).
3. Done. It appears in `nix build .#all`, `nix flake check`, and the root shell.

## First-build notes

- `services/billing/_package.nix` has `mvnHash = lib.fakeHash;`.
  The first `nix build .#billing` fails and prints the real hash — paste it in.
  Repeat whenever `pom.xml` dependencies change.
- The Rust service builds as-is (`cargoLock.lockFile`, no hash dance).
