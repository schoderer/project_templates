# __NAME__

Python command line tool (click), packaged with nixpkgs `buildPythonApplication`.

```sh
__NAME__ greet           # Hello, world!
__NAME__ greet nix --shout
__NAME__ version
```

## Commands

Inside this folder (standalone flake):

```sh
nix develop                # python + click, pytest, mypy, ruff
nix build                  # binary -> result/bin/__NAME__ (runs pytest)
nix run . -- greet nix
nix flake check            # ruff, mypy, build + tests
```

From the repo root: `nix build .#__NAME__`, `nix run .#__NAME__ -- greet`.

In the dev shell, `pytest`, `mypy` and `python -m __NAME_SNAKE__` work straight
from the source tree, without installing the package.

## Adding a dependency

1. Add it to `dependencies` in `pyproject.toml`.
2. Add the nixpkgs package to `runtimeDeps` in `nix/default.nix` (test and
   dev-only packages go to `devDeps`).

## Files

- `nix/default.nix`: all build logic (binary, checks, dev shell)
- `flake.nix`: thin standalone wrapper around `nix/default.nix`
