# Python project library: uv2nix build from uv.lock + pytest/ruff/ty checks +
# optional docker image.
#
#   lib.python.mkProject { pkgs, src, ... } => { packages, checks, devShell, formatter }
#
# Same contract as nix/rust.nix and nix/go.nix. `mkFlake` (in ../flake.nix)
# wraps it for every system and turns it into flake outputs.
# Options are documented in ../Readme.md (common table + language section).
{
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
}:
let
  project = import ./project.nix;
in
{
  mkProject =
    {
      pkgs,
      src, # with pyproject.toml and uv.lock
      python ? null, # null: nixpkgs python3
      sourcePreference ? "wheel",
      # `pkgs: final: prev: { … }`. Always takes pkgs first: an overlay is a
      # function itself, so the `pkgs -> value` convention would be ambiguous.
      pythonOverrides ? (
        _pkgs: _final: _prev:
        { }
      ),
      library ? null, # null: auto-detect (no [project.scripts])
      docker ? null,
      test ? true, # pytest
      lint ? true, # ruff check
      typecheck ? false, # ty (pre-1.0, so opt-in)
      checkGroups ? null, # dependency groups in the test/typecheck venv; null: all
      extraChecks ? { },
      devPackages ? [ ],
      formatters ? [ ],
    }:
    let
      inherit (pkgs) lib;
      resolve = project.resolve pkgs;

      python' = if python != null then resolve python else pkgs.python3;
      src' = project.filterSource pkgs src;

      pyproject = builtins.fromTOML (builtins.readFile (src + "/pyproject.toml"));
      pname = pyproject.project.name;
      attrName = pyproject-nix.lib.pypa.normalizePackageName pname;
      scripts = pyproject.project.scripts or { };
      isLibrary = if library != null then library else scripts == { };
      # The script named like the project, else the first one (docker entrypoint, `nix run`).
      mainProgram =
        if scripts ? ${pname} then
          pname
        else if scripts != { } then
          builtins.head (builtins.attrNames scripts)
        else
          pname;

      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = src'; };
      pythonSet = (pkgs.callPackage pyproject-nix.build.packages { python = python'; }).overrideScope (
        lib.composeManyExtensions [
          pyproject-build-systems.overlays.${sourcePreference}
          (workspace.mkPyprojectOverlay { inherit sourcePreference; })
          (pythonOverrides pkgs)
        ]
      );

      # Runtime venv: the project without dependency groups. (uv2nix's
      # deps.default would add [tool.uv] default-groups, e.g. dev tools or a
      # multi-GB `gpu` group.)
      venv = pythonSet.mkVirtualEnv "${pname}-env" { ${attrName} = [ ]; };
      # Dependency groups for the checks (incl. `dev` with pytest): all, or only
      # `checkGroups` (e.g. to keep a multi-GB `gpu` group with torch out of Nix).
      testVenv = pythonSet.mkVirtualEnv "${pname}-test-env" (
        if checkGroups == null then workspace.deps.all else { ${attrName} = checkGroups; }
      );

      # Only the project's scripts, without the venv around them.
      app = (pkgs.callPackages pyproject-nix.build.util { }).mkApplication {
        inherit venv;
        package = pythonSet.${attrName};
      };
      bin = app // {
        meta = (app.meta or { }) // {
          inherit mainProgram;
        };
      };

      check = project.runInSource pkgs src';
    in
    project.mkOutputs {
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
      buildCheck = if isLibrary then venv else bin;
      formatters = [ pkgs.ruff ] ++ resolve formatters; # ruff format

      checks =
        lib.optionalAttrs test {
          test = check "${pname}-test" [ testVenv ] "pytest -p no:cacheprovider";
        }
        // lib.optionalAttrs lint {
          lint = check "${pname}-lint" [ pkgs.ruff ] "ruff check --no-cache";
        }
        // lib.optionalAttrs typecheck {
          typecheck = check "${pname}-typecheck" [ pkgs.ty ] "ty check --python ${testVenv}";
        };

      # Plain uv workflow: `uv sync` manages .venv with the Nix interpreter.
      devShell =
        formatter:
        pkgs.mkShell {
          packages = [
            python'
            pkgs.uv
            pkgs.ruff
            pkgs.ty
            formatter
          ]
          ++ resolve devPackages;
          env = {
            UV_PYTHON = python'.interpreter;
            UV_PYTHON_DOWNLOADS = "never";
          }
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            # manylinux wheels (numpy, …) expect these at runtime.
            LD_LIBRARY_PATH = lib.makeLibraryPath [
              pkgs.stdenv.cc.cc.lib
              pkgs.zlib
            ];
          };
          shellHook = ''
            unset PYTHONPATH
          '';
        };
    };
}
