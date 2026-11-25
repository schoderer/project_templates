# CLAUDE.md

A library flake (`lib.<lang>.mkProject` / `mkFlake` in `nix/<lang>.nix`) plus `nix flake init` templates
(`templates/<lang>/`) that consume it as the `project-templates` input. All cookiecutter templates are legacy,
in `old/`.

## Rules

- The repo is **private**. Reference it as `git+ssh://git@github.com/schoderer/project_templates`, never
  `github:…` (the API fetch is unauthenticated and returns 404).
- Version control is **jj**. Don't `git add`/`git commit`.
- `mkProject` returns `{ packages, checks, devShell, formatter }`; the shared parts (source filter, docker,
  treefmt, library rules) live in `nix/project.nix` (`mkOutputs`). Common options: `test`, `lint`, `docker`,
  `library`, `extraChecks`, `devPackages`, `formatters`. Options that
  reference packages must also accept `pkgs -> value`, because `mkFlake` users have no per-system `pkgs`.
- Libraries (`library`, auto-detected for Rust and Python, explicit for Go) get no packages and no docker (`docker` is
  ignored), and their build check is `build`, not `bin`.
- Templates are copied verbatim: no Jinja, no variables. Names come from project metadata (`Cargo.toml`,
  `go.mod`, `pyproject.toml`) with an `app` placeholder that the `welcomeText` tells the user to rename.
- Formatting: each template owns a `treefmt.toml`, and the lib only supplies the programs it
  references (+ `formatters`). A new template's toml must only use programs its lib provides.
- Python: `pythonOverrides` is `pkgs: final: prev:` (not via `resolve`, since an overlay is a function itself).
  Its template's taplo options match uv's pyproject.toml style. Keep them, or `uv add` fails the format check.
- Templates ship no CI workflow on purpose: the private input would need an SSH deploy key on the runner.
- `nix/templates.nix` is the single table of templates (description, welcomeText, `selfTest` options). The root
  `checks` build every template through its lib with all opt-in gates on. Keep it buildable
  (e.g. a valid `Cargo.lock`, no Go deps so `vendorHash = null`).
- Nix style: when two or more attributes share a prefix, nest them (`lib = { rust = …; go = …; }`,
  `project-templates = { url = …; inputs.nixpkgs.follows = …; }`). A lone dotted path (`nixpkgs.url`) stays.
  Applies to the repo, templates and Readme examples.
- `Readme.md` is the reference for every option and output (shared ones in "Common options and outputs").
  Update it with any lib change; option comments in `nix/*.nix` stay one-line labels.
- Don't extend `old/`. Port a template to `templates/` instead (drop its `.github/` and Jinja).

## Adding a template

- New language: `nix/<lang>.nix` whose `mkProject` ends in `project.mkOutputs` (don't reimplement packages,
  docker, treefmt or library rules), register it in `langs` in `flake.nix`, and make new inputs follow `nixpkgs`.
- Add the language's local build/tool dirs to `ignoredDirs` in `filterSource` (`nix/project.nix`).
- Builds run offline: dependencies must come from a lockfile with hashes (crane, uv2nix) or a single hash
  option (`vendorHash`). Prefer tooling that reads the lockfile; never a hash per dependency.
- Set `meta.mainProgram` on `bin` so `nix run` and the docker entrypoint find the program.
- Check that the language's own tools (`uv add`, `cargo add`, …) don't write files the template's
  `treefmt.toml` would reformat, or every dependency change fails `checks.treefmt`. Configure the formatter to
  match them.
- `treefmt.toml`: exclude the local build dir (`target/**`, `.venv/**`) for walks outside git.
- The template needs a valid lockfile and at least one test, so the self-test proves the `test` gate runs.
- `nix/templates.nix` entry: `welcomeText` must list every place the `app` placeholder appears (incl.
  `flake.nix` description and justfile), and `selfTest` turns on every opt-in gate.
- Readme: add the language to the table at the top and a section whose "Specifics" only lists what differs from
  "Common options and outputs".
- Verify as a consumer: `nix flake new`, rename per the welcomeText, `nix build`, `nix run`, `nix flake check`,
  add a dependency, break a test and a lint rule (each must fail), turn it into a library.

## Verifying

```bash
nix flake check path:.     # always use path: (jj changes aren't in the git index)
cd "$(mktemp -d)" && nix flake init -t path:/path/to/repo#go
sed -i 's|git+ssh://git@github.com/schoderer/project_templates|path:/path/to/repo|' flake.nix
nix flake check path:. && nix build path:.#dockerImage
```

Claude sandbox: Nix is Debian's `nix-bin` with a single-user store (`NIX_REMOTE=local`), and there is no GitHub
SSH key. If `cache.nixos.org` is blocked by the firewall, only evaluate (`--no-build`).
