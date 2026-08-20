{
  description = "Flake for {{ cookiecutter.project_slug }}";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        devDeps = with pkgs.elmPackages; [
          elm
          elm-language-server
          elm-format
          elm-test
          elm-review
          elm-live
        ] ++ (with pkgs; [
          nodejs
        ]);
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = devDeps;
        };
      }
    );
}
