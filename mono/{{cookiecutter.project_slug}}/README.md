# {{ cookiecutter.project_name }}

{{ cookiecutter.project_description }}.

A Nix monorepo: one root flake orchestrates many independent projects, each
with its own flake, tooling, builds and checks. Services and tools can be
written in any language; templates exist for Rust, Python, Go, TypeScript,
Java (Maven, services only) and a generic starting point for everything else.

```
.
├── flake.nix          root flake: discovers and aggregates every project
├── justfile           shortcuts for everything below (`just` lists them)
├── nix/               root flake modules (discovery, outputs, apps, compose, formatting)
├── documents/         architecture and business documentation, ADRs
├── services/          deployable projects: binary + docker image
├── tools/             CLI tools: binary only
└── templates/         skeletons for new projects, one per kind and language
    ├── services/{rust,python,go,typescript,java_maven,generic}/
    └── tools/{rust,python,go,typescript,generic}/
```

## Requirements

Nix with flakes enabled (`experimental-features = nix-command flakes`), git,
and docker for running images locally. Optionally
[direnv](https://direnv.net) + nix-direnv. Supported systems:
{% for system in cookiecutter.systems.split(",") %}`{{ system }}`{{ ", " if not loop.last else "." }}{% endfor %}

Everything else (compilers, linters, `just`) comes from the dev shells.

## Getting started

```sh
nix develop                        # or `direnv allow`; provides just + all project tooling
just new-service go billing-api    # services/billing-api from templates/services/go
just new-tool python release-notes # tools/release-notes from templates/tools/python
just check                         # every check of every project
just up                            # run every service locally, see ports below
```

`just templates` lists the available languages. Every service gets a host
port for local runs when it is created (8081, 8082, ...); it is stored in its
`nix/default.nix` (`compose.ports`) and printed in its README.

## Templates

| Language     | Service                         | Tool                    | Built with                       |
| ------------ | ------------------------------- | ----------------------- | -------------------------------- |
| `rust`       | axum                            | clap                    | crane                            |
| `python`     | FastAPI + uvicorn               | click                   | `buildPythonApplication`         |
| `go`         | `net/http`                      | `flag`                  | `buildGoModule`                  |
| `typescript` | `node:http`                     | `node:util` parseArgs   | `buildNpmPackage` + `importNpmLock` |
| `java_maven` | `com.sun.net.httpserver`        | (none yet)              | `maven.buildMavenPackage`, jlink'ed JRE |
| `generic`    | static files (darkhttpd)        | bash script             | adapt `bin` to any language      |

Every service serves `GET /health` on `$PORT` (8080 in the image), shuts down
on SIGTERM and ships a docker image; every tool has `greet` and `version`
commands. All of them have unit tests and linters wired into `nix flake check`.

## Everyday commands (repo root)

| just                         | nix                                    | What it does                                 |
| ---------------------------- | -------------------------------------- | -------------------------------------------- |
| `just build [name]`          | `nix build [.#<name>]`                 | every binary → `result/bin`, or one project  |
| `just docker [name]`         | `nix build .#docker` / `.#<name>-docker` | every service image → `result/<name>.tar.gz` |
| `just check`                 | `nix flake check`                      | every project's checks + formatting          |
| `just check-one <check>`     | `nix build .#checks.<system>.<check>`  | one check, e.g. `billing-api-test`           |
| `just fmt`                   | `nix fmt`                              | format nix, rust, python, go, java, ts/json, shell |
| `just run <name> <args>`     | `nix run .#<name> -- <args>`           | run one project                              |
| `just dev [name]`            | `nix develop [.#<name>]`               | shell with all tooling, or one project's     |
| `just up [args]` / `just down` | `nix run .#up` / `.#down`            | run every service with docker compose        |
| `just new-service <lang> <name>` | `nix run .#new-service -- <lang> <name>` | scaffold `services/<name>`             |
| `just new-tool <lang> <name>`    | `nix run .#new-tool -- <lang> <name>`    | scaffold `tools/<name>`                |
| `just update`                | `nix flake update` + `sync-locks`      | update nixpkgs & co. for every project       |
| `just ci`                    |                                        | everything CI runs                           |

Pass extra nix flags with `just flags=-L check`. Every project folder is also
a standalone flake: `cd services/billing-api && nix build .#docker` works
without the root.

> Flakes only see files tracked by git. `git add` new files before building
> (the scaffolding apps do this for you).

## How it fits together

Each project has a `nix/default.nix` implementing a small contract:

```nix
{ pkgs, inputs }:
{
  packages = { default = <binary>; docker = <image>; };   # docker: services only
  checks   = { ... };                                     # run by `nix flake check`
  devShell = <mkShell>;                                   # `nix develop .#<name>`
  compose  = { ports = [ "8081:8080" ]; ... };            # services only, optional
}
```

- The **root flake** (`nix/lib.nix`, `nix/projects.nix`) reads `services/`
  and `tools/`, imports every `*/nix/default.nix` with the root's `pkgs` and
  `inputs`, validates the contract and builds the aggregate outputs. Adding a
  project never requires editing the root.
- The **project flake** (`<project>/flake.nix`) calls the same function, so
  standalone and monorepo builds share one definition.
- **One pin**: project flakes may only declare inputs the root also has.
  `nix run .#sync-locks` locks them to exactly the root's revisions; CI fails
  when they drift (`sync-locks --check`).
- **Local runs** (`nix/compose.nix`): every service becomes a docker compose
  service running its nix-built image, extended by its `compose` attribute.
  Shared infrastructure such as a database goes into `infrastructure` there.

See [services/README.md](services/README.md) and [tools/README.md](tools/README.md)
for the contract details.

## Adding a language

1. Create `templates/services/<lang>/` and/or `templates/tools/<lang>/`
   (start from a copy of `generic` or the closest language). Use the
   placeholders `__NAME__`, `__NAME_SNAKE__`, `__DIR__` and, for services,
   `__PORT__`; the scaffolder replaces them in file names and contents.
2. Optional `scaffold.sh`: runs once in the new project's dev shell (e.g. to
   generate a lock file) and is deleted afterwards.
3. Add the language's formatter to `nix/treefmt.nix`.
4. Scaffold a throwaway project and run `just ci` before committing.

## CI

`.github/workflows/ci.yml` runs on one native runner per supported system:
lock drift check, `nix flake check`, and `nix build .#default .#docker`.
