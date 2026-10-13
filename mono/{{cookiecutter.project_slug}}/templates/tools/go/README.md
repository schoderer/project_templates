# __NAME__

Go command line tool (standard library `flag`), built with nixpkgs `buildGoModule`.

```sh
__NAME__ greet           # Hello, world!
__NAME__ greet --shout nix
__NAME__ version
```

## Commands

Inside this folder (standalone flake):

```sh
nix develop                # go, gopls, goimports
nix build                  # binary -> result/bin/__NAME__ (runs go test)
nix run . -- greet nix
nix flake check            # gofmt, go vet, build + tests
```

From the repo root: `nix build .#__NAME__`, `nix run .#__NAME__ -- greet`.

## Adding a dependency

1. `go get example.com/some/module` in the dev shell (creates `go.sum`).
2. In `nix/default.nix` set `vendorHash = lib.fakeHash;`, run `nix build`, and
   replace it with the hash printed in the error (`got: sha256-...`).
3. Repeat step 2 whenever `go.sum` changes.

## Files

- `nix/default.nix`: all build logic (binary, checks, dev shell)
- `flake.nix`: thin standalone wrapper around `nix/default.nix`
