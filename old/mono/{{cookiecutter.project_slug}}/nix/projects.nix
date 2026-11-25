# flake-parts module: turns the discovered projects into root flake outputs.
#
#   packages.<name>           a project's binary
#   packages.<name>-<pkg>     a project's other packages (e.g. <name>-docker)
#   packages.default          every binary (services + tools)
#   packages.services         every service binary
#   packages.tools            every tool binary
#   packages.docker           every service image, as result/<name>.tar.gz
#   checks.<name>-<check>     every project check, plus <name>-build
#   devShells.<name>          a project's dev shell
#   devShells.default         all project tooling combined
#
# The discovered projects are also passed to other perSystem modules as the
# `monorepo` argument ({ services, tools, projects }), see nix/compose.nix.
{ inputs, lib, ... }:
let
  monorepo = import ./lib.nix { inherit lib; };

  # Aggregate packages and apps live next to project outputs (and `nix run .#x`
  # prefers apps over packages), so projects cannot use these names.
  reserved = [
    "default"
    "services"
    "tools"
    "docker"
    "compose"
    "up"
    "down"
    "new-service"
    "new-tool"
    "sync-locks"
    "docker-load"
  ];
in
{
  perSystem =
    { config, pkgs, ... }:
    let
      args = { inherit pkgs inputs; };

      services = monorepo.discover {
        dir = ../services;
        kind = "services";
        requireDocker = true;
        inherit args;
      };
      tools = monorepo.discover {
        dir = ../tools;
        kind = "tools";
        requireDocker = false;
        inherit args;
      };

      clashes = lib.intersectLists (builtins.attrNames services) (builtins.attrNames tools);
      badNames = lib.intersectLists reserved (builtins.attrNames projects);
      projects =
        assert lib.assertMsg (
          clashes == [ ]
        ) "project names must be unique across services/ and tools/: ${toString clashes}";
        services // tools;

      binaries = set: lib.mapAttrsToList (_: p: p.packages.default) set;
      joinBinaries =
        name: set:
        pkgs.symlinkJoin {
          inherit name;
          paths = binaries set;
        };

      # { default = a; docker = b; } of project "x"  ->  { x = a; x-docker = b; }
      projectPackages =
        name: p:
        lib.mapAttrs' (
          pkg: drv: lib.nameValuePair (if pkg == "default" then name else "${name}-${pkg}") drv
        ) p.packages;

      projectChecks =
        name: p:
        lib.mapAttrs' (check: drv: lib.nameValuePair "${name}-${check}" drv) (
          p.checks // { build = p.packages.default; }
        );
    in
    assert lib.assertMsg (
      badNames == [ ]
    ) "these project names are reserved for root outputs: ${toString badNames}";
    {
      _module.args.monorepo = { inherit services tools projects; };

      packages = lib.concatMapAttrs projectPackages projects // {
        default = joinBinaries "all-binaries" projects;
        services = joinBinaries "services" services;
        tools = joinBinaries "tools" tools;
        docker = pkgs.linkFarm "docker-images" (
          lib.mapAttrsToList (name: p: {
            name = "${name}.tar.gz";
            path = p.packages.docker;
          }) services
        );
      };

      checks = lib.concatMapAttrs projectChecks projects;

      devShells = lib.mapAttrs (_: p: p.devShell) projects // {
        default = pkgs.mkShell {
          name = "monorepo";
          # Pulls in the packages and shell hooks of every project shell.
          inputsFrom = lib.mapAttrsToList (_: p: p.devShell) projects;
          packages = [
            config.treefmt.build.wrapper
            pkgs.just # runs the root justfile
          ];
        };
      };
    };
}
