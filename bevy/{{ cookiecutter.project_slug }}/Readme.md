# {{ cookiecutter.project_name }}

Bevy 0.19 on a nightly toolchain, pinned with nix.

```sh
direnv allow      # or: nix develop
just run          # the dev loop
just watch        # continuous type-check in a second pane
```

Run `cargo generate-lockfile` (or any cargo command) once before `just build` --
crane needs a committed `Cargo.lock` to build the release package.

## Recipes

| | |
|---|---|
| `just run` | dev loop: dynamic linking, dev tools, asset hot-reload |
| `just check` | type-check only; the fastest feedback there is |
| `just watch` | bacon TUI, re-checks on save |
| `just hotpatch` | edit system bodies without restarting the game |
| `just run-release` | optimised build |
| `just build` | reproducible release build via nix |
| `just timings` | writes `target/cargo-timings/cargo-timing.html` |

## How the build is kept fast

Roughly in order of how much they matter:

- **Dynamic linking** (`--features dev`). Bevy is linked as a single shared
  object instead of being statically linked into your binary on every rebuild.
  This is the single biggest win and it is why `just run` exists.
- **mold** as the linker, via clang. Linking is otherwise a large share of an
  incremental Bevy rebuild.
- **Minimal debug info.** `debug = "line-tables-only"` for your crate and
  `debug = false` for dependencies. Full debuginfo for a Bevy binary is hundreds
  of megabytes that get written and linked every single time you hit save.
  Backtraces still resolve; stepping into dependency source does not.
- **Cranelift** as the codegen backend for your crate only. It generates code
  considerably faster than LLVM; dependencies stay on LLVM at `opt-level = 3`
  because they are compiled once and then cached.
- **`-Zshare-generics=y`** so monomorphised generics are reused across crates
  rather than re-emitted, and **`-Zthreads=8`** for the parallel rustc frontend.
- **Feature trimming.** Bevy 0.19's `2d` / `3d` / `ui` / `audio` umbrella
  features are self-contained. A 2D project that sets
  `default-features = false, features = ["2d", "ui", "audio"]` drops the entire
  PBR, glTF and animation stack from the graph.

Two habits matter as much as the configuration:

1. **Stay on one feature set.** Alternating between `just run` and
   `just run-static` changes feature resolution and rebuilds everything. Pick
   one for the day.
2. **Prefer `cargo check` to `cargo build`.** `just watch` catches nearly every
   error without codegen or linking.

When a build feels slow, `just timings` tells you which crate is responsible
instead of guessing.

## Hot patching

`just hotpatch` runs the game under the dioxus CLI with Bevy's `hotpatching`
feature, so edits to the *body* of a system take effect in the running game.
Changing a signature, adding a system, or touching a type still needs a restart.
Install the CLI with `cargo install dioxus-cli`, or uncomment `dioxus-cli` in
`flake.nix`.

## Caveats

- The nightly-only flags (`-Zshare-generics`, `-Zthreads`, cranelift) are the
  price of the speed. If a dependency ever fails to compile under cranelift,
  drop the `codegen-backend` line from `[profile.dev]` in `Cargo.toml`; nothing
  else depends on it.
- `.cargo/config.toml` targets Linux. The Windows block is there but untested.
