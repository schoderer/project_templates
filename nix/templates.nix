# One entry per templates/<name>/. ../flake.nix turns this into
#   templates.<name>                      for `nix flake init -t …#<name>`
#   checks.<system>.<name>-template-*     the self-test: the template built through lib.<lang>
# `selfTest` is passed to lib.<lang>.mkProject on top of the defaults (turn on
# every opt-in gate so the template is tested with all of them).
{
  rust = {
    lang = "rust";
    description = "Rust binary: crane build, cargo test + clippy checks, docker image, devShell";
    selfTest = { };
    welcomeText = ''
      # Rust project

      Rename `app`: `name` in Cargo.toml, `description` in flake.nix and the
      title in Readme.md. Then:

          direnv allow             # or: nix develop
          cargo check              # updates Cargo.lock to the new name
          nix build                # binary  -> result/bin/<name>
          nix build .#dockerImage  # docker image (set `docker = false;` in flake.nix to drop it)
          nix flake check          # build + cargo test + clippy + formatting
          just                     # list recipes
    '';
  };

  go = {
    lang = "go";
    description = "Go binary: buildGoModule, go test + go vet checks, docker image, devShell";
    selfTest = {
      golangciLint = true;
    };
    welcomeText = ''
      # Go project

      Rename `app`: `module` in go.mod, `description` in flake.nix and the
      title in Readme.md. Then:

          direnv allow             # or: nix develop
          nix build                # binary  -> result/bin/<name>
          nix build .#dockerImage  # docker image (set `docker = false;` in flake.nix to drop it)
          nix flake check          # build + go test + go vet + formatting
          just                     # list recipes

      After adding a dependency, set `vendorHash = "";` in flake.nix
      and copy the real hash from the `nix build` error.
    '';
  };

  python = {
    lang = "python";
    description = "Python app: uv2nix build from uv.lock, pytest + ruff + ty checks, docker image, devShell";
    selfTest = {
      typecheck = true;
    };
    welcomeText = ''
      # Python project

      Rename `app`: pyproject.toml `name` + `[project.scripts]`, the src/app
      directory, the import in tests/, the `run` recipe in the justfile,
      `description` in flake.nix and the title in Readme.md. Then:

          uv lock                  # re-resolve under the new name
          direnv allow             # or: nix develop
          uv sync                  # .venv for your editor
          nix build                # app    -> result/bin/<script>
          nix build .#dockerImage  # docker image (set `docker = false;` in flake.nix to drop it)
          nix flake check          # build + pytest + ruff check + ty + formatting
          just                     # list recipes

      Dependencies: `uv add <pkg>`. Nix builds from uv.lock, so there is no hash to update.
    '';
  };
}
