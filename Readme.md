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

## Rust

### New project

```bash
nix flake new my-app -t git+ssh://git@github.com/schoderer/project_templates#rust && cd my-app
# rename `name = "app"` in Cargo.toml (and the title in Readme.md)
direnv allow              # or: nix develop
nix build                 # binary        -> result/bin/my-app
nix build .#dockerImage   # docker image  -> result (tar.gz), `docker load < result`
nix flake check           # build + cargo test
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

      clippy = true;   # cargo clippy --all-targets -- --deny warnings
    };
}
```

### Outputs

| Output                       | Content                                                  |
|------------------------------|----------------------------------------------------------|
| `packages.default` / `bin`   | the binary, built with [crane] (dependencies cached separately); not for libraries |
| `packages.dockerImage`       | `dockerTools.buildImage`, runs as user `7337:7337` (unless `docker = false`); not for libraries |
| `checks.bin` / `checks.test` | build + `cargo test`, plus `clippy` / `fmt` when enabled (`checks.build` for libraries) |
| `checks.treefmt`             | formatting, when `treefmt.toml` exists |
| `formatter`                  | `nix fmt`: treefmt with rustfmt, nixfmt, taplo (+ `formatters`) |
| `devShells.default`          | toolchain incl. rust-analyzer, clippy, rustfmt, plus `bacon`, `treefmt` and the build inputs |

### Options (`mkFlake` / `mkProject`)

