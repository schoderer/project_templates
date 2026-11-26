# project_templates

Shared Nix build logic for my projects, plus flake templates (`nix flake new`/`init`) to start new ones.

Projects use this repo as a **flake input**, so build logic is not copied into each project. Improvements
reach every project with `nix flake update project-templates`.

| Language | Library function       | Template                   |
|----------|------------------------|----------------------------|
| Rust     | `lib.rust.mkFlake`     | `templates.rust`           |
| Go       | `lib.go.mkFlake`       | `templates.go`             |
| Python   | `lib.python.mkFlake`   | `templates.python`, `templates.python-torch` (PyTorch on AMD GPUs) |
| TypeScript | `lib.node.mkFlake`   | `templates.node` (Node app), `templates.vite` (Vite + React frontend) |

## Access (private repo)

This repo is private, so it's fetched over **SSH** (`git+ssh://`) with your normal GitHub SSH key. The `github:` shorthand doesn't
work here because it downloads through the GitHub API without credentials and gets a 404.

Nothing to set up if `ssh -T git@github.com` works: Nix runs the git fetch as your user, with your
ssh-agent, even when it uses the nix-daemon.

The templates ship **no CI workflow**. On a GitHub runner `nix flake check` would also need an SSH key for
this repo (for example a read-only deploy key loaded with `webfactory/ssh-agent` before the Nix step),
because the `project-templates` input isn't part of the project checkout.

Branches and commits go in the query, and the `#` fragment picks the flake output (template name):

```bash
nix flake init -t "git+ssh://git@github.com/schoderer/project_templates?ref=my-branch#rust"
nix flake init -t "git+ssh://git@github.com/schoderer/project_templates?rev=<sha>#rust"
```

## Starting a project

```bash
nix flake new my-app -t git+ssh://git@github.com/schoderer/project_templates#go   # creates ./my-app
cd my-app && nix flake init -t git+ssh://git@github.com/schoderer/project_templates#go   # into the current dir
```

`init` never overwrites existing files, so it also works in a directory that already has some content.

The generated `flake.nix` has its own `nixpkgs` input (`nixos-unstable`), and the lib follows it
(`project-templates.inputs.nixpkgs.follows = "nixpkgs"`). So `nix flake update` moves the project to the latest
unstable, independent of this repo's `flake.lock`. Update only the lib with `nix flake update project-templates`.

## Formatting (treefmt)

