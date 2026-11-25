# Build definition of the __NAME__ service (the project contract, see services/README.md).
#
# Called by ../flake.nix (standalone) and by the root flake (monorepo) with
#   pkgs    nixpkgs for the target system
#   inputs  flake inputs (unused here)
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

  bin = pkgs.buildGoModule {
    pname = "__NAME__";
    version = "0.1.0";
    inherit src;

    # Hash of the downloaded dependencies. `null` while go.mod has no
    # requirements; after adding one, set it to `lib.fakeHash`, run `nix build`
    # and copy the hash from the error message.
    vendorHash = null;

    # Static binary: the docker image needs no libc.
    env.CGO_ENABLED = 0;
    ldflags = [
      "-s"
      "-w"
    ];

    # `go test ./...` runs in the build's checkPhase, so a failing test fails `nix build`.
    meta.mainProgram = "__NAME__";
  };

  docker = pkgs.dockerTools.buildLayeredImage {
    name = "__NAME__";
    tag = bin.version;
    # CA certificates for outgoing TLS; the image otherwise only holds the binary.
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
    # environment.LOG_LEVEL = "debug";
    # depends_on = [ "postgres" ];
  };

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
