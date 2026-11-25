# Standalone flake for the __NAME__ tool.
#
#   nix build              binary
#   nix run . -- --help    run it
#   nix flake check        biome, build (runs tsc and node --test)
#   nix develop            Node/TypeScript tooling
#
# The root flake does not use this file: it imports ./nix/default.nix directly,
# so all build logic belongs there. Only declare inputs that the root flake also
# has; `nix run .#sync-locks` (repo root) pins them to the root's revisions.
{
  description = "__NAME__ tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/{{ cookiecutter.nixpkgs_branch }}";
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
