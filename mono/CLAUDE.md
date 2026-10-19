# CLAUDE.md

Cookiecutter template for a Nix multi-project monorepo, the starting point for
a new platform (see README.md).

## Layout

- `cookiecutter.json`, `hooks/`: variables, answer validation, post-generation
  (CI removal, git init, `nix flake lock`).
- `{{cookiecutter.project_slug}}/`: the generated monorepo. Its own CLAUDE.md
  and README.md document the monorepo itself (contract, commands, layout).
- `{{cookiecutter.project_slug}}/templates/<services|tools>/<lang>/`: project
  skeletons for rust, python, go, typescript and generic, plus java_maven
  (services only). Each is a complete project (`flake.nix` wrapper,
  `nix/default.nix` with all build logic, sources, tests, README, `.envrc`,
  `.gitignore`, optional `scaffold.sh`).
- `scripts/test-template.sh`: end-to-end self-test.

## Rules

- Files under `{{cookiecutter.project_slug}}/` are Jinja-rendered: escape a
  literal `{{`, `{%` or `{#` with `{% raw %}` or add the file to
  `_copy_without_render` (the justfile is). Placeholders for the scaffolder
  use `__NAME__`-style tokens instead, and survive rendering untouched.
- Keep the language templates consistent: same `flake.nix` shape (only Rust
  adds the crane input), same service conventions (`$PORT`, `GET /health`,
  SIGTERM, image `<name>:<version>` as nobody, `compose.ports = [ "__PORT__:8080" ]`),
  same tool commands (`greet [NAME] [--shout]`, `version`), tests wired into
  `checks` or the build.
- Every `.sh` and `.envrc` file needs a `# shellcheck shell=bash` line
  (treefmt runs shellcheck); templates must already be formatted.
- A new language template also needs its formatter in
  `{{cookiecutter.project_slug}}/nix/treefmt.nix` and a row in the READMEs.
- Keep both CLAUDE.md files and the READMEs in line with behaviour changes.

## Verify

`scripts/test-template.sh --docker` must pass (nix, git and docker required;
cookiecutter comes from nixpkgs if missing). For quicker iterations, fix
things in the generated project under the output dir, then port the change
back into the template and rerun the script.
