# Rust project library: crane build + cargo test/clippy + optional docker image.
#
#   lib.rust.mkProject { pkgs, src, ... } => { packages, checks, devShell, formatter }
#
# `mkFlake` (in ../flake.nix) wraps it for every system and turns it into
# flake outputs; a monorepo can also call mkProject per project directly.
# Options are documented in ../Readme.md (common table + language section).
{ crane, rust-overlay }:
let
  project = import ./project.nix;
in
{
  mkProject =
    {
      pkgs,
      src,
      toolchain ? null, # null: rust-toolchain.toml if present, else stable latest
      nativeBuildInputs ? [ ],
      buildInputs ? [ ],
      craneArgs ? { },
      library ? null, # null: auto-detect
      docker ? null,
      test ? true, # cargo test
      lint ? true, # clippy
      extraChecks ? { },
      devPackages ? [ ],
      formatters ? [ ],
    }:
    let
      inherit (pkgs) lib;

      # Accept plain nixpkgs as well as nixpkgs with rust-overlay applied.
      pkgs' = if pkgs ? rust-bin then pkgs else pkgs.extend rust-overlay.overlays.default;
      resolve = project.resolve pkgs';

      toolchainFile = src + "/rust-toolchain.toml";
      rustToolchain =
        if toolchain != null then
          toolchain pkgs'
        else if builtins.pathExists toolchainFile then
          pkgs'.rust-bin.fromRustupToolchainFile toolchainFile
        else
          pkgs'.rust-bin.stable.latest.default.override {
            extensions = [
              "rust-analyzer"
              "rust-src"
              "clippy"
              "rustfmt"
            ];
          };

      craneLib = (crane.mkLib pkgs').overrideToolchain (_: rustToolchain);
      src' = project.filterSource pkgs' src;
      craneArgs' = resolve craneArgs;

      pname = craneArgs'.pname or (craneLib.crateNameFromCargoToml { inherit src; }).pname;

      args = {
        src = craneLib.cleanCargoSource src';
        strictDeps = true;
        nativeBuildInputs = [ pkgs'.pkg-config ] ++ resolve nativeBuildInputs;
        buildInputs = [ pkgs'.openssl ] ++ resolve buildInputs;
        meta.mainProgram = pname;
      }
      // craneArgs';

      cargoToml = builtins.readFile (src + "/Cargo.toml");
      hasBin =
        builtins.pathExists (src + "/src/main.rs")
        || builtins.pathExists (src + "/src/bin")
        || lib.hasInfix "[[bin]]" cargoToml
        || lib.hasInfix "[workspace]" cargoToml;

      cargoArtifacts = craneLib.buildDepsOnly args;
      bin = craneLib.buildPackage (args // { inherit cargoArtifacts; });
    in
    project.mkOutputs {
      pkgs = pkgs';
      src = src';
      inherit
        pname
        bin
        docker
        extraChecks
        ;
      isLibrary = if library != null then library else !hasBin;
      formatters = [ rustToolchain ] ++ resolve formatters; # rustfmt, same version as `cargo fmt`

      checks =
        lib.optionalAttrs test {
          test = craneLib.cargoTest (args // { inherit cargoArtifacts; });
        }
        // lib.optionalAttrs lint {
          lint = craneLib.cargoClippy (
            args
            // {
              inherit cargoArtifacts;
              cargoClippyExtraArgs = "--all-targets -- --deny warnings";
            }
          );
        };

      devShell =
        formatter:
        craneLib.devShell {
          inputsFrom = [ bin ];
          packages = [
            pkgs'.bacon
            formatter
          ]
          ++ resolve devPackages;
        };
    };
}
