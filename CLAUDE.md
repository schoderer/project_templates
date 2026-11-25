# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of [cookiecutter](https://cookiecutter.readthedocs.io/) project templates, one per top-level
directory. There is no build, no test suite, and no application code here — every file is either
cookiecutter metadata or a Jinja2-rendered template of a file that ends up in a *generated* project.

Consumers generate a project by selecting a template directory:

```bash
cookiecutter git@github.com:schoderer/project_templates.git --directory="rust"
# nested case (note the two-level path):
cookiecutter git@github.com:schoderer/project_templates.git --directory="rust_esp32_riscv_embassy/rust_esp32_embassy"
```

Templates: `bevy`, `deno`, `elixir`, `elm`, `gm-campaign`, `go`, `godot`, `java_maven`, `node`, `python`, `rust`,
`rust_esp32_riscv_embassy/rust_esp32_embassy`, `rust_godot`, `rust_pico2_embassy`.

## Template anatomy

Each template is `<template>/cookiecutter.json` plus a `<template>/{{ cookiecutter.project_slug }}/`
directory whose contents are rendered into the new project. Every template's `cookiecutter.json`
follows the same shape, and `project_name` matches its directory (`bevy-template`, `go-template`,
`campaign-template`, …):

```json
{
  "project_name": "<something>-template",
  "project_slug": "{{ cookiecutter.project_name.lower().replace(' ', '_') }}"
}
```

Extra variables in use:

- `java_version` (`java_maven`, default `jdk23`)
- `esp_chip` (`rust_esp32_riscv_embassy`) — a JSON list, which cookiecutter turns into a choice prompt
- `docker_image` (`rust`) — `["yes", "no"]` choice gating the Docker parts of `flake.nix`/`justfile`
- `_copy_without_render` (`go`, `rust_pico2_embassy`) — see the Jinja pitfall below

`project_slug` is the variable most templates reference inside files (flake `description`, Docker
image name and `Entrypoint` path, `Readme.md` title). When adding a file that mentions the project by
name, use `{{ cookiecutter.project_slug }}` / `{{ cookiecutter.project_name }}` rather than hardcoding.

## The shared conventions every template follows

- **Nix flake per project.** `flake.nix` provides at minimum `devShells.default` with the language
  toolchain (`devShells.default`, never the deprecated `devShell` attribute). Rust-flavoured
  templates additionally build the binary with [crane] and expose `packages.default`/`packages.bin`,
  plus `packages.dockerImage` where Docker is enabled.
- **direnv.** `.envrc` is always exactly `use flake`; `.gitignore` always ignores `.direnv`.
- **justfile.** Task runner entry point. Every one starts with a `default: just --list` recipe; add
  project-specific recipes below it (see `rust` for perf/docker recipes, `go` for run/build/test,
  `bevy` for `run-dynamic`, `rust_pico2_embassy` for `defmt` log-level recipes).
- **Readme.md** is typically a single `# {{ cookiecutter.project_name }}` line.
- **CI.** `deno`, `elixir`, `elm`, `go`, `java_maven`, `node`, `python` and `rust` ship an identical
  `.github/workflows/nix-check.yml` running `nix flake check --print-build-logs` on every push/PR
  (`actions/checkout@v7` + `DeterminateSystems/determinate-nix-action`). Absent from `bevy`, `godot`,
  `rust_godot`, `gm-campaign` and the two embedded templates.

[crane]: https://github.com/ipetkov/crane

## Jinja pitfalls