Every template ships a `treefmt.toml`, which the project owns. The lib supplies the formatter programs:
nixfmt and taplo for all projects, plus rustfmt (from the project's toolchain, so it matches `cargo fmt`),
gofmt (from the project's Go), `ruff format` or biome (TS/JS/JSON/CSS; npm-owned `package.json`/`package-lock.json`
are left alone). In the Python template, taplo is configured to match the style
`uv add` writes into `pyproject.toml`, so adding a dependency doesn't fail the format check.

```bash
nix fmt           # format the project (also `treefmt` / `just fmt` in the devShell)
nix flake check   # includes checks.treefmt, which fails on unformatted files
```

To add a formatter, add a `[formatter.<name>]` entry to `treefmt.toml` and its program to `flake.nix`:

```nix
formatters = pkgs: [ pkgs.mdformat ];
```

`checks.treefmt` only exists when the project has a `treefmt.toml`. To adopt it in an existing project, copy
one from `templates/<lang>/`.

## Common options and outputs

All three libs share one shape: `lib.<lang>.mkFlake { src = ./.; … }` returns `packages`, `checks`,
`devShells.default` and `formatter` for every system, and `lib.<lang>.mkProject { pkgs, src, … }` takes the same
options for a single system and returns `{ packages, checks, devShell, formatter }` (useful inside a monorepo
flake). Options that reference packages can be written as functions of `pkgs` (`buildInputs = pkgs: [ … ];`).

| Option        | Default                              | Meaning |
|---------------|--------------------------------------|---------|
| `src`         | required                             | project root, usually `./.` |
| `systems`     | x86_64/aarch64 linux, aarch64-darwin | `mkFlake` only |
| `library`     | auto-detected (Rust, Python, Node); `false` (Go) | `true`: no packages, no Docker image, build check named `build` |
| `docker`      | on for binaries                      | `false`, `true`, or `{ name ? "ghcr.io/schoderer/<pname>", tag ? "latest", config ? { }, copyToRoot ? [ ], entrypoint ? [ "<bin>/bin/<program>" ] }` (or `pkgs: { … }`); ignored for libraries |
| `test`, `lint` | `true`, `true`                      | the language's tests and standard linter (see each language) |
| `extraChecks` | `{ }`                                | more checks; attrset or `pkgs: attrset` |
| `devPackages` | `[ ]`                                | extra devShell tools; list or `pkgs: list` |
| `formatters`  | `[ ]`                                | extra programs for your `treefmt.toml` entries; list or `pkgs: list` |

| Output                     | Content |
|----------------------------|---------|
| `packages.default` / `bin` | the program (`nix run` works); not for libraries |
| `packages.dockerImage`     | `dockerTools.buildImage` with the program as entrypoint, runs as user `7337:7337`; Linux only, not for libraries |
| `checks.bin`               | the build (`checks.build` for libraries) |
| `checks.test` / `checks.lint` | tests / linter, see each language |
| `checks.treefmt`           | formatting, when the project has a `treefmt.toml` |
| `formatter`                | `nix fmt`: treefmt with nixfmt, taplo, the language's formatter and `formatters` |
| `devShells.default`        | toolchain, language tools and `treefmt`, see each language |

Build inputs and the source are filtered: `target/`, `.venv`, `node_modules`, `.direnv`, `result*`, VCS and
Python cache dirs never reach a build or check, so `path:` flakes (jj) don't copy them or rebuild when they change.

## Rust

### New project

```bash
nix flake new my-app -t git+ssh://git@github.com/schoderer/project_templates#rust && cd my-app
# rename `app`: `name` in Cargo.toml, `description` in flake.nix, the title in Readme.md
direnv allow              # or: nix develop
cargo check               # updates Cargo.lock to the new name
nix build                 # binary        -> result/bin/my-app
nix build .#dockerImage   # docker image  -> result (tar.gz), `docker load < result`
nix flake check           # build + cargo test + clippy + formatting
just                      # list recipes
```

The template contains `Cargo.toml`, `src/main.rs`, `flake.nix`, `.envrc`, `justfile`, `bacon.toml`,
and `.gitignore`.

### Turning it into a library

Replace `src/main.rs` with `src/lib.rs` and remove `docker = { };` from `flake.nix`. A crate without
`src/main.rs`, `src/bin/` or `[[bin]]` is detected as a library: it gets no packages (`nix build` fails with
"does not provide attribute 'packages…default'"), no Docker image, and its build check is called
`checks.build`. Tests, clippy and treefmt work as before. `docker` is ignored for libraries. Override the detection with `library = true/false`. Workspaces always count as binaries.

### Existing Rust project

Add a `flake.nix` next to `Cargo.toml` (`Cargo.lock` must be committed):

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    project-templates = {
      url = "git+ssh://git@github.com/schoderer/project_templates";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { project-templates, ... }:
    project-templates.lib.rust.mkFlake { src = ./.; };
}
```

With options:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    project-templates = {
      url = "git+ssh://git@github.com/schoderer/project_templates";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { project-templates, ... }:
    project-templates.lib.rust.mkFlake {
      src = ./.;
      systems = [ "x86_64-linux" ];

      # Per-system values are written as functions of pkgs:
      buildInputs = pkgs: [ pkgs.sqlite ];
      nativeBuildInputs = pkgs: [ pkgs.protobuf ];

      # Attrset, or a function of pkgs when the image needs packages:
      docker = pkgs: {
        name = "ghcr.io/schoderer/my-app";
        tag = "0.1.0";
        config = {
          Env = [ "RUST_LOG=info" ];
          ExposedPorts."8080/tcp" = { };
        };
        copyToRoot = [ pkgs.cacert ];
      };

      lint = false;     # clippy, on by default
    };
}
```

### Specifics

- `bin`: built with [crane], dependencies cached in a separate derivation.
- `test` = `cargo test`, `lint` = `cargo clippy --all-targets -- --deny warnings`.
- devShell: the toolchain (rust-analyzer, clippy, rustfmt), `bacon`, the build inputs.
- formatter: rustfmt from the project's toolchain, so it matches `cargo fmt`.

| Option              | Default                         | Meaning |
|---------------------|---------------------------------|---------|
| `toolchain`         | `rust-toolchain.toml` if present, else stable latest | or `pkgs: pkgs.rust-bin.nightly.latest.default` |
| `nativeBuildInputs` | `[ ]` (added to `pkg-config`)   | list or `pkgs: list` |
| `buildInputs`       | `[ ]` (added to `openssl`)      | list or `pkgs: list` |
| `craneArgs`         | `{ }`                           | merged into crane's args (`pname`, env vars, `cargoExtraArgs`, …); attrset or `pkgs: attrset` |

Library detection: no `src/main.rs`, `src/bin/` or `[[bin]]` (workspaces always count as binaries).

[crane]: https://github.com/ipetkov/crane

## Go

### New project

```bash
nix flake new my-app -t git+ssh://git@github.com/schoderer/project_templates#go && cd my-app
# rename `app`: `module` in go.mod, `/app` in .gitignore, `description` in flake.nix, the title in Readme.md
direnv allow              # or: nix develop
nix build                 # binary        -> result/bin/my-app
nix build .#dockerImage   # docker image  -> result (tar.gz), `docker load < result`
nix flake check           # build + go test + go vet + formatting
just                      # list recipes
```

The template contains `go.mod`, `main.go`, `main_test.go`, `flake.nix`, `.envrc`, `justfile` and `.gitignore`.
The binary is named after the last element of the module path (`module github.com/me/my-app` gives `my-app`).

### Dependencies: `vendorHash`

Nix builds without network access, so it has to know the hash of the module's dependencies in advance:

1. With no requirements in `go.mod`, keep `vendorHash = null;` (the template default).
2. After `go get …`, set `vendorHash = "";` and run `nix build`. It fails and prints `got: sha256-…`.
3. Paste that hash into `vendorHash`. Repeat whenever `go.mod`/`go.sum` change.

If you vendor dependencies (`go mod vendor`, committed `vendor/`), `vendorHash = null;` stays.

### Turning it into a library

Replace `main.go`/`main_test.go` with a non-main package, and in `flake.nix` remove `docker = { };` and add
`library = true;`. Go needs the flag because detecting `package main` would mean parsing every `.go` file.
Otherwise it behaves like Rust: no packages, no Docker image, the build/test check is `checks.build`, and
`docker` is ignored.

### Existing Go project

Add a `flake.nix` next to `go.mod`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    project-templates = {
      url = "git+ssh://git@github.com/schoderer/project_templates";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { project-templates, ... }:
    project-templates.lib.go.mkFlake {
      src = ./.;
      vendorHash = "sha256-…";
      subPackages = [ "cmd/server" ];   # only build these main packages
      golangciLint = true;              # golangci-lint
      docker = pkgs: {
        config.ExposedPorts."8080/tcp" = { };
        copyToRoot = [ pkgs.cacert ];   # TLS roots for outgoing HTTPS
      };
    };
}
```

### Specifics

- `bin`: `buildGoModule`, static (`CGO_ENABLED=0`), stripped (`-s -w`). Named after the last element of the
  module path.
- `test` = `go test ./...` (runs in the build's check phase, so it's part of `checks.bin`), `lint` = `go vet ./...`,
  plus `checks.golangci-lint` with `golangciLint = true`.
- devShell: go, gopls, delve, golangci-lint, the build inputs.

| Option              | Default                         | Meaning |
|---------------------|---------------------------------|---------|
| `vendorHash`        | `null`                          | dependency hash, see above |
| `pname`             | last element of the `module` path | binary/package name |
| `version`           | `"0.0.1"`                       | |
| `subPackages`       | all main packages               | e.g. `[ "cmd/server" ]` |
| `cgo`               | `false`                         | `true` for cgo (no longer a static binary) |
| `ldflags`           | `[ "-s" "-w" ]`                 | e.g. add `"-X main.version=1.2.3"` |
| `go`                | nixpkgs `go`                    | `pkgs: pkgs.go_1_26` to pin |
| `nativeBuildInputs`, `buildInputs` | `[ ]`            | list or `pkgs: list` |
| `goArgs`            | `{ }`                           | merged into `buildGoModule` args (`tags`, `env`, …); attrset or `pkgs: attrset` |
| `golangciLint`      | `false`                         | golangci-lint check |

## Python

Built with [uv2nix] straight from `uv.lock`. uv already records every dependency's hash there, so unlike Go
there is no hash to maintain in `flake.nix`. The devShell is a plain uv workflow with the Nix interpreter.

### New project

```bash
nix flake new my-app -t git+ssh://git@github.com/schoderer/project_templates#python && cd my-app
# rename `app`: pyproject.toml `name` + `[project.scripts]`, the src/app dir, the import in tests/,
# the `run` recipe in the justfile, `description` in flake.nix, the title in Readme.md
uv lock                   # re-resolve under the new name
direnv allow              # or: nix develop
uv sync                   # .venv for your editor
nix build                 # app           -> result/bin/<script>
nix build .#dockerImage   # docker image  -> result (tar.gz), `docker load < result`
nix flake check           # build + pytest + ruff check + ty + formatting
just                      # list recipes
```

The template contains `pyproject.toml` (uv_build backend, `dev` group with pytest, ruff rules), `uv.lock`,
`src/app/__init__.py`, `tests/test_app.py`, `flake.nix`, `treefmt.toml`, `.envrc`, `justfile` and `.gitignore`.

### Dependencies

`uv add <pkg>` (or `uv add --dev <pkg>` for the `dev` group). That updates `pyproject.toml` and `uv.lock`, and
the next `nix build` uses them. Wheels are preferred (`sourcePreference = "wheel"`). A dependency that has to
be built from source and needs native libraries gets them through `pythonOverrides`:

```nix
pythonOverrides = pkgs: final: prev: {
  somepkg = prev.somepkg.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkg-config ];
  });
};
```

### Turning it into a library

Remove `[project.scripts]` from `pyproject.toml` and `docker = { };` from `flake.nix`. A project without
scripts is detected as a library: no packages, no Docker image, and its build check (the venv) is called
`checks.build`. Tests, ruff, ty and treefmt work as before. `docker` is ignored for libraries. Override the detection with `library = true/false`.

### Existing Python project

Needs a `uv.lock`, a `[build-system]` and, for an app, `[project.scripts]`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    project-templates = {
      url = "git+ssh://git@github.com/schoderer/project_templates";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { project-templates, ... }:
    project-templates.lib.python.mkFlake {
      src = ./.;
      python = pkgs: pkgs.python313;   # must satisfy requires-python
      typecheck = true;                # ty
      docker = pkgs: {
        config.ExposedPorts."8000/tcp" = { };
        copyToRoot = [ pkgs.cacert ];
      };
    };
}
```

