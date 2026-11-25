# Python project library: uv2nix build from uv.lock + pytest/ruff/ty checks +
# optional docker image.
#
#   lib.python.mkProject { pkgs, src, ... } => { packages, checks, devShell, formatter }
#
# Same contract as nix/rust.nix and nix/go.nix. `mkFlake` (in ../flake.nix)
# wraps it for every system and turns it into flake outputs.
{
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
}:
{
  mkProject =
    {
      pkgs,
      # Project root with pyproject.toml and uv.lock.
      src,
      # Everything below that references packages may also be a function
      # `pkgs -> value`, which is how mkFlake users (who have no per-system pkgs)
      # reference them: python = pkgs: pkgs.python313;
      #
      # Interpreter; must satisfy `requires-python`. Default: nixpkgs python3.
      python ? null,
      # "wheel" (prefer prebuilt wheels) or "sdist" (build from source).
      sourcePreference ? "wheel",
      # `pkgs: final: prev: { … }`: an overlay on the uv2nix package set for
      # dependencies that need build fixes (extra nativeBuildInputs, patches, …).
      # Always takes pkgs first (an overlay is a function itself, so the
      # `pkgs -> value` convention would be ambiguous here).
      pythonOverrides ? (
        _pkgs: _final: _prev:
        { }
      ),
      # null: auto-detect. A project without [project.scripts] is a library (no
      # packages, no docker).
      library ? null,
      # null/true (defaults), false, or { name, tag, config, copyToRoot, entrypoint }.
      # Binaries only; see ./docker.nix.
      docker ? null,
      # `nix flake check` gates.
      test ? true, # pytest (from the `dev` dependency group)
      lint ? true, # ruff check
      typecheck ? false, # ty check (pre-1.0, so opt-in)
      extraChecks ? { },
      # devShell-only tools added to python, uv, ruff, ty.
      devPackages ? [ ],
      # Extra programs for formatters you add to treefmt.toml (ruff, nixfmt and
      # taplo are always there).
      formatters ? [ ],
    }:
    let
      inherit (pkgs) lib;
      resolve = v: if builtins.isFunction v then v pkgs else v;

      python' = if python != null then resolve python else pkgs.python3;

      pyproject = builtins.fromTOML (builtins.readFile (src + "/pyproject.toml"));
      pname = pyproject.project.name;
      attrName = pyproject-nix.lib.pypa.normalizePackageName pname;
      scripts = pyproject.project.scripts or { };
      isLibrary = if library != null then library else scripts == { };
      # Entrypoint for docker: the script named like the project, else the first one.
      mainProgram =
        if scripts ? ${pname} then
          pname
        else if scripts != { } then
          builtins.head (builtins.attrNames scripts)
        else
          pname;

      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = src; };
      pythonSet = (pkgs.callPackage pyproject-nix.build.packages { python = python'; }).overrideScope (
        lib.composeManyExtensions [
          pyproject-build-systems.overlays.${sourcePreference}
          (workspace.mkPyprojectOverlay { inherit sourcePreference; })
          (pythonOverrides pkgs)
        ]
      );

      venv = pythonSet.mkVirtualEnv "${pname}-env" workspace.deps.default;
      # All dependency groups (incl. `dev` with pytest) for the checks.
      testVenv = pythonSet.mkVirtualEnv "${pname}-test-env" workspace.deps.all;

      # Only the project's scripts, without the venv around them.
      bin = (pkgs.callPackages pyproject-nix.build.util { }).mkApplication {
        inherit venv;
        package = pythonSet.${attrName};
      };

      # Run `cmd` in a writable copy of the project as a check.
      pyCheck =
        name: inputs: cmd:
        pkgs.runCommand "${pname}-${name}" { nativeBuildInputs = inputs; } ''
          cp -r ${src} project
          chmod -R u+w project
          cd project
          export HOME=$TMPDIR
          ${cmd}
          touch $out
        '';

      treefmt = import ./treefmt.nix {
        inherit pkgs src;
        formatters = [
          pkgs.ruff # ruff format
          pkgs.nixfmt
          pkgs.taplo
        ]
        ++ resolve formatters;
      };

      docker' = import ./docker.nix {
        inherit
          pkgs
          bin
          pname
          mainProgram
          ;
        docker = resolve docker;
        library = isLibrary;
      };
    in
    {
      # A library has no scripts to ship, so it gets no packages (`nix build`
      # errors clearly instead of producing a bare venv).
      packages =
        lib.optionalAttrs (!isLibrary) {
          inherit bin;
          default = bin;
        }
        // docker';

      checks = {
        ${if isLibrary then "build" else "bin"} = if isLibrary then venv else bin;
      }
      // lib.optionalAttrs test {
        test = pyCheck "test" [ testVenv ] "pytest -p no:cacheprovider";
      }
      // lib.optionalAttrs lint {
        lint = pyCheck "lint" [ pkgs.ruff ] "ruff check --no-cache";
      }
      // lib.optionalAttrs typecheck {
        typecheck = pyCheck "typecheck" [ pkgs.ty ] "ty check --python ${testVenv}";
      }
      // treefmt.checks
      // resolve extraChecks;

      inherit (treefmt) formatter;

      # Plain uv workflow: `uv sync` manages .venv with the Nix interpreter.
      devShell = pkgs.mkShell {
        packages = [
          python'
          pkgs.uv
          pkgs.ruff
          pkgs.ty
          treefmt.formatter
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
