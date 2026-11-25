# Build definition of the __NAME__ service (the project contract, see services/README.md).
#
# Called by ../flake.nix (standalone) and by the root flake (monorepo) with
#   pkgs    nixpkgs for the target system
#   inputs  flake inputs (unused here)
#
# This is the language-agnostic starting point: a static file server
# (darkhttpd) serving ./public. For any other language keep the returned shape
# ({ packages, compose, checks, devShell }) and replace `bin` with that
# language's build, for example:
#
#   bin = pkgs.stdenv.mkDerivation {
#     pname = "__NAME__";
#     inherit version;
#     src = lib.fileset.toSource { root = ../.; fileset = ../src; };
#     nativeBuildInputs = [ pkgs.zig ];      # compiler / build tool
#     buildPhase = "zig build-exe main.zig"; # compile
#     doCheck = true;
#     checkPhase = "zig test main.zig";      # unit tests fail the build
#     installPhase = "install -Dm755 main $out/bin/__NAME__";
#     meta.mainProgram = "__NAME__";
#   };
#
# nixpkgs has dedicated builders for most ecosystems (maven, gradle, dotnet,
# mix, ...); see https://nixos.org/manual/nixpkgs/stable/#chap-language-support
#
# The image, compose entry and checks below work unchanged for any `bin` that
# serves HTTP on $PORT.
{ pkgs, ... }:
let
  inherit (pkgs) lib;
  version = "0.1.0";

  # Static content, copied into the nix store (and so into the image).
  public = ../public;

  bin = pkgs.writeShellApplication {
    name = "__NAME__";
    runtimeInputs = [ pkgs.darkhttpd ];
    text = ''
      exec darkhttpd ${public} --addr 0.0.0.0 --port "''${PORT:-8080}" --no-listing
    '';
    derivationArgs = { inherit version; };
  };

  docker = pkgs.dockerTools.buildLayeredImage {
    name = "__NAME__";
    tag = version;
    config = {
      Cmd = [ (lib.getExe bin) ];
      Env = [ "PORT=8080" ];
      ExposedPorts."8080/tcp" = { };
      User = "65534:65534"; # nobody
      Labels = {
        "org.opencontainers.image.title" = "__NAME__";
        "org.opencontainers.image.version" = version;
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
    # environment.LOG_LEVEL = "debug";
    # depends_on = [ "postgres" ];
  };

  checks = {
    # Starts the server inside the build sandbox and probes it over HTTP.
    smoke =
      pkgs.runCommand "__NAME__-smoke"
        {
          nativeBuildInputs = [
            bin
            pkgs.curl
          ];
        }
        ''
          export PORT=18080
          __NAME__ &
          bash ${../tests/smoke.sh} "http://127.0.0.1:$PORT"
          kill %1
          touch $out
        '';
  };

  devShell = pkgs.mkShell {
    packages = [
      pkgs.darkhttpd
      pkgs.curl
      pkgs.shellcheck
    ];
  };
}
