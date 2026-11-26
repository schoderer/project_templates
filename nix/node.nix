# Node/TypeScript project library: npm build from package-lock.json +
# vitest/biome/tsc checks + optional docker image.
#
#   lib.node.mkProject { pkgs, src, ... } => { packages, checks, devShell, formatter }
#
# Same contract as the other libs. `mkFlake` (in ../flake.nix) wraps it for
# every system and turns it into flake outputs.
# Options are documented in ../Readme.md (common table + language section).
let
  project = import ./project.nix;
in
{
  mkProject =
    {
      pkgs,
      src, # with package.json and package-lock.json
      kind ? "app", # "app" (node program) or "static" (built site, e.g. Vite or Angular)
      outDir ? "dist", # build output served for kind = "static"
      buildScript ? "build",
      nodejs ? null, # null: nixpkgs nodejs
      npmArgs ? { },
      library ? null, # null: auto-detect (app without "bin")
      docker ? null,
      test ? true, # npm test
      lint ? true, # biome lint
      typecheck ? true, # npm run typecheck
      extraChecks ? { },
      devPackages ? [ ],
      formatters ? [ ],
    }:
    let
      inherit (pkgs) lib;
      resolve = project.resolve pkgs;

      nodejs' = if nodejs != null then resolve nodejs else pkgs.nodejs;
      src' = project.filterSource pkgs src;

      packageJson = lib.importJSON (src + "/package.json");
      # Scoped packages (@scope/name) are named after the last part.
      pname = lib.last (lib.splitString "/" packageJson.name);
      bins =
        let
          b = packageJson.bin or { };
        in
        if builtins.isString b then { ${pname} = b; } else b;
      isStatic = kind == "static";
      isLibrary = if library != null then library else !isStatic && bins == { };
      # The bin named like the package, else the first one (docker entrypoint, `nix run`).
      mainProgram =
        if isStatic || bins ? ${pname} then
          pname
        else if bins != { } then
          builtins.head (builtins.attrNames bins)
        else
          pname;

      # node_modules from package-lock.json (its integrity hashes are the lock;
      # no extra hash in the flake), then `npm run <buildScript>`.
      built = (pkgs.buildNpmPackage.override { nodejs = nodejs'; }) (
        {
          inherit pname;
          version = packageJson.version or "0.0.0";
          src = src';
          npmDeps = pkgs.importNpmLock { npmRoot = src'; };
          npmConfigHook = pkgs.importNpmLock.npmConfigHook;
          npmBuildScript = buildScript;
          meta.mainProgram = mainProgram;
        }
        // lib.optionalAttrs isStatic {
          installPhase = ''
            runHook preInstall
            cp -r ${outDir} $out
            runHook postInstall
          '';
        }
        // resolve npmArgs
      );

      # kind = "static": the site, plus a program serving it (nix run, docker).
      site = built;
      server = pkgs.writeShellApplication {
        name = pname;
        runtimeInputs = [ pkgs.static-web-server ];
        text = ''
          exec static-web-server --root ${site} \
            --host "''${HOST:-0.0.0.0}" --port "''${PORT:-8080}" \
            --page-fallback ${site}/index.html "$@"
        '';
      };

      bin = if isStatic then server else built;

      # Run `cmd` with the project's node_modules installed (instead of building).
      npmCheck =
        name: cmd:
        built.overrideAttrs {
          pname = "${pname}-${name}";
          buildPhase = ''
            runHook preBuild
            ${cmd}
            runHook postBuild
          '';
          installPhase = "touch $out";
          dontFixup = true;
        };
    in
    lib.recursiveUpdate (project.mkOutputs {
      inherit
        pkgs
        pname
        mainProgram
        bin
        docker
        extraChecks
        isLibrary
        ;
      src = src';
      buildCheck = built;
      formatters = [ pkgs.biome ] ++ resolve formatters; # biome format

      checks =
        lib.optionalAttrs test { test = npmCheck "test" "npm test"; }
        // lib.optionalAttrs lint {
          lint = project.runInSource pkgs src' "${pname}-lint" [ pkgs.biome ] "biome lint";
        }
        // lib.optionalAttrs typecheck { typecheck = npmCheck "typecheck" "npm run typecheck"; };

      devShell =
        formatter:
        pkgs.mkShell {
          packages = [
            nodejs'
            pkgs.biome
            formatter
          ]
          ++ resolve devPackages;
        };
    }) { packages = lib.optionalAttrs isStatic { inherit site; }; };
}
