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

        # Configure the rust toolchain.
        #
        # Stable. Nothing in this repo needs nightly: .cargo/config.toml and the
        # profiles in Cargo.toml only use flags that are stable. Pin an exact
        # release with `pkgs.rust-bin.stable."<version>".default` if you want the
        # toolchain to stop moving when nixpkgs updates.
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [
            "rust-analyzer"
            "rust-src"
            "clippy"
            "rustfmt"
          ];
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

        # Tools that only matter inside the dev shell, not in the release build.
        devTools = with pkgs; [
          just
          bacon
          # Uncomment for `just hotpatch`. Needs to match the subsecond version
          # Bevy was built against, so pin it if it misbehaves.
          # dioxus-cli
        ];

        cargoArtifacts = craneLib.buildDepsOnly args;
        bin = craneLib.buildPackage (args // { inherit cargoArtifacts; });
      in with pkgs; {
        packages = {
          inherit bin;
          default = bin;
        };
        devShells.default = mkShell {
          nativeBuildInputs = args.nativeBuildInputs ++ devTools;
          buildInputs = args.buildInputs;
          RUST_BACKTRACE = "1";
          LD_LIBRARY_PATH = lib.makeLibraryPath args.buildInputs;
        };

      }
    );
}
