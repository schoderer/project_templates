{
  description = "Flake for {{ cookiecutter.project_slug }}";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    goflake = {
      url = "github:sagikazarmark/go-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, goflake, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ goflake.overlay ];
        };
        devDeps = with pkgs; [
          go
          gopls # go lang server
          delve # debugging 
        ];
      in
      { 
        devShells.default = pkgs.mkShell {
          buildInputs = devDeps; 
        }; 
      }
    );
}
