# CLAUDE.md

{{ cookiecutter.project_name }}: Nix multi-project monorepo for services and
tools in several languages. README.md has the full picture; this file lists
what matters when changing the repo.

## Layout

- `flake.nix`: root flake (flake-parts), imports the modules in `nix/`.
- `nix/lib.nix`: project discovery + contract validation.
- `nix/projects.nix`: packages, checks, dev shells, aggregates (`default`,
  `services`, `tools`, `docker`); passes `monorepo = { services, tools, projects }`
  to other perSystem modules.
- `nix/compose.nix`: `packages.compose`, `apps.up`/`apps.down`; shared
  infrastructure (databases, ...) goes into `infrastructure` there.
- `nix/apps.nix`: `new-service`, `new-tool` (scaffolder), `sync-locks`, `docker-load`.
- `nix/treefmt.nix`: `nix fmt` (nixfmt, rustfmt, ruff, gofmt, biome, shellcheck).
- `services/<name>/`, `tools/<name>/`: projects; `templates/<kind>/<lang>/`:
  skeletons (rust, python, go, typescript, generic); `documents/`: docs + ADRs.

## Project contract

Each project's `nix/default.nix` is `{ pkgs, inputs }: { packages, checks, devShell, compose? }`.
`packages.default` (binary) is required; services also need `packages.docker`
and may set `compose`; tools must not have either. All build logic lives there;
the project's `flake.nix` is only a standalone wrapper and must declare only
inputs the root flake also has (`nixpkgs`, `crane`).

Service conventions: listen on `$PORT` (8080 in the image), `GET /health` -> `ok`,
exit on SIGTERM, image `<name>:<version>` running as `nobody`,
`compose.ports = [ "<host port>:8080" ]` with a unique host port.

## Working rules

- Create projects with `just new-service <lang> <name>` / `just new-tool <lang> <name>`,
  never by hand-copying: the scaffolder fills placeholders (`__NAME__`,
  `__NAME_SNAKE__`, `__DIR__`, `__PORT__`), assigns the port, locks the
  project flake, runs the template's `scaffold.sh` and stages the files.
- New files must be `git add`ed before nix can see them.
- After changing root inputs or `flake.lock` (`just update`), run
  `nix run .#sync-locks`; CI fails on drift.
- Project names must be unique across `services/` and `tools/` and not clash
  with root outputs (`default`, `docker`, `compose`, `up`, ... see `reserved`
  in `nix/projects.nix`).
- Dependencies: Python from nixpkgs (`runtimeDeps` in `nix/default.nix` +
  `pyproject.toml`); TypeScript via `npm install` (lock read by `importNpmLock`,
  `tsc`/`biome` come from nixpkgs); Go needs `vendorHash` updated once go.sum
  exists; Rust via Cargo.lock (crane).
- When adding a language template, also add its formatter to `nix/treefmt.nix`.

## Verify

`just ci` (sync-locks check, `nix flake check`, all binaries and images), plus
`just fmt` before committing. For services, `just up -d` and
`curl localhost:<port>/health`, then `just down`.
