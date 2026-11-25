{
  description = "Flake for {{ cookiecutter.project_slug }}";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        # Add the tools this project needs here (search: nix search nixpkgs <name>)
        devDeps = with pkgs; [
          just
          # jq
          # nodejs
          # python3
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          packages = devDeps;

          # Environment variables for the shell, e.g.:
          # MY_VAR = "value";

          shellHook = ''
          '';
        };

        formatter = pkgs.nixfmt;
      }
    );
}
