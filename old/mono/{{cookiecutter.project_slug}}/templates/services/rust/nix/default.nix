# Build definition of the __NAME__ service (the project contract, see services/README.md).
#
# Called by ../flake.nix (standalone) and by the root flake (monorepo) with
#   pkgs    nixpkgs for the target system
#   inputs  flake inputs; `inputs.crane` is used here
{ pkgs, inputs }:
let
  inherit (pkgs) lib;
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

  docker = pkgs.dockerTools.buildLayeredImage {
    name = "__NAME__";
    tag = bin.version;
    # CA certificates for outgoing TLS; the image otherwise only holds the binary's closure.
    contents = [ pkgs.cacert ];
    config = {
      Cmd = [ (lib.getExe bin) ];
      Env = [ "PORT=8080" ];
      ExposedPorts."8080/tcp" = { };
      User = "65534:65534"; # nobody
      Labels = {
        "org.opencontainers.image.title" = "__NAME__";
        "org.opencontainers.image.version" = bin.version;
      };
    };
  };
in
{
  packages = {
    default = bin;
    inherit docker;
  };

  # Merged into this service's entry of the root compose file (`just up`).
  # The host port was picked by the scaffolder; any compose key works here.
  compose = {
    ports = [ "__PORT__:8080" ];
    # environment.RUST_LOG = "debug";
    # depends_on = [ "postgres" ];
  };

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
