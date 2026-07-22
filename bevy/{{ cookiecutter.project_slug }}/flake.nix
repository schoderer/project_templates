{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };
    crane.url = "github:ipetkov/crane";
  };
  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Import packages with overlay
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

        # Configure the rust toolchain
        rustToolchain = pkgs.rust-bin.nightly.latest.default.override {
          extensions = [ "rust-analyzer" "rust-src" "clippy" "rustfmt" ];
        };
        
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
        src = craneLib.cleanCargoSource ./.;

        ##########
        # Required Packages
        ##########
        args = {
          nativeBuildInputs = with pkgs; [
            rustToolchain
            pkg-config
            bacon

            # Build
            clang
            lld
            mold
          ];
          buildInputs = with pkgs; [
            # Dependencies
            vulkan-loader
            alsa-lib
            libudev-zero
            # wayland
            wayland
            libxkbcommon
          ];
          inherit src;
        };

        cargoArtifacts = craneLib.buildDepsOnly args;
        bin = craneLib.buildPackage (args // { inherit cargoArtifacts; });
      in with pkgs; {
        packages = {
          inherit bin;
          default = bin;
        };
        devShells.default = mkShell {
          nativeBuildInputs = args.nativeBuildInputs;
          buildInputs = args.buildInputs;
        LD_LIBRARY_PATH = lib.makeLibraryPath [
              vulkan-loader
              libxkbcommon
              wayland
            ];
        };

      }
    );
}

