# Nix monorepo cookiecutter template

Generates the starting point for a new platform: a Nix multi-project monorepo
whose root flake (flake-parts) auto-discovers every project in `services/`
(binary + docker image) and `tools/` (binary), with

- language templates for services and tools: Rust, Python, Go, TypeScript and
  a generic one for any other language (`just new-service <lang> <name>`),
- one-command build, check, format and local run of everything
  (`just build`, `just docker`, `just check`, `just fmt`, `just up`),
- a single pinned nixpkgs for all projects, direnv, GitHub Actions CI,
- `documents/` with an ADR template and the first ADR.

```sh
cookiecutter path/to/this/template          # or: cookiecutter gh:<org>/<repo> --directory <dir>
cd my-platform
nix develop                                 # or: direnv allow
just new-service go billing-api
just check && just up
```

## Variables (`cookiecutter.json`)

| Variable              | Default                        | Used for                                         |
| --------------------- | ------------------------------ | ------------------------------------------------ |
| `project_name`        | `My Platform`                  | README / CLAUDE.md title                         |
| `project_slug`        | derived from `project_name`    | directory and compose project name (kebab-case) |
| `project_description` | `Services and tools of …`      | root flake `description`, README                 |
| `nixpkgs_branch`      | `nixos-unstable`               | nixpkgs pin of the root flake and project templates |
| `systems`             | x86_64 + aarch64 Linux         | `systems` of all flakes, CI runner matrix        |
| `include_github_ci`   | `true`                         | keeps or removes `.github/`                      |
| `init_git`            | `true`                         | `git init` + `git add -A` (flakes need tracked files) |
| `lock_flake`          | `true`                         | runs `nix flake lock` when nix is installed      |

## Layout

```
cookiecutter.json
hooks/
  pre_gen_project.py     validates project_slug and nixpkgs_branch
  post_gen_project.py    removes CI if disabled, git init, nix flake lock
scripts/
  test-template.sh       end-to-end self-test (see below)
{{cookiecutter.project_slug}}/   the generated monorepo
  templates/<kind>/<lang>/       project skeletons, copied by `just new-service/new-tool`
```

The generated project starts without services or tools; its README documents
the commands, the project contract and how to add a language.

## Placeholders

Two placeholder syntaxes live side by side in `{{cookiecutter.project_slug}}/templates/`:

- `{{ cookiecutter.* }}`: filled in once, when the monorepo is generated
  (nixpkgs branch, systems).
- `__NAME__`, `__NAME_SNAKE__`, `__DIR__`, `__PORT__`: filled in later by the
  scaffolder (`nix/apps.nix`) for each new project.

`justfile` is copied without rendering (`_copy_without_render`) because just
uses `{{ }}` itself; GitHub expressions in `ci.yml` are wrapped in
`{% raw %}…{% endraw %}`. Any other file containing a literal `{{`, `{%` or
`{#` needs the same treatment, or Jinja will consume it.

## Testing the template

```sh
scripts/test-template.sh [--docker] [output-dir]
```

Generates a project, scaffolds one service and one tool from every language
template, and runs `nix fmt` (must not change anything), `sync-locks --check`,
`nix flake check`, all binary and image builds, `docker compose config`, a
standalone project flake and every tool binary. `--docker` additionally runs
all services with `just up` and probes `/health` on each port. Run it after
every change to the template; the first run takes a while (toolchains for
five languages).