### Specifics

- `bin`: only the project's scripts (`mkApplication` over the uv2nix venv); the Docker entrypoint and `nix run`
  use the script named like the project, else the first one. For libraries, `checks.build` is the venv.
  The runtime venv never contains dependency groups (not even `[tool.uv] default-groups`).
- `test` = `pytest` with all dependency groups installed (or only `checkGroups`), `lint` = `ruff check`, plus `checks.typecheck`
  (`ty check` against the test venv) with `typecheck = true`.
- devShell: python, uv, ruff, ty. `UV_PYTHON` points at the Nix python, downloads are off, and on Linux
  `LD_LIBRARY_PATH` covers manylinux wheels.

| Option              | Default                         | Meaning |
|---------------------|---------------------------------|---------|
| `python`            | nixpkgs `python3`               | `pkgs: pkgs.python313`; must satisfy `requires-python` |
| `sourcePreference`  | `"wheel"`                       | or `"sdist"` to build everything from source |
| `pythonOverrides`   | none                            | `pkgs: final: prev: { … }`, an overlay on the uv2nix package set |
| `typecheck`         | `false`                         | ty check |
| `checkGroups`       | all groups                      | dependency groups in the test/typecheck venv, e.g. `[ "dev" ]` |

Library detection: no `[project.scripts]` in `pyproject.toml`.

