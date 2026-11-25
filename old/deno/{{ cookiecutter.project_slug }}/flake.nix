{
  description = "Flake for {{ cookiecutter.project_slug }}";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils,  ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
      
        pkgs = import nixpkgs {
          inherit system;
        };

        devDeps = with pkgs; [
          deno
          typescript-language-server
          
        ];
      in
      { 
        devShells.default = pkgs.mkShell {
          buildInputs = devDeps; 
        }; 
      }
    );
}