Template files are rendered by Jinja2, so `{{ ... }}` in file *content* is interpreted. Two files hit
this and are therefore listed in `_copy_without_render` in their `cookiecutter.json`: the `justfile`
in `rust_pico2_embassy` (just's `{{LEVEL}}` interpolation) and the one in `go`
(`{{justfile_directory()}}`). Any new file containing literal braces (just variables, GitHub Actions
`${{ }}`, Handlebars, …) needs the same treatment — add it to `_copy_without_render` — or must escape
them as `{{ '{{' }}`.

The converse also applies: files that *are* rendered can use full Jinja control flow. `rust` wraps its
Docker image derivation and its `build-docker`/`dive-inspect` recipes in
`{%- if cookiecutter.docker_image == "yes" %} … {%- endif %}`, and inlines the same condition in the
`packages` attrset. A template cannot use both mechanisms on one file — putting a conditional in a
`_copy_without_render` file silently ships the raw Jinja.

## Notable templates

- `rust` — the reference for the Rust-flavoured templates. crane builds `bin` from `args`/
  `cargoArtifacts`; `checks` exposes `bin` plus a `cargoTest` derivation that reuses those artifacts,
  so `nix flake check` (and hence CI) both builds and tests. A comment there shows where to hang
  `cargoClippy`/`cargoFmt` gates. Docker support is optional via `docker_image`.
- `elm` — devShell-only (like `deno`): the flake just provides `elmPackages.elm`, `elm-language-server`,
  `elm-format`, `elm-test`, `elm-review`, `elm-live` and `nodejs`, and all compiling/testing happens
  through the justfile (`compile`, `release`, `dev`, `test`, `format`, `review`). Deliberately no
  `packages.default`: a nix build of an Elm app needs the `elm.json` deps pinned via `elm2nix`
  (`elm-srcs.nix` + `registry.dat` + `elmPackages.fetchElmDeps`), which has to be regenerated on
  every dependency change.
- `node` — devShell-only, a starting point for Vite apps (React, Svelte, …): the flake provides `nodejs`
  (npm included) and `typescript-language-server`, and the framework is chosen after generation with
  `npm create vite@latest .`. Node is still required because Vite itself runs on it. Deliberately no
  `packages.default`, for the same lockfile-hash reason as `elm`.
- `gm-campaign` — not code: a markdown scaffold (`campaign.md`, `players.md`, `threads.md`, `npcs/`,
  `factions/`, `locations/`, `sessions/`, `handouts/`) consumed by the `gm-prep`/`gm-recap`/
  `gm-review` skills. The `**System:**` line in `campaign.md` is read by those skills; the
  `_template.md` files are per-entity stubs, not cookiecutter machinery. It has no flake, `.envrc` or
  justfile.
- `rust_godot` — splits the generated project into `rust/` (the gdext crate) and `godot/` (the Godot
  project, incl. `rust.gdextension`); `godot` instead nests a second
  `{{ cookiecutter.project_slug }}/` directory holding the Godot project.
- `rust_esp32_riscv_embassy` — the only two-level template (`--directory` needs both segments).
  Along with `rust_pico2_embassy` it targets bare metal: probe-rs/`defmt` workflow, no CI.
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **library flake** with shared Nix build logic, plus `nix flake init` templates that use it. Projects add
this repo as a flake input (`project-templates`) and call e.g. `lib.rust.mkFlake { src = ./.; }`, so build
logic lives in one place and reaches projects through `nix flake update`. That replaces the old cookiecutter
approach, which copied the logic into each project once and let it drift. The legacy cookiecutter templates
are parked in `old/` (see below).

Version control is **jj** (colocated with git). Don't run `git add`/`git commit`; jj snapshots the working copy.

## Layout

```
flake.nix          # inputs (nixpkgs unstable, crane, rust-overlay) + outputs wiring
flake.lock
nix/rust.nix       # lib.rust.mkProject
templates/rust/    # plain files copied verbatim by `nix flake init -t .#rust`
old/               # legacy cookiecutter templates
```

Root flake outputs:

- `lib.rust.mkProject { pkgs, src, … }` returns `{ packages, checks, devShell }` for one system. This is the
  same contract as `old/mono`'s `nix/default.nix`, so a monorepo can call it per project. It accepts plain
  nixpkgs and applies rust-overlay itself.
- `lib.rust.mkFlake { src, systems ? …, … }` wraps `mkProject` per system into `packages`/`checks`/
  `devShells.default`. Consumers have no per-system `pkgs`, so `nativeBuildInputs`, `buildInputs`,
  `craneArgs`, `docker` and `extraChecks` may also be functions `pkgs -> value` (`resolve` in
  `nix/rust.nix`). Keep that convention for new options that reference packages.
- `templates.<lang>` with a `welcomeText`.
- `checks.<system>.<lang>-template-*` is the **self-test**: it builds each template through the lib (Rust:
  bin, test, clippy, fmt, and dockerImage on Linux).
- `formatter` (nixfmt).

All options and outputs are documented in `Readme.md`. Keep it in sync when changing the lib.

Systems: `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`. nixpkgs-unstable has dropped `x86_64-darwin`.

## Templates (`templates/<lang>/`)

- These are **not** rendered: no Jinja and no variables. `nix flake init` copies them verbatim. Anything
  name-dependent comes from the project's own metadata (Rust: `pname` from `Cargo.toml` through crane), and
  the template ships a placeholder (`name = "app"`) that the `welcomeText` tells the user to rename.
- A template's `flake.nix` is a thin consumer: `inputs.project-templates.url =
  "github:schoderer/project_templates"` plus one `lib.<lang>.mkFlake` call with commented-out options.
- Ship a valid lockfile (`Cargo.lock`) so the self-test can build.
- Conventions carried over from the old templates: `.envrc` is `use flake`, `.gitignore` ignores `.direnv`
  and `result*`, the `justfile` starts with `default: just --list`, and `.github/workflows/nix-check.yml` runs
  `nix flake check --print-build-logs`.

### Adding a language

1. `nix/<lang>.nix` exporting `mkProject` with the same `{ packages, checks, devShell }` contract.
2. Wire `lib.<lang>` (+ `mkFlake`) and `templates.<lang>` in `flake.nix`, and add `<lang>-template-*` checks.
3. `templates/<lang>/` holds plain files, ported from `old/<lang>/{{ cookiecutter.project_slug }}/` with the
   Jinja removed.
4. Document it in `Readme.md`.

Languages with lockfile-hash builds (Go `vendorHash`, Elixir `mixFodDeps`, Elm/Node) need a hash option in
`mkProject`. That's why only Rust is ported so far.

## Verifying a change

There is nothing to build in this repo; verify by generating a project and building it there:

```bash
cookiecutter --no-input /workdir/project_templates --directory="rust" -o /tmp/out
cd "/tmp/out/rust-template" && nix flake check   # or: nix develop, just <recipe>
```

For templates with choice variables, check both branches, e.g.
`cookiecutter --no-input /workdir/project_templates --directory="rust" -o /tmp/out docker_image=no`.
