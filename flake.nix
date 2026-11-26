# Library flake for project build logic, plus `nix flake init` templates.
#
#   nix flake init -t git+ssh://git@github.com/schoderer/project_templates#rust   (or #go, #python, #python-torch, #node, #vite)
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
      nixpkgs,
      crane,
      rust-overlay,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      ...
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

      langs = {
        rust = import ./nix/rust.nix { inherit crane rust-overlay; };
        go = import ./nix/go.nix;
        python = import ./nix/python.nix { inherit pyproject-nix uv2nix pyproject-build-systems; };
        node = import ./nix/node.nix;
      };

      templates = import ./nix/templates.nix;
      templatePath = name: ./templates + "/${name}";

      # Self-test: a template built through its lib, all checks (+ the docker
      # image, which only exists on Linux) prefixed with `<name>-template-`.
      templateChecks =
        pkgs: name: t:
        let
          project = langs.${t.lang}.mkProject (
            {
              inherit pkgs;
              src = templatePath name;
            }
            // t.selfTest
          );
        in
        lib.mapAttrs' (n: v: lib.nameValuePair "${name}-template-${n}" v) (
          project.checks
          // lib.optionalAttrs (project.packages ? dockerImage) { inherit (project.packages) dockerImage; }
        );
    in
    {
      lib = lib.mapAttrs (_: l: l // { mkFlake = mkFlakeFor l.mkProject; }) langs;

      templates = lib.mapAttrs (name: t: {
        path = templatePath name;
        inherit (t) description welcomeText;
      }) templates;

      checks = forSystems defaultSystems (pkgs: lib.concatMapAttrs (templateChecks pkgs) templates);

      formatter = forSystems defaultSystems (pkgs: pkgs.nixfmt);
    };
}