### PyTorch on AMD GPUs (`#python-torch`)

For PyTorch scripts on AMD cards, without a ROCm container and without managing ROCm in Nix: PyTorch's ROCm
wheels bundle the ROCm runtime, so uv installs GPU torch straight into `.venv`. The host only needs the amdgpu
kernel driver (`/dev/kfd`, `/dev/dri`). On ROCm builds the GPU is the `"cuda"` device, so model code written
for CUDA runs unchanged.

```bash
nix flake new my-ml -t git+ssh://git@github.com/schoderer/project_templates#python-torch && cd my-ml
# rename `app`: pyproject.toml `name`, the src/app dir, the import in tests/, flake.nix description, Readme.md
uv lock                   # keeps the pinned torch
direnv allow              # or: nix develop
uv sync                   # .venv with the ROCm torch (first time: 6+ GB download, shared via the uv cache)
just gpu-check            # torch/HIP versions, visible GPUs, a matmul on each
just run scripts/train.py # any script with the GPU torch
```

- **torch stays out of Nix.** It lives in the `gpu` dependency group (installed by `uv sync` via
  `default-groups`), and the flake sets `checkGroups = [ "dev" ]`. So `nix flake check` runs pytest (torch tests
  are skipped via `pytest.importorskip`), ruff and treefmt without ever downloading torch. The project is a
  library (no `[project.scripts]`): no packages, no Docker image. Type checking runs locally (`just typecheck`),
  where torch is installed.
