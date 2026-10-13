# __NAME__

Go HTTP service (standard library `net/http`), built with nixpkgs `buildGoModule`.

| Route               | Response          |
| ------------------- | ----------------- |
| `GET /health`       | `ok`              |
| `GET /hello/{name}` | `Hello, {name}!`  |

The port comes from `PORT` (default `8080`).

## Commands

Inside this folder (standalone flake):

```sh
nix develop                # go, gopls, goimports
nix build                  # binary -> result/bin/__NAME__ (runs go test)
nix build .#docker         # image  -> result (tar.gz)
nix flake check            # gofmt, go vet, build + tests
```

From the repo root: `nix build .#__NAME__`, `nix build .#__NAME__-docker`, and
`just up` runs it with every other service on `localhost:__PORT__`.

## Adding a dependency

1. `go get example.com/some/module` in the dev shell (creates `go.sum`).
2. In `nix/default.nix` set `vendorHash = lib.fakeHash;`, run `nix build`, and
   replace it with the hash printed in the error (`got: sha256-...`).
3. Repeat step 2 whenever `go.sum` changes.

## Files

- `nix/default.nix`: all build logic (binary, image, checks, dev shell)
- `flake.nix`: thin standalone wrapper around `nix/default.nix`
