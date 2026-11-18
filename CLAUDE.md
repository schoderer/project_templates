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

Templates: `bevy`, `deno`, `elixir`, `elm`, `gm-campaign`, `go`, `godot`, `java_maven`, `node`, `python`, `python_ai`,
`rust`, `rust_esp32_riscv_embassy/rust_esp32_embassy`, `rust_godot`, `rust_pico2_embassy`.

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
- `rocm_image` (`python_ai`) — the `rocm/pytorch` base image; its `py3.X` must match `python314`
  in the flake and `requires-python`
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
- **CI.** `deno`, `elixir`, `elm`, `go`, `java_maven`, `node`, `python`, `python_ai` and `rust` ship an identical
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
- `python_ai` — Hugging Face models on AMD GPUs. Host: devShell (python 3.14, uv, ty, ruff) with a
  **CPU** torch from the PyTorch CPU index (`[tool.uv.sources]`, dev group) only for type checking.
  Execution: `just run <script>` in a podman container built from `Containerfile` (`rocm/pytorch` + uv)
  with the project mounted at `/workspace`. `container-entrypoint.sh` keeps the container venv on a
  named volume (`UV_PROJECT_ENVIRONMENT`), exposes the image's ROCm torch through a `.pth` file (not
  `--system-site-packages`, which misses torch when the image installs it into its own venv) and syncs
  with `--no-install-package torch …` so PyPI torch never shadows it. The justfile is rendered but
  avoids just's `{{ }}` (uses `set positional-arguments` + `$VAR`), so it needs no `_copy_without_render`.
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

## Verifying a change

There is nothing to build in this repo; verify by generating a project and building it there:

```bash
cookiecutter --no-input /workdir/project_templates --directory="rust" -o /tmp/out
cd "/tmp/out/rust-template" && nix flake check   # or: nix develop, just <recipe>
```

For templates with choice variables, check both branches, e.g.
`cookiecutter --no-input /workdir/project_templates --directory="rust" -o /tmp/out docker_image=no`.