- **Pinned, so projects share one download.** torch is locked in the template's `uv.lock` (currently
  2.14.1+rocm7.2), and the Python minor is pinned in `flake.nix` and `requires-python` (wheels are per minor).
  New projects keep the template's torch, uv hardlinks it from `~/.cache/uv` into each `.venv`, and a
  `nix flake update` never changes it.
- **`triton-rocm`** is listed in the `gpu` group although it's torch's own dependency: `[tool.uv.sources]` only
  applies to direct dependencies, and it has to come from the ROCm index too (PyPI only has an ancient version).
  `torchvision`/`torchaudio` are pre-mapped to the ROCm index, so `uv add --group gpu torchvision` just works.
- **Several GPUs / an iGPU:** pick the card with `HIP_VISIBLE_DEVICES=<index>`.
- **Upgrading a project:** `uv lock --upgrade-package torch` (within the pin in pyproject.toml).
- **Bumping the template:** in `templates/python-torch/`, update the `torch==` pin and the index URL
  (`rocm<X.Y>`, the newest one with wheels for the pinned Python), plus the Python minor in `flake.nix`,
  `requires-python` and `nix/templates.nix` if needed. Then run `uv lock` and `nix flake check path:.`. If torch
  renames its triton dependency again, the lock error names the new package.
- **Cache:** `just clean-cache` (`uv cache clean torch triton-rocm`) after a bump; existing venvs keep working.
  The uv cache isn't touched by Nix garbage collection.

