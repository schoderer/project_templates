# project_templates

Shared Nix build logic for my projects, plus flake templates (`nix flake new`/`init`) to start new ones.

Projects use this repo as a **flake input**, so build logic is not copied into each project. Improvements
reach every project with `nix flake update project-templates`.

| Language | Library function       | Template                   |
|----------|------------------------|----------------------------|
| Rust     | `lib.rust.mkFlake`     | `templates.rust`           |
| Go       | `lib.go.mkFlake`       | `templates.go`             |
| Python   | `lib.python.mkFlake`   | `templates.python`         |
| *others* | –                      | cookiecutter in `old/`, see [below](#cookiecutter-templates) |

## Access (private repo)

This repo is private, so it's fetched over **SSH** (`git+ssh://`), just like
`cookiecutter git@github.com:…` did. Your normal GitHub SSH key is used. The `github:` shorthand doesn't
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
gofmt (from the project's Go) or `ruff format`. In the Python template, taplo is configured to match the style
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
| `library`     | auto-detected (Rust, Python); `false` (Go) | `true`: no packages, no Docker image, build check named `build` |
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
# rename `app`: `module` in go.mod, `description` in flake.nix, the title in Readme.md
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
- `test` = `pytest` with all dependency groups installed, `lint` = `ruff check`, plus `checks.typecheck`
  (`ty check` against the test venv) with `typecheck = true`.
- devShell: python, uv, ruff, ty. `UV_PYTHON` points at the Nix python, downloads are off, and on Linux
  `LD_LIBRARY_PATH` covers manylinux wheels.

| Option              | Default                         | Meaning |
|---------------------|---------------------------------|---------|
| `python`            | nixpkgs `python3`               | `pkgs: pkgs.python313`; must satisfy `requires-python` |
| `sourcePreference`  | `"wheel"`                       | or `"sdist"` to build everything from source |
| `pythonOverrides`   | none                            | `pkgs: final: prev: { … }`, an overlay on the uv2nix package set |
| `typecheck`         | `false`                         | ty check |

Library detection: no `[project.scripts]` in `pyproject.toml`.

[uv2nix]: https://github.com/pyproject-nix/uv2nix

## Cookiecutter templates

The previous cookiecutter templates live in `old/` and still work, but they aren't developed further:

```bash
cookiecutter git@github.com:schoderer/project_templates.git --directory="old/python_ai"
cookiecutter git@github.com:schoderer/project_templates.git --directory="old/elixir"
cookiecutter git@github.com:schoderer/project_templates.git --directory="old/rust_esp32_riscv_embassy/rust_esp32_embassy"
```

Available in `old/`: `bevy`, `deno`, `elixir`, `elm`, `gm-campaign`, `godot`, `java_maven`, `mono`, `node`,
`python_ai`, `rust_esp32_riscv_embassy/rust_esp32_embassy`, `rust_godot`, `rust_pico2_embassy`. Rust, Go and Python
are covered by the flake templates above.
