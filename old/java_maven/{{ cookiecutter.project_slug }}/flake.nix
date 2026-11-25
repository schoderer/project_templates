{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
    (system:
    let
      overlays = [
        (final: prev: rec {
          jdk = prev."jdk{{ cookiecutter.java_version }}";
          maven = prev.maven.override { jdk_headless = jdk; };
        })
      ];
      pkgs = import nixpkgs { inherit overlays system; };
     
    in
    {
      devShells = {
        default = pkgs.mkShell {
          packages = with pkgs; [ jdk maven ];
        };
      };
    });
}
