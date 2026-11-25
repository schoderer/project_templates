# Tools

Internal command line tools (developer utilities, ops scripts, codegen, ...).
Same as services, but **without a docker image**.

The root flake finds every `tools/<name>/` that contains `nix/default.nix`;
nothing else has to be registered. Folders starting with `.` or `_` are skipped.

## Adding a tool

```sh
just new-tool <lang> <name>        # or: nix run .#new-tool -- <lang> <name>
just templates                     # available languages
```

This copies `templates/tools/<lang>/`, creates the project's `flake.lock`
(pinned to the root) and stages everything in git.

## Contract

`tools/<name>/nix/default.nix` is a function:

```nix
{ pkgs, inputs }:          # nixpkgs for the system, root flake inputs
{
  packages.default = <binary>;   # required; packages.docker and compose are rejected
  checks   = { ... };            # anything that must pass in `nix flake check`
  devShell = <mkShell>;          # tooling for `nix develop`
}
```

`tools/<name>/flake.nix` is a thin wrapper that calls the same function so the
tool also builds on its own (`cd tools/<name> && nix build`). It may only
declare inputs the root flake also has.

## What the root flake makes of it

| Root command                  | Includes                               |
| ----------------------------- | -------------------------------------- |
| `nix build`                   | `packages.default` of every project    |
| `nix build .#tools`           | `packages.default` of every tool       |
| `nix build .#<name>`          | one tool                               |
| `nix run .#<name> -- <args>`  | run one tool                           |
| `nix flake check`             | `checks.*` as `<name>-<check>` + build |
| `nix develop .#<name>`        | `devShell`                             |
