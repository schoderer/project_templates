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
        # Nightly is required by .cargo/config.toml (-Zshare-generics, -Zthreads,
        # the cranelift codegen backend). `selectLatestNightlyWith` picks the most
        # recent nightly that actually ships every component below -- plain
        # `nightly.latest` breaks whenever one of them is missing for a day.
        rustToolchain = pkgs.rust-bin.selectLatestNightlyWith (toolchain:
          toolchain.default.override {
            extensions = [
              "rust-analyzer"
              "rust-src"
              "clippy"
              "rustfmt"
              "rustc-codegen-cranelift-preview"
            ];
          });

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
