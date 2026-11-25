# Build definition of the __NAME__ tool (the project contract, see tools/README.md).
#
# Called by ../flake.nix (standalone) and by the root flake (monorepo) with
#   pkgs    nixpkgs for the target system
#   inputs  flake inputs (unused here)
#
# Tools provide no docker image.
{ pkgs, ... }:
let
  inherit (pkgs) lib;

  # Only Go sources and module files: editing docs or nix files does not cause a rebuild.
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../go.mod
      (lib.fileset.maybeMissing ../go.sum)
      (lib.fileset.fileFilter (file: file.hasExt "go") ../.)
    ];
  };

  version = "0.1.0";

  bin = pkgs.buildGoModule {
    pname = "__NAME__";
    inherit version;
    inherit src;

    # Hash of the downloaded dependencies. `null` while go.mod has no
    # requirements; after adding one, set it to `lib.fakeHash`, run `nix build`
    # and copy the hash from the error message.
    vendorHash = null;

    # Static binary, so it runs anywhere.
    env.CGO_ENABLED = 0;
    ldflags = [
      "-s"
      "-w"
      "-X main.version=${version}" # reported by `__NAME__ version`
    ];

    # `go test ./...` runs in the build's checkPhase, so a failing test fails `nix build`.
    meta.mainProgram = "__NAME__";
  };

in
{
  packages.default = bin;

  checks = {
    # Reuses the module setup of the build, but only runs `go vet`.
    vet = bin.overrideAttrs {
      pname = "__NAME__-vet";
      buildPhase = "go vet ./...";
      doCheck = false;
      installPhase = "touch $out";
    };
    fmt = pkgs.runCommand "__NAME__-gofmt" { nativeBuildInputs = [ pkgs.go ]; } ''
      unformatted=$(gofmt -l ${src})
      if [ -n "$unformatted" ]; then
        echo "not gofmt-formatted (run: nix fmt):" >&2
        echo "$unformatted" >&2
        exit 1
      fi
      touch $out
    '';
  };

  devShell = pkgs.mkShell {
    packages = with pkgs; [
      go
      gopls
      gotools # goimports, ...
    ];
    # Same as the nix build: no cgo.
    CGO_ENABLED = 0;
  };
}
