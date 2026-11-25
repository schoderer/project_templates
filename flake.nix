# Library flake for project build logic, plus `nix flake init` templates.
#
#   nix flake init -t git+ssh://git@github.com/schoderer/project_templates#rust   (or #go)
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
  };

  outputs =
    {
      self,
      nixpkgs,
      crane,
      rust-overlay,
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
      lib.rust = rust // {
        mkFlake = mkFlakeFor rust.mkProject;
      };
      lib.go = go // {
        mkFlake = mkFlakeFor go.mkProject;
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
      );

      formatter = forSystems defaultSystems (pkgs: pkgs.nixfmt);
    };
}
