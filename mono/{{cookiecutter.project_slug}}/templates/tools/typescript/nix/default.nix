# Build definition of the __NAME__ tool (the project contract, see tools/README.md).
#
# Called by ../flake.nix (standalone) and by the root flake (monorepo) with
#   pkgs    nixpkgs for the target system
#   inputs  flake inputs (unused here)
#
# Tooling (node, tsc, biome) comes from nixpkgs; libraries come from npm via
# package-lock.json, which `importNpmLock` reads directly (no hash to update).
# Tools provide no docker image.
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

in
{
  packages.default = bin;

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
