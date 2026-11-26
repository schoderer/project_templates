# One entry per templates/<name>/. ../flake.nix turns this into
#   templates.<name>                      for `nix flake init -t …#<name>`
#   checks.<system>.<name>-template-*     the self-test: the template built through lib.<lang>
# `selfTest` is passed to lib.<lang>.mkProject on top of the defaults: repeat
# the options the template's flake.nix sets (e.g. `kind`) and turn on every
# opt-in gate so the template is tested with all of them.
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

      Rename `app`: `module` in go.mod, `/app` in .gitignore, `description`
      in flake.nix and the title in Readme.md. Then:

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

  vite = {
    lang = "node";
    description = "Vite + React + TypeScript frontend: npm build from package-lock.json, vitest + biome + tsc checks, static site + server, docker image, devShell";
    selfTest = {
      kind = "static";
    };
    welcomeText = ''
      # Vite + React project

      Rename `app`: `name` in package.json, `description` in flake.nix, the
      `<title>` in index.html, the heading in src/App.tsx and Readme.md. Then:

          direnv allow             # or: nix develop
          npm install              # node_modules for the editor (updates package-lock.json after the rename)
          npm run dev              # Vite dev server
          nix build                # result/bin/<name> serves the built site on :8080 (packages.site is dist/)
          nix build .#dockerImage  # docker image (set `docker = false;` in flake.nix to drop it)
          nix flake check          # build + vitest + tsc + biome lint + formatting
          just                     # list recipes

      Dependencies: `npm install <pkg>`. Nix builds from package-lock.json, so there is no hash to update.
    '';
  };

  node = {
    lang = "node";
    description = "TypeScript Node app: npm build from package-lock.json, vitest + biome + tsc checks, docker image, devShell";
    selfTest = { };
    welcomeText = ''
      # TypeScript Node project

      Rename `app`: `name` and `bin` in package.json, `description` in flake.nix
      and the title in Readme.md. Then:

          direnv allow             # or: nix develop
          npm install              # node_modules for the editor (updates package-lock.json after the rename)
          npm run dev              # run from source, restart on changes
          nix build                # app -> result/bin/<name>
          nix build .#dockerImage  # docker image (set `docker = false;` in flake.nix to drop it)
          nix flake check          # build + vitest + tsc + biome lint + formatting
          just                     # list recipes

      Dependencies: `npm install <pkg>`. Nix builds from package-lock.json, so there is no hash to update.
    '';
  };

  python-torch = {
    lang = "python";
    description = "PyTorch on AMD GPUs: torch from the ROCm wheel index via uv (no container), Python and torch pinned, pytest + ruff checks, devShell";
    selfTest = {
      python = pkgs: pkgs.python314;
      checkGroups = [ "dev" ];
    };
    welcomeText = ''
      # PyTorch (ROCm) project

      Rename `app`: pyproject.toml `name`, the src/app directory, the import in
      tests/, `description` in flake.nix and the title in Readme.md. Then:

          uv lock                  # re-resolve under the new name (keeps the pinned torch)
          direnv allow             # or: nix develop
          uv sync                  # .venv with the ROCm torch (first time: several GB, shared via the uv cache)
          just gpu-check           # versions, visible GPUs and a matmul on each
          just run scripts/x.py    # run your scripts with the GPU torch
          nix flake check          # pytest (torch tests skipped) + ruff check + formatting
          just                     # list recipes

      torch and Python are pinned by the template, so projects share one torch download.
      Upgrade a project's torch on purpose with `uv lock --upgrade-package torch`.
    '';
  };
}
