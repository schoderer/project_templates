# Build definition of the __NAME__ service (the project contract, see services/README.md).
#
# Called by ../flake.nix (standalone) and by the root flake (monorepo) with
#   pkgs    nixpkgs for the target system
#   inputs  flake inputs (unused here)
{ pkgs, ... }:
let
  inherit (pkgs) lib;
  python = pkgs.python3;

  # Python dependencies come from nixpkgs. Keep `runtimeDeps` in sync with
  # `dependencies` in pyproject.toml.
  runtimeDeps = ps: [
    ps.fastapi
    ps.uvicorn
  ];
  devDeps = ps: [
    ps.pytest
    ps.httpx2 # used by fastapi.testclient
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
    nativeCheckInputs = [
      python.pkgs.pytestCheckHook
      python.pkgs.httpx2
    ];
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

  docker = pkgs.dockerTools.buildLayeredImage {
    name = "__NAME__";
    tag = bin.version;
    # CA certificates for outgoing TLS; the image otherwise only holds the binary's closure.
    contents = [ pkgs.cacert ];
    config = {
      Cmd = [ (lib.getExe bin) ];
      Env = [
        "PORT=8080"
        "PYTHONUNBUFFERED=1" # logs reach `docker logs` immediately
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
