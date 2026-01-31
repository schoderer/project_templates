{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          overlays = [ ];
          pkgs = import nixpkgs {
            inherit system overlays;
          };
          args = {
            nativeBuildInputs = with pkgs; [ ];
            buildInputs = with pkgs; [ ];
          };
        in
        with pkgs;
        {
          devShells.default = mkShell {
            nativeBuildInputs = args.nativeBuildInputs;
            buildInputs = args.buildInputs;
            packages = with pkgs; [
              # godot

              godot-mono
              dotnet-sdk
            ];
          };
        }
      );
}
