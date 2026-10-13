# __NAME__

Rust command line tool (clap), built with [crane](https://crane.dev).

```sh
__NAME__ greet           # Hello, world!
__NAME__ greet nix --shout
__NAME__ version
```

## Commands

Inside this folder (standalone flake):

```sh
nix develop                # cargo, rustc, clippy, rustfmt, rust-analyzer, cargo-watch
nix build                  # binary -> result/bin/__NAME__
nix run . -- greet nix
nix flake check            # clippy, rustfmt, tests, build
```

From the repo root: `nix build .#__NAME__`, `nix run .#__NAME__ -- greet`.

## Files

- `nix/default.nix`: all build logic (binary, checks, dev shell)
- `flake.nix`: thin standalone wrapper around `nix/default.nix`
- `Cargo.lock`: generated when the project was scaffolded; commit it
