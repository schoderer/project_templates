# Library flake for project build logic, plus `nix flake init` templates.
#
#   nix flake init -t github:schoderer/project_templates#rust   scaffold a project
#   nix flake check                                              build + test every template via the lib
#
# Projects consume `lib.rust.mkFlake` (see templates/rust/flake.nix and Readme.md).
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

      rust = import ./nix/rust.nix { inherit crane rust-overlay; };
    in
    {
      lib.rust = rust // {
        # Flake outputs for a single-crate project:
        #   outputs = { project-templates, ... }:
        #     project-templates.lib.rust.mkFlake { src = ./.; };
        # Every mkProject option (docker, clippy, buildInputs, ...) is accepted.
        mkFlake =
          {
            systems ? defaultSystems,
            ...
          }@args:
          let
            projectArgs = removeAttrs args [ "systems" ];
            perSystem = forSystems systems (pkgs: rust.mkProject (projectArgs // { inherit pkgs; }));
          in
          {
            packages = lib.mapAttrs (_: p: p.packages) perSystem;
            checks = lib.mapAttrs (_: p: p.checks) perSystem;
            devShells = lib.mapAttrs (_: p: { default = p.devShell; }) perSystem;
          };
      };

      templates.rust = {
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

      # Self-test: build every template through the lib.
      checks = forSystems defaultSystems (
        pkgs:
        let
          project = rust.mkProject {
            inherit pkgs;
            src = ./templates/rust;
            clippy = true;
            fmt = true;
          };
        in
        lib.mapAttrs' (n: v: lib.nameValuePair "rust-template-${n}" v) (
          project.checks // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux { inherit (project.packages) dockerImage; }
        )
      );

      formatter = forSystems defaultSystems (pkgs: pkgs.nixfmt);
    };
}
