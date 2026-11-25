# __NAME__

Language-agnostic service: a static file server (darkhttpd) serving `public/`.
Use it as is for static content, or as the starting point for a service in a
language without its own template.

| Route         | Response                 |
| ------------- | ------------------------ |
| `GET /health` | `ok` (`public/health`)   |
| `GET /`       | `public/index.html`      |

The port comes from `PORT` (default `8080`).

## Commands

Inside this folder (standalone flake):

```sh
nix develop                # darkhttpd, curl, shellcheck
nix build                  # binary -> result/bin/__NAME__
nix build .#docker         # image  -> result (tar.gz)
nix flake check            # HTTP smoke test, build
```

From the repo root: `nix build .#__NAME__`, `nix build .#__NAME__-docker`, and
`just up` runs it with every other service on `localhost:__PORT__`.

## Using another language

`nix/default.nix` documents the contract and shows a `stdenv.mkDerivation`
skeleton. Replace `bin` with your build (compiler in `nativeBuildInputs`, unit
tests in `checkPhase`), add the toolchain to `devShell`, and keep `docker`,
`compose` and the smoke test: they only need a binary serving HTTP on `$PORT`
with a `/health` route. If the language is used more than once, turn the
result into a new template under `templates/services/<lang>/`.

## Files

- `nix/default.nix`: all build logic (binary, image, checks, dev shell)
- `flake.nix`: thin standalone wrapper around `nix/default.nix`
- `public/`: served content
- `tests/smoke.sh`: HTTP smoke test used by `nix flake check`
