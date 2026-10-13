# __NAME__

Language-agnostic tool: a bash script packaged with `writeShellApplication`
(shellcheck runs at build time). Use it as is for scripts, or as the starting
point for a tool in a language without its own template.

```sh
__NAME__ greet           # Hello, world!
__NAME__ greet --shout nix
__NAME__ version
```

## Commands

Inside this folder (standalone flake):

```sh
nix develop                # shellcheck
nix build                  # binary -> result/bin/__NAME__
nix run . -- greet nix
nix flake check            # tests, build (shellcheck)
```

From the repo root: `nix build .#__NAME__`, `nix run .#__NAME__ -- greet`.

## Using another language

`nix/default.nix` documents the contract and shows a `stdenv.mkDerivation`
skeleton. Replace `bin` with your build (compiler in `nativeBuildInputs`, unit
tests in `checkPhase`) and add the toolchain to `devShell`; `tests/test.sh`
keeps working against any binary with the same command line. If the language
is used more than once, turn the result into a new template under
`templates/tools/<lang>/`.

## Files

- `nix/default.nix`: all build logic (binary, checks, dev shell)
- `flake.nix`: thin standalone wrapper around `nix/default.nix`
- `src/main.sh`: the tool
- `tests/test.sh`: black-box tests used by `nix flake check`
