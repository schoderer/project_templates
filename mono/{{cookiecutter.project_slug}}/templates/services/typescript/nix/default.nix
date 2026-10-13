# Build definition of the __NAME__ service (the project contract, see services/README.md).
#
# Called by ../flake.nix (standalone) and by the root flake (monorepo) with
#   pkgs    nixpkgs for the target system
#   inputs  flake inputs (unused here)
#
# Tooling (node, tsc, biome) comes from nixpkgs; libraries come from npm via
# package-lock.json, which `importNpmLock` reads directly (no hash to update).
{ pkgs, ... }:
let
  inherit (pkgs) lib;
  packageJson = lib.importJSON ../package.json;
  nodejs = pkgs.nodejs;

  # Only the files the build needs: editing docs or nix files does not cause a rebuild.
  sourceFiles = lib.fileset.unions [
    ../package.json
    ../package-lock.json
    ../tsconfig.json
    ../src
  ];
  src = lib.fileset.toSource {
    root = ../.;
    fileset = sourceFiles;
  };

  bin = pkgs.buildNpmPackage {
    pname = packageJson.name;
    inherit (packageJson) version;
    inherit src nodejs;

    npmDeps = pkgs.importNpmLock { npmRoot = src; };
    npmConfigHook = pkgs.importNpmLock.npmConfigHook;

    # `npm run build` calls tsc, which comes from nixpkgs (see devShell).
    nativeBuildInputs = [ pkgs.typescript ];

    # Unit tests run against the compiled output, so a failing test fails `nix build`.
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      npm test
      runHook postCheck
    '';

    meta.mainProgram = "__NAME__";
  };

  docker = pkgs.dockerTools.buildLayeredImage {
    name = "__NAME__";
    tag = bin.version;
    # CA certificates for outgoing TLS; the image otherwise only holds the binary's closure.
    contents = [ pkgs.cacert ];
    config = {
      Cmd = [ (lib.getExe bin) ];
      Env = [
        "PORT=8080"
        "NODE_ENV=production"
      ];
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
    biome =
      pkgs.runCommand "__NAME__-biome"
        {
          nativeBuildInputs = [ pkgs.biome ];
          src = lib.fileset.toSource {
            root = ../.;
            fileset = lib.fileset.unions [
              sourceFiles
              ../biome.json
            ];
          };
        }
        ''
          cd $src
          biome ci .
          touch $out
        '';
  };

  devShell = pkgs.mkShell {
    packages = [
      nodejs
      pkgs.typescript
      pkgs.biome
    ];
  };
}
