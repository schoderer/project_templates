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
  python = pkgs.python3;

  # Python dependencies come from nixpkgs. Keep `runtimeDeps` in sync with
  # `dependencies` in pyproject.toml.
  runtimeDeps = ps: [ ps.click ];
  devDeps = ps: [
    ps.pytest
    ps.mypy
  ];
  pyproject = lib.importTOML ../pyproject.toml;

  # Only the files the build needs: editing docs or nix files does not cause a rebuild.
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../pyproject.toml
      ../src
      ../tests
    ];
  };

  bin = python.pkgs.buildPythonApplication {
    pname = pyproject.project.name;
    inherit (pyproject.project) version;
    pyproject = true;
    inherit src;

    build-system = [ python.pkgs.hatchling ];
    dependencies = runtimeDeps python.pkgs;

    # pytest runs as part of the build, so a broken test fails `nix build`.
    nativeCheckInputs = [ python.pkgs.pytestCheckHook ];
    pythonImportsCheck = [ "__NAME_SNAKE__" ];

    meta.mainProgram = "__NAME__";
  };

  # Python with runtime and development dependencies, for linting and the dev shell.
  devPython = python.withPackages (ps: runtimeDeps ps ++ devDeps ps);

  # Runs `script` against a writable copy of the sources.
  lint =
    name: script:
    pkgs.runCommand "__NAME__-${name}"
      {
        nativeBuildInputs = [
          devPython
          pkgs.ruff
        ];
      }
      ''
        cp -r --no-preserve=mode ${src}/. .
        ${script}
        touch $out
      '';
in
{
  packages.default = bin;

  # The root flake adds the binary build (which runs pytest) as <name>-build.
  checks = {
    ruff = lint "ruff" "ruff check . && ruff format --check .";
    mypy = lint "mypy" "mypy";
  };

  devShell = pkgs.mkShell {
    packages = [
      devPython
      pkgs.ruff
    ];
    # Make the sources importable (`python -m __NAME_SNAKE__`) without installing,
    # both in this folder's shell and in the root's combined shell.
    shellHook = ''
      for dir in "$PWD/src" "$(git rev-parse --show-toplevel 2>/dev/null)/__DIR__/src"; do
        if [ -d "$dir/__NAME_SNAKE__" ]; then
          export PYTHONPATH="$dir''${PYTHONPATH:+:$PYTHONPATH}"
          break
        fi
      done
    '';
  };
}
