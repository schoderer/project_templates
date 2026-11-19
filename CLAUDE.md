# CLAUDE.md

Cookiecutter templates, one per top-level directory (`<template>/cookiecutter.json` +
`<template>/{{ cookiecutter.project_slug }}/`). Nothing to build here. `rust_esp32_riscv_embassy` is
two levels deep (`--directory="rust_esp32_riscv_embassy/rust_esp32_embassy"`). `mono` is a much bigger
template with hooks and a self-test; see its own `CLAUDE.md`/`README.md`.

## Conventions for new/changed templates

- `project_name` default is `<dir>-template`; refer to the project via `{{ cookiecutter.project_slug }}`,
  never hardcode it.
- `flake.nix` exposes `devShells.default` (not the deprecated `devShell`); `.envrc` is exactly
  `use flake`; `.gitignore` ignores `.direnv`.
- Every `justfile` starts with `default: just --list`.
- Templates with a meaningful `nix flake check` ship the shared `.github/workflows/nix-check.yml`.

## Jinja pitfalls

All file content is rendered by Jinja2. Files with literal `{{ }}` (just interpolation, GitHub Actions
`${{ }}`, …) must be listed in `_copy_without_render` or escaped as `{{ '{{' }}`. A file can't use both:
Jinja conditionals in a `_copy_without_render` file ship raw. Alternative used by `python_ai`'s
justfile: avoid just's braces (`set positional-arguments`, `"$@"`, exported `$VAR`s).

## Non-obvious decisions

- `elm` and `node` deliberately have no `packages.default`: a Nix build would need lockfile-derived
  hashes (`elm2nix`, npm deps hash) regenerated on every dependency change.
- `python_ai`: torch comes from the `rocm/pytorch` image, never PyPI. The container venv lives on a
  named volume (host `.venv` is linked against Nix python), sees the image's torch via a `.pth` file
  (`--system-site-packages` misses it when the image installs torch into its own venv), and syncs
  with `--no-install-package torch …` because `accelerate`/`timm` pull torch transitively. The host
  gets CPU torch only for `ty`. GPU selection (e.g. hiding an APU's iGPU) is `ROCR_VISIBLE_DEVICES`
  with UUIDs in `.env` (`set dotenv-load`). Image `py3.X` must match `python314` in the flake and `requires-python`.
- `gm-campaign` is a markdown scaffold read by the `gm-prep`/`gm-recap`/`gm-review` skills (they parse
  the `**System:**` line in `campaign.md`); its `_template.md` files are entity stubs, not cookiecutter
  machinery.

## Verifying a change

Generate and build the result; for choice variables test every branch:

```bash
cookiecutter --no-input . --directory="rust" -o /tmp/out [docker_image=no]
cd /tmp/out/rust-template && nix flake check
```
