# Library flake for project build logic, plus `nix flake init` templates.
#
#   nix flake init -t git+ssh://git@github.com/schoderer/project_templates#rust   (or #go, #python)
#   nix flake check   build + test every template via the lib
#
# Projects consume `lib.<lang>.mkFlake` (see templates/<lang>/flake.nix and Readme.md).
{
  description = "Shared Nix build logic and project templates";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Python builds from uv.lock (uv2nix).
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs = {
        pyproject-nix.follows = "pyproject-nix";
        nixpkgs.follows = "nixpkgs";
      };
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs = {
        pyproject-nix.follows = "pyproject-nix";
        uv2nix.follows = "uv2nix";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      crane,
      rust-overlay,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
    }:
    let
      inherit (nixpkgs) lib;
      defaultSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forSystems = systems: f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # Turn a per-system `mkProject` into flake outputs for every system:
      #   outputs = { project-templates, ... }:
      #     project-templates.lib.<lang>.mkFlake { src = ./.; };
      # Every mkProject option (docker, buildInputs, ...) is accepted.
      mkFlakeFor =
        mkProject:
        {
          systems ? defaultSystems,
          ...
        }@args:
        let
          projectArgs = removeAttrs args [ "systems" ];
          perSystem = forSystems systems (pkgs: mkProject (projectArgs // { inherit pkgs; }));
        in
        {
          packages = lib.mapAttrs (_: p: p.packages) perSystem;
          checks = lib.mapAttrs (_: p: p.checks) perSystem;
          devShells = lib.mapAttrs (_: p: { default = p.devShell; }) perSystem;
          formatter = lib.mapAttrs (_: p: p.formatter) perSystem;
        };

      rust = import ./nix/rust.nix { inherit crane rust-overlay; };
      go = import ./nix/go.nix { };
      python = import ./nix/python.nix { inherit pyproject-nix uv2nix pyproject-build-systems; };

      # Self-test helper: a template's checks (+ docker image on Linux), prefixed.
      templateChecks =
        pkgs: prefix: project:
        lib.mapAttrs' (n: v: lib.nameValuePair "${prefix}-template-${n}" v) (
          project.checks
          // lib.optionalAttrs (pkgs.stdenv.hostPlatform.isLinux && project.packages ? dockerImage) {
            inherit (project.packages) dockerImage;
          }
        );
    in
    {
      lib = {
        rust = rust // {
          mkFlake = mkFlakeFor rust.mkProject;
        };
        go = go // {
          mkFlake = mkFlakeFor go.mkProject;
        };
        python = python // {
          mkFlake = mkFlakeFor python.mkProject;
        };
      };

      templates = {
        rust = {
          path = ./templates/rust;
          description = "Rust binary: crane build, cargo test check, docker image, devShell";
          welcomeText = ''
            # Rust project

            Rename `name = "app"` in Cargo.toml (and `# app` in Readme.md), then:

                direnv allow             # or: nix develop
                nix build                # binary  -> result/bin/<name>
                nix build .#dockerImage  # docker image (set `docker = false;` in flake.nix to drop it)
                nix flake check          # build + cargo test
                just                     # list recipes
          '';
        };

        go = {
          path = ./templates/go;
          description = "Go binary: buildGoModule, go test + go vet checks, docker image, devShell";
          welcomeText = ''
            # Go project

            Rename `module app` in go.mod (and `# app` in Readme.md), then:

                direnv allow             # or: nix develop
                nix build                # binary  -> result/bin/<name>
                nix build .#dockerImage  # docker image (set `docker = false;` in flake.nix to drop it)
                nix flake check          # build + go test + go vet
                just                     # list recipes

            After adding a dependency, set `vendorHash = "";` in flake.nix
            and copy the real hash from the `nix build` error.
          '';
        };

        python = {
          path = ./templates/python;
          description = "Python app: uv2nix build from uv.lock, pytest + ruff + ty checks, docker image, devShell";
          welcomeText = ''
            # Python project

            Rename the project from `app` (pyproject.toml `name` + `[project.scripts]`,
            the `src/app` directory, the import in tests/, Readme.md), then:

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
      };

      # Self-test: build every template through the lib.
      checks = forSystems defaultSystems (
        pkgs:
        templateChecks pkgs "rust" (
          rust.mkProject {
            inherit pkgs;
            src = ./templates/rust;
            clippy = true;
            fmt = true;
          }
        )
        // templateChecks pkgs "go" (
          go.mkProject {
            inherit pkgs;
            src = ./templates/go;
            lint = true;
          }
        )
        // templateChecks pkgs "python" (
          python.mkProject {
            inherit pkgs;
            src = ./templates/python;
            typecheck = true;
          }
        )
      );

      formatter = forSystems defaultSystems (pkgs: pkgs.nixfmt);
    };
}
