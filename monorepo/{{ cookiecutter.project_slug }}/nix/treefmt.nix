# Repo-wide formatting via the treefmt-nix flake-parts module.
# Wires up `nix fmt`, a formatter package, and a formatting check
# (which `nix flake check` picks up automatically).
{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem = {
    treefmt = {
      projectRootFile = "flake.nix";
      programs = {
        nixfmt.enable = true; # *.nix
        rustfmt.enable = true; # Rust services
      };
    };
  };
}