[uv2nix]: https://github.com/pyproject-nix/uv2nix

## TypeScript / Node

Built from `package-lock.json` with nixpkgs' `importNpmLock`: npm records every dependency's integrity hash in
the lock, so (like Python) there is no hash to maintain in `flake.nix`. Tooling: npm, vitest, `tsc`, and
[biome] for lint and format (from nixpkgs, not an npm dependency).

`kind` picks what the project produces:
- `"app"` (default, `#node`): a Node program from package.json's `"bin"`, `result/bin/<name>`.
- `"static"` (`#vite`): the build output (`outDir`, default `dist`) as `packages.site`, and `bin` is a small
  [static-web-server] wrapper serving it (`nix run`, docker), with SPA fallback to `index.html`. `HOST`/`PORT`
  (default `0.0.0.0:8080`) override the address.

### New project

```bash
nix flake new my-app -t git+ssh://git@github.com/schoderer/project_templates#node && cd my-app   # or #vite
# rename `app`: package.json `name` (+ `bin` for #node, `<title>` in index.html for #vite),
# `description` in flake.nix, the title in Readme.md
direnv allow              # or: nix develop
npm install               # node_modules for the editor, refreshes package-lock.json after the rename
npm run dev               # #node: run from source with --watch; #vite: Vite dev server
nix build                 # #node: result/bin/my-app; #vite: result/bin/my-app serves the site
nix build .#dockerImage   # docker image  -> result (tar.gz), `docker load < result`
nix flake check           # build + vitest + tsc + biome lint + formatting
just                      # list recipes
```

`#node` runs TypeScript directly with Node's type stripping in development (`npm run dev`, `just run`) and
compiles with `tsc -p tsconfig.build.json` for the build. `#vite` is `create-vite`'s react-ts setup with biome
instead of oxlint, vitest + Testing Library + jsdom, and `typecheck` split out of `build`.

### Dependencies

`npm install <pkg>` (or `--save-dev`). The next `nix build` uses the updated lock.

### Turning it into a library

`#node`: remove `"bin"` from package.json and `docker = { };` from flake.nix. An app without `"bin"` is detected
as a library. `kind = "static"` is never a library.

### Angular (and other npm projects)

The lib doesn't care about the framework: anything with `package-lock.json` and an npm build script works.
For Angular, create the project with `ng new my-app`, add a `flake.nix` with

```nix
project-templates.lib.node.mkFlake {
  src = ./.;
  kind = "static";
  outDir = "dist/my-app/browser";   # Angular's build output
  docker = { };
  typecheck = false;                # `ng build` type-checks; there is no `typecheck` script
  lint = false;                     # keep angular-eslint (`ng lint`) instead of biome
};
```

and copy `treefmt.toml` from `templates/vite/` (or drop it). `test` runs `npm test` (`ng test`).

### Specifics

- `test` = `npm test`, `typecheck` = `npm run typecheck` (both with the project's node_modules), `lint` =
  `biome lint`. So the checks follow your package.json scripts.
- `pname`/`version` from package.json (a scope like `@me/` is dropped); `nix run` and the docker entrypoint use
  the bin named like the package, else the first one.
- devShell: nodejs (npm), biome. Vite, vitest and tsc come from `node_modules`.

| Option        | Default        | Meaning |
|---------------|----------------|---------|
| `kind`        | `"app"`        | `"app"` or `"static"` |
| `outDir`      | `"dist"`       | build output for `kind = "static"` |
| `buildScript` | `"build"`      | the `npm run` script for the build |
| `nodejs`      | nixpkgs `nodejs` | `pkgs: pkgs.nodejs_22` to pin |
| `npmArgs`     | `{ }`          | merged into `buildNpmPackage` args; attrset or `pkgs: attrset` |
| `typecheck`   | `true`         | `npm run typecheck` |

[biome]: https://biomejs.dev
[static-web-server]: https://static-web-server.net
