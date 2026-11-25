# CLAUDE.md

A library flake (`lib.<lang>.mkProject` / `mkFlake` in `nix/<lang>.nix`) plus `nix flake init` templates
(`templates/<lang>/`) that consume it as the `project-templates` input. All cookiecutter templates are legacy,
in `old/`.

## Rules

- The repo is **private**. Reference it as `git+ssh://git@github.com/schoderer/project_templates`, never
  `github:…` (the API fetch is unauthenticated and returns 404).
- Version control is **jj**. Don't `git add`/`git commit`.
- `mkProject` returns `{ packages, checks, devShell, formatter }`. Options that
  reference packages must also accept `pkgs -> value`, because `mkFlake` users have no per-system `pkgs`.
- Libraries (`library`, auto-detected for Rust and Python, explicit for Go) get no packages and no docker (`docker` is
  ignored, see `nix/docker.nix`, shared by all languages), and their build check is `build`, not `bin`.
- Templates are copied verbatim: no Jinja, no variables. Names come from project metadata (`Cargo.toml`,
  `go.mod`, `pyproject.toml`) with an `app` placeholder that the `welcomeText` tells the user to rename.
- Formatting: each template owns a `treefmt.toml`, and the lib (`nix/treefmt.nix`) only supplies the programs it
  references (+ `formatters`). A new template's toml must only use programs its lib provides.
- Python: `pythonOverrides` is `pkgs: final: prev:` (not via `resolve`, since an overlay is a function itself).
  Its template's taplo options match uv's pyproject.toml style. Keep them, or `uv add` fails the format check.
- Templates ship no CI workflow on purpose: the private input would need an SSH deploy key on the runner.
- Every template is built by the root `checks` (`templateChecks`) with all optional gates on. Keep it buildable
  (e.g. a valid `Cargo.lock`, no Go deps so `vendorHash = null`).
- Nix style: when two or more attributes share a prefix, nest them (`lib = { rust = …; go = …; }`,
  `project-templates = { url = …; inputs.nixpkgs.follows = …; }`). A lone dotted path (`nixpkgs.url`) stays.
  Applies to the repo, templates and Readme examples.
- `Readme.md` documents every option and output. Update it with any lib change.
- Don't extend `old/`. Port a template to `templates/` instead (drop its `.github/` and Jinja).

## Verifying

```bash
nix flake check path:.     # always use path: (jj changes aren't in the git index)
cd "$(mktemp -d)" && nix flake init -t path:/path/to/repo#go
sed -i 's|git+ssh://git@github.com/schoderer/project_templates|path:/path/to/repo|' flake.nix
nix flake check path:. && nix build path:.#dockerImage
```

Claude sandbox: Nix is Debian's `nix-bin` with a single-user store (`NIX_REMOTE=local`), and there is no GitHub
SSH key. If `cache.nixos.org` is blocked by the firewall, only evaluate (`--no-build`).

## Cookiecutter pitfall

Literal `{{ }}` in a rendered file (just variables, `${{ }}`) must be escaped as `{{ '{{' }}`, or the file
listed in `_copy_without_render`. Files listed there can't use Jinja conditionals.
