# __NAME__

Rust HTTP service (axum), built with [crane](https://crane.dev).

| Route               | Response          |
| ------------------- | ----------------- |
| `GET /health`       | `ok`              |
| `GET /hello/{name}` | `Hello, {name}!`  |

The port comes from `PORT` (default `8080`).

## Commands

Inside this folder (standalone flake):

```sh
nix develop                # cargo, rustc, clippy, rustfmt, rust-analyzer, cargo-watch
nix build                  # binary  -> result/bin/__NAME__
nix build .#docker         # image   -> result (tar.gz)
nix flake check            # clippy, rustfmt, tests, build
```

From the repo root: `nix build .#__NAME__`, `nix build .#__NAME__-docker`, and
`just up` runs it with every other service on `localhost:__PORT__`.

Run the image:

```sh
docker load < result
docker run --rm -p 8080:8080 __NAME__:0.1.0
curl localhost:8080/hello/world
```

## Files

- `nix/default.nix`: all build logic (binary, image, checks, dev shell)
- `flake.nix`: thin standalone wrapper around `nix/default.nix`
- `Cargo.lock`: generated when the project was scaffolded; commit it
