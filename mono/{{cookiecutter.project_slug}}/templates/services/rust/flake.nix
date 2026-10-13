# Standalone flake for the __NAME__ service.
#
#   nix build              binary
#   nix build .#docker     docker image (result is a .tar.gz for `docker load`)
#   nix flake check        clippy, rustfmt, tests, build
#   nix develop            Rust tooling
#
# The root flake does not use this file: it imports ./nix/default.nix directly,
# so all build logic belongs there. Only declare inputs that the root flake also
# has; `nix run .#sync-locks` (repo root) pins them to the root's revisions.
{
  description = "__NAME__ service";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/{{ cookiecutter.nixpkgs_branch }}";
    crane.url = "github:ipetkov/crane";
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      systems = [
{%- for system in cookiecutter.systems.split(",") %}
        "{{ system }}"
{%- endfor %}
      ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import ./nix {
              pkgs = nixpkgs.legacyPackages.${system};
              inherit inputs;
            }
          )
        );
    in
    {
      packages = forAllSystems (project: project.packages);
      # The binary is a check too, matching the root flake's <name>-build check.
      checks = forAllSystems (project: project.checks // { build = project.packages.default; });
      devShells = forAllSystems (project: {
        default = project.devShell;
      });
    };
}
