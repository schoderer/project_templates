# Build definition of the __NAME__ tool (the project contract, see tools/README.md).
#
# Called by ../flake.nix (standalone) and by the root flake (monorepo) with
#   pkgs    nixpkgs for the target system
#   inputs  flake inputs (unused here)
#
# This is the language-agnostic starting point: a bash script. For any other
# language keep the returned shape ({ packages, checks, devShell }) and replace
# `bin` with that language's build, for example:
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
# Tools provide no docker image.
{ pkgs, ... }:
let
  version = "0.1.0";

  # writeShellApplication runs shellcheck on the script at build time.
  bin = pkgs.writeShellApplication {
    name = "__NAME__";
    runtimeInputs = [ pkgs.coreutils ];
    runtimeEnv.VERSION = version;
    text = builtins.readFile ../src/main.sh;
  };
in
{
  packages.default = bin;

  checks = {
    # Black-box tests against the built binary.
    test = pkgs.runCommand "__NAME__-test" { nativeBuildInputs = [ bin ]; } ''
      bash ${../tests/test.sh}
      touch $out
    '';
  };

  devShell = pkgs.mkShell {
    packages = [ pkgs.shellcheck ];
  };
}
