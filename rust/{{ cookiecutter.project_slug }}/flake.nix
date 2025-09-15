{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };
  };
  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-analyzer" "rust-src" ];
        };
        
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
        src = craneLib.cleanCargoSource ./.;

        args = {
          nativeBuildInputs = with pkgs; [ rustToolchain pkg-config bacon ];
          buildInputs = with pkgs; [ openssl ];
          inherit src;
        };

        cargoArtifacts = craneLib.buildDepsOnly args;
        bin = craneLib.buildPackage (args // { inherit cargoArtifacts; });

        dockerImage = pkgs.dockerTools.buildImage {
          name = "ghcr.io/schoderer/{{ cookiecutter.project_slug }}";
          tag = "latest";
          copyToRoot = [ bin ];
          config = { Cmd = [ "${bin}/bin/{{ cookiecutter.project_slug }}" ]; };
        };
      in with pkgs; {
        packages = {
          inherit bin dockerImage;
          default = bin;
        };
        devShells.default = mkShell {
          nativeBuildInputs = args.nativeBuildInputs;
          buildInputs = args.buildInputs;
        };
      });
}