| Option              | Default                         | Meaning |
|---------------------|---------------------------------|---------|
| `src`               | required                        | crate root (usually `./.`) |
| `systems`           | x86_64/aarch64 linux, aarch64-darwin | `mkFlake` only |
| `library`           | auto-detected                   | `true`: no packages, no docker (see [Turning it into a library](#turning-it-into-a-library)) |
| `toolchain`         | `rust-toolchain.toml` if present, else stable latest | or `pkgs: pkgs.rust-bin.nightly.latest.default` |
| `nativeBuildInputs` | `[ ]` (added to `pkg-config`)   | list or `pkgs: list` |
| `buildInputs`       | `[ ]` (added to `openssl`)      | list or `pkgs: list` |
| `craneArgs`         | `{ }`                           | merged into crane's args (`pname`, env vars, `cargoExtraArgs`, …); attrset or `pkgs: attrset` |
| `docker`            | on for binaries                 | `false`, `true`, or `{ name ? "ghcr.io/schoderer/<pname>", tag ? "latest", config ? {}, copyToRoot ? [], entrypoint ? [ "<bin>/bin/<pname>" ] }` (or `pkgs: { … }`) |
| `clippy`, `fmt`     | `false`                         | extra checks (`fmt` = `cargo fmt --check`, redundant with treefmt) |
| `extraChecks`       | `{ }`                           | attrset or `pkgs: attrset` |
| `formatters`        | `[ ]`                           | extra programs for `treefmt.toml`; list or `pkgs: list` |

`lib.rust.mkProject { pkgs, src, … }` takes the same options for a single system and returns
`{ packages, checks, devShell }`, which is useful inside a monorepo flake.

[crane]: https://github.com/ipetkov/crane

## Go

### New project

```bash
nix flake new my-app -t git+ssh://git@github.com/schoderer/project_templates#go && cd my-app
# rename `module app` in go.mod (and the title in Readme.md)
direnv allow              # or: nix develop
nix build                 # binary        -> result/bin/my-app
nix build .#dockerImage   # docker image  -> result (tar.gz), `docker load < result`
nix flake check           # build + go test + go vet
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
      lint = true;                      # golangci-lint
      docker = pkgs: {
        config.ExposedPorts."8080/tcp" = { };
        copyToRoot = [ pkgs.cacert ];   # TLS roots for outgoing HTTPS
      };
    };
}
```

### Outputs

| Output                     | Content                                                     |
|----------------------------|-------------------------------------------------------------|
| `packages.default` / `bin` | `buildGoModule`, static (`CGO_ENABLED=0`), stripped (`-s -w`); not for libraries |
| `packages.dockerImage`     | `dockerTools.buildImage`, runs as user `7337:7337` (unless `docker = false`); not for libraries |
| `checks.bin`               | build + `go test ./...` (runs in the build's check phase; `checks.build` for libraries) |
| `checks.vet` / `checks.lint` | `go vet ./...` (on by default) / `golangci-lint run ./...` (`lint = true`) |
| `checks.treefmt`           | formatting, when `treefmt.toml` exists |
| `formatter`                | `nix fmt`: treefmt with gofmt, nixfmt, taplo (+ `formatters`) |
| `devShells.default`        | go, gopls, delve, golangci-lint, `treefmt`, plus the build inputs |

### Options (`mkFlake` / `mkProject`)

| Option              | Default                         | Meaning |
|---------------------|---------------------------------|---------|
| `src`               | required                        | module root (usually `./.`) |
| `systems`           | x86_64/aarch64 linux, aarch64-darwin | `mkFlake` only |
| `library`           | `false`                         | `true` for a package without `main`: no packages, no docker |
| `vendorHash`        | `null`                          | dependency hash, see above |
| `pname`             | last element of the `module` path | binary/package name |
| `version`           | `"0.0.1"`                       | |
| `subPackages`       | all main packages               | e.g. `[ "cmd/server" ]` |
| `cgo`               | `false`                         | `true` for cgo (no longer a static binary) |
| `ldflags`           | `[ "-s" "-w" ]`                 | e.g. add `"-X main.version=1.2.3"` |
| `go`                | nixpkgs `go`                    | `pkgs: pkgs.go_1_26` to pin |
| `nativeBuildInputs`, `buildInputs` | `[ ]`            | list or `pkgs: list` |
| `goArgs`            | `{ }`                           | merged into `buildGoModule` args (`tags`, `env`, …); attrset or `pkgs: attrset` |
| `docker`            | on for binaries                 | same as Rust: `false`, `true`, or `{ name, tag, config, copyToRoot, entrypoint }` (or `pkgs: { … }`) |
| `vet`, `lint`       | `true`, `false`                 | extra checks |
| `extraChecks`       | `{ }`                           | attrset or `pkgs: attrset` |
| `devPackages`       | `[ ]`                           | extra devShell tools; list or `pkgs: list` |
| `formatters`        | `[ ]`                           | extra programs for `treefmt.toml`; list or `pkgs: list` |

`lib.go.mkProject { pkgs, src, … }` takes the same options for a single system and returns
`{ packages, checks, devShell }`.

## Python

Built with [uv2nix] straight from `uv.lock`. uv already records every dependency's hash there, so unlike Go
there is no hash to maintain in `flake.nix`. The devShell is a plain uv workflow with the Nix interpreter.

### New project

```bash
nix flake new my-app -t git+ssh://git@github.com/schoderer/project_templates#python && cd my-app
# rename `app`: pyproject.toml `name` + `[project.scripts]`, the src/app dir, the import in tests/
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

### Outputs

| Output                     | Content                                                     |
|----------------------------|-------------------------------------------------------------|
| `packages.default` / `bin` | the project's scripts only (`mkApplication` over the uv2nix venv); not for libraries |
| `packages.dockerImage`     | `dockerTools.buildImage`, runs as user `7337:7337`, entrypoint = the script named like the project (else the first); not for libraries |
| `checks.bin`               | the build (`checks.build`, the venv, for libraries)         |
| `checks.test`              | `pytest` with all dependency groups installed               |
| `checks.lint` / `checks.typecheck` | `ruff check` (on by default) / `ty check` against the test venv (`typecheck = true`) |
| `checks.treefmt`           | formatting, when `treefmt.toml` exists                      |
| `formatter`                | `nix fmt`: treefmt with ruff, nixfmt, taplo (+ `formatters`) |
| `devShells.default`        | python, uv, ruff, ty, `treefmt`; `UV_PYTHON` points at the Nix python, downloads are off, and on Linux `LD_LIBRARY_PATH` covers manylinux wheels |

### Options (`mkFlake` / `mkProject`)

| Option              | Default                         | Meaning |
|---------------------|---------------------------------|---------|
| `src`               | required                        | project root with `pyproject.toml` and `uv.lock` |
| `systems`           | x86_64/aarch64 linux, aarch64-darwin | `mkFlake` only |
| `python`            | nixpkgs `python3`               | `pkgs: pkgs.python313`; must satisfy `requires-python` |
| `sourcePreference`  | `"wheel"`                       | or `"sdist"` to build everything from source |
| `pythonOverrides`   | none                            | `pkgs: final: prev: { … }`, an overlay on the uv2nix package set |
| `library`           | auto-detected                   | `true`: no packages, no docker |
| `docker`            | on for apps                     | same as Rust: `false`, `true`, or `{ name, tag, config, copyToRoot, entrypoint }` (or `pkgs: { … }`) |
| `test`, `lint`, `typecheck` | `true`, `true`, `false` | pytest, ruff check, ty |
| `extraChecks`       | `{ }`                           | attrset or `pkgs: attrset` |
| `devPackages`       | `[ ]`                           | extra devShell tools; list or `pkgs: list` |
| `formatters`        | `[ ]`                           | extra programs for `treefmt.toml`; list or `pkgs: list` |

`lib.python.mkProject { pkgs, src, … }` takes the same options for a single system and returns
`{ packages, checks, devShell, formatter }`.

[uv2nix]: https://github.com/pyproject-nix/uv2nix

## Cookiecutter templates

The previous cookiecutter templates live in `old/` and still work, but they aren't developed further:

```bash
cookiecutter git@github.com:schoderer/project_templates.git --directory="old/python_ai"
cookiecutter git@github.com:schoderer/project_templates.git --directory="old/elixir"
cookiecutter git@github.com:schoderer/project_templates.git --directory="old/rust_esp32_riscv_embassy/rust_esp32_embassy"
```

Available in `old/`: `bevy`, `deno`, `elixir`, `elm`, `empty`, `gm-campaign`, `godot`, `java_maven`, `mono`, `node`,
`python_ai`, `rust_esp32_riscv_embassy/rust_esp32_embassy`, `rust_godot`, `rust_pico2_embassy`, and `go`, `python`
and `rust` (superseded by the flake templates above).
