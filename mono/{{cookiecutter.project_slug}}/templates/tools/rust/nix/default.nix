# Build definition of the __NAME__ tool (the project contract, see tools/README.md).
#
# Called by ../flake.nix (standalone) and by the root flake (monorepo) with
#   pkgs    nixpkgs for the target system
#   inputs  flake inputs; `inputs.crane` is used here
{ pkgs, inputs }:
let
  craneLib = inputs.crane.mkLib pkgs;

  # Only Cargo.toml, Cargo.lock and Rust sources: editing docs or nix files
  # does not cause a rebuild.
  src = craneLib.cleanCargoSource ../.;

  commonArgs = {
    inherit src;
    strictDeps = true;
    # Native dependencies go here, e.g. nativeBuildInputs = [ pkgs.pkg-config ];
    # buildInputs = [ pkgs.openssl ];
  };

  # Dependencies are compiled once and shared by the binary and every check.
  cargoArtifacts = craneLib.buildDepsOnly commonArgs;

  bin = craneLib.buildPackage (
    commonArgs
    // {
      inherit cargoArtifacts;
      doCheck = false; # tests run as their own check below
      meta.mainProgram = "__NAME__";
    }
  );
in
{
  # Tools provide no docker image.
  packages.default = bin;

  checks = {
    clippy = craneLib.cargoClippy (
      commonArgs
      // {
        inherit cargoArtifacts;
        cargoClippyExtraArgs = "--all-targets -- --deny warnings";
      }
    );
    fmt = craneLib.cargoFmt { inherit src; };
    test = craneLib.cargoTest (commonArgs // { inherit cargoArtifacts; });
  };

  # cargo, rustc, clippy and rustfmt come with craneLib.devShell.
  devShell = craneLib.devShell {
    packages = with pkgs; [
      rust-analyzer
      cargo-watch
    ];
  };
}
