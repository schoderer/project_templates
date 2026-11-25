# project_templates

Shared Nix build logic for my projects, plus `nix flake init` templates to start new ones.

Projects use this repo as a **flake input**, so build logic is not copied into each project. Improvements
reach every project with `nix flake update project-templates`.

| Language | Library function       | Template                   |
|----------|------------------------|----------------------------|
| Rust     | `lib.rust.mkFlake`     | `templates.rust`           |
| *others* | –                      | cookiecutter, see [old/](#legacy-cookiecutter-templates) |

## Rust

### New project

```bash
mkdir my-app && cd my-app
nix flake init -t github:schoderer/project_templates#rust
# rename `name = "app"` in Cargo.toml (and the title in Readme.md)
direnv allow              # or: nix develop
nix build                 # binary        -> result/bin/my-app
nix build .#dockerImage   # docker image  -> result (tar.gz), `docker load < result`
nix flake check           # build + cargo test (CI runs this too)
just                      # list recipes
```

The template contains `Cargo.toml`, `src/main.rs`, `flake.nix`, `.envrc`, `justfile`, `bacon.toml`,
`.gitignore` and the `nix-check` GitHub workflow.

### Existing Rust project

Add a `flake.nix` next to `Cargo.toml` (`Cargo.lock` must be committed):

```nix
{
  inputs.project-templates.url = "github:schoderer/project_templates";

  outputs = { project-templates, ... }:
    project-templates.lib.rust.mkFlake { src = ./.; };
}
```

With options:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    project-templates.url = "github:schoderer/project_templates";
    project-templates.inputs.nixpkgs.follows = "nixpkgs";   # share one nixpkgs
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
        config.Env = [ "RUST_LOG=info" ];
        config.ExposedPorts."8080/tcp" = { };
        copyToRoot = [ pkgs.cacert ];
      };

      clippy = true;   # cargo clippy --all-targets -- --deny warnings
      fmt = true;      # cargo fmt --check
    };
}
```

### Outputs

| Output                       | Content                                                  |
|------------------------------|----------------------------------------------------------|
| `packages.default` / `bin`   | the binary, built with [crane] (dependencies cached separately) |
| `packages.dockerImage`       | `dockerTools.buildImage`, runs as user `7337:7337` (unless `docker = false`) |
| `checks.bin` / `checks.test` | build + `cargo test`, plus `clippy` / `fmt` when enabled  |
| `devShells.default`          | toolchain incl. rust-analyzer, clippy, rustfmt, plus `bacon` and the build inputs |

### Options (`mkFlake` / `mkProject`)

| Option              | Default                         | Meaning |
|---------------------|---------------------------------|---------|
| `src`               | required                        | crate root (usually `./.`) |
| `systems`           | x86_64/aarch64 linux, aarch64-darwin | `mkFlake` only |
| `toolchain`         | `rust-toolchain.toml` if present, else stable latest | or `pkgs: pkgs.rust-bin.nightly.latest.default` |
| `nativeBuildInputs` | `[ ]` (added to `pkg-config`)   | list or `pkgs: list` |
| `buildInputs`       | `[ ]` (added to `openssl`)      | list or `pkgs: list` |
| `craneArgs`         | `{ }`                           | merged into crane's args (`pname`, env vars, `cargoExtraArgs`, …); attrset or `pkgs: attrset` |
| `docker`            | `true`                          | `false`, `true`, or `{ name ? "ghcr.io/schoderer/<pname>", tag ? "latest", config ? {}, copyToRoot ? [], entrypoint ? [ "<bin>/bin/<pname>" ] }` (or `pkgs: { … }`) |
| `clippy`, `fmt`     | `false`                         | extra checks |
| `extraChecks`       | `{ }`                           | attrset or `pkgs: attrset` |

`lib.rust.mkProject { pkgs, src, … }` takes the same options for a single system and returns
`{ packages, checks, devShell }`, which is useful inside a monorepo flake.

[crane]: https://github.com/ipetkov/crane

## Legacy cookiecutter templates

The previous cookiecutter templates live in `old/` and still work:

```bash
cookiecutter git@github.com:schoderer/project_templates.git --directory="old/go"
cookiecutter git@github.com:schoderer/project_templates.git --directory="old/rust_esp32_riscv_embassy/rust_esp32_embassy"
```

Available: `bevy`, `deno`, `elixir`, `elm`, `gm-campaign`, `go`, `godot`, `java_maven`, `mono`, `node`, `python`,
`rust`, `rust_esp32_riscv_embassy/rust_esp32_embassy`, `rust_godot`, `rust_pico2_embassy`.
