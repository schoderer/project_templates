# __NAME__

Python HTTP service (FastAPI + uvicorn), packaged with nixpkgs
`buildPythonApplication`.

| Route               | Response          |
| ------------------- | ----------------- |
| `GET /health`       | `ok`              |
| `GET /hello/{name}` | `Hello, {name}!`  |
| `GET /docs`         | OpenAPI UI        |

The port comes from `PORT` (default `8080`).

## Commands

Inside this folder (standalone flake):

```sh
nix develop                # python + fastapi, uvicorn, pytest, httpx2, mypy, ruff
nix build                  # binary -> result/bin/__NAME__ (runs pytest)
nix build .#docker         # image  -> result (tar.gz)
nix flake check            # ruff, mypy, build + tests
```

In the dev shell, `python -m __NAME_SNAKE__`, `pytest` and `mypy` work straight
from the source tree.

From the repo root: `nix build .#__NAME__`, `nix build .#__NAME__-docker`, and
`just up` runs it with every other service on `localhost:__PORT__`.

## Adding a dependency

1. Add it to `dependencies` in `pyproject.toml`.
2. Add the nixpkgs package to `runtimeDeps` in `nix/default.nix` (test and
   dev-only packages go to `devDeps`).

## Files

- `nix/default.nix`: all build logic (binary, image, checks, dev shell)
- `flake.nix`: thin standalone wrapper around `nix/default.nix`
