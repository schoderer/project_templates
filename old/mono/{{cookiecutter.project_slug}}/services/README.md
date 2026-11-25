# Services

Deployable projects. Each one ships a **binary** and a **docker image**.

The root flake finds every `services/<name>/` that contains `nix/default.nix`;
nothing else has to be registered. Folders starting with `.` or `_` are skipped.

## Adding a service

```sh
just new-service <lang> <name>     # or: nix run .#new-service -- <lang> <name>
just templates                     # available languages
```

This copies `templates/services/<lang>/`, assigns the next free host port for
`just up`, creates the project's `flake.lock` (pinned to the root) and stages
everything in git.

## Contract

`services/<name>/nix/default.nix` is a function:

```nix
{ pkgs, inputs }:          # nixpkgs for the system, root flake inputs
{
  packages = {
    default = <binary>;    # required
    docker  = <image>;     # required (dockerTools.buildLayeredImage)
  };
  checks   = { ... };      # anything that must pass in `nix flake check`
  devShell = <mkShell>;    # tooling for `nix develop`
  compose  = { ... };      # optional: docker compose keys for `just up`
}
```

Conventions shared by all templates (keep them for new languages):

- listen on `0.0.0.0:$PORT`; the image sets `PORT=8080`
- `GET /health` returns `ok`
- exit cleanly on SIGTERM (`docker stop`, `just down`)
- image named `<name>:<version>`, runs as `nobody`, OCI title/version labels
- `compose.ports = [ "<host port>:8080" ]`; add `environment`, `depends_on`, ...
  as needed. Shared infrastructure (databases, queues) is declared once in
  `nix/compose.nix`.

`services/<name>/flake.nix` is a thin wrapper that calls the same function so
the service also builds on its own (`cd services/<name> && nix build`). It may
only declare inputs the root flake also has (currently `nixpkgs`, `crane`).

## What the root flake makes of it

| Root command                    | Includes                               |
| ------------------------------- | -------------------------------------- |
| `nix build`                     | `packages.default` of every project    |
| `nix build .#services`          | `packages.default` of every service    |
| `nix build .#docker`            | `packages.docker` as `<name>.tar.gz`   |
| `nix build .#<name>[-docker]`   | one service                            |
| `nix flake check`               | `checks.*` as `<name>-<check>` + build |
| `nix develop .#<name>`          | `devShell`                             |
| `nix run .#up` / `just up`      | every image, configured by `compose`   |
