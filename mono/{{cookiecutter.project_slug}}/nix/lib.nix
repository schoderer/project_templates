# Project discovery and validation.
#
# A *project* is a directory `<dir>/<name>/` containing `nix/default.nix`.
# That file is a function implementing the project contract:
#
#   { pkgs, inputs }:
#   {
#     packages = {
#       default = <binary derivation>;   # required
#       docker  = <docker image>;        # required for services, forbidden for tools
#       ...                              # optional extras, exposed as <name>-<pkg>
#     };
#     checks   = { <check> = <derivation>; ... };   # run by `nix flake check`
#     devShell = <mkShell derivation>;              # project tooling
#     compose  = { ports = [ "8081:8080" ]; ... };  # services only, optional:
#                                                   # merged into the service's
#                                                   # entry of `packages.compose`
#   }
#
# `pkgs` is nixpkgs for the current system, `inputs` are the root flake inputs.
# The project's own flake.nix calls the same function, so standalone and
# monorepo builds share one definition.
#
# Directories whose name starts with "." or "_" are skipped, which lets you
# park unfinished work as e.g. services/_wip-api.
{ lib }:
let
  isProject =
    dir: name: type:
    type == "directory"
    && !(lib.hasPrefix "." name)
    && !(lib.hasPrefix "_" name)
    && builtins.pathExists (dir + "/${name}/nix/default.nix");

  # Names of the project directories in `dir` (none if `dir` does not exist).
  projectNames =
    dir:
    let
      entries = if builtins.pathExists dir then builtins.readDir dir else { };
    in
    builtins.attrNames (lib.filterAttrs (isProject dir) entries);

  # Fail evaluation early with a message that points at the offending file.
  validate =
    {
      kind,
      requireDocker,
    }:
    name: project:
    let
      where = "${kind}/${name}/nix/default.nix";
      packages = project.packages or { };
    in
    assert lib.assertMsg (
      project ? packages && project ? checks && project ? devShell
    ) "${where}: must return { packages, checks, devShell }";
    assert lib.assertMsg (packages ? default) "${where}: packages.default (the binary) is missing";
    assert lib.assertMsg (
      requireDocker -> packages ? docker
    ) "${where}: services must provide packages.docker";
    assert lib.assertMsg (
      !requireDocker -> !(packages ? docker)
    ) "${where}: tools must not provide packages.docker (move the project to services/)";
    assert lib.assertMsg (
      !requireDocker -> !(project ? compose)
    ) "${where}: tools must not provide compose (only services run in `just up`)";
    assert lib.assertMsg (builtins.isAttrs (
      project.compose or { }
    )) "${where}: compose must be an attribute set of docker compose service keys";
    project;
in
{
  # Import and validate every project in `dir`.
  #
  #   discover { dir = ../services; kind = "services"; requireDocker = true; args = { inherit pkgs inputs; }; }
  #   => { hello-service = { packages = …; checks = …; devShell = …; }; … }
  discover =
    {
      dir,
      kind,
      requireDocker,
      args,
    }:
    lib.genAttrs (projectNames dir) (
      name: validate { inherit kind requireDocker; } name (import (dir + "/${name}/nix") args)
    );

  # Which languages the projects in `dirs` use, detected by a marker file in
  # each project root. Only reads directories (no project is imported), so
  # nix/treefmt.nix can use it to enable just the formatters that are needed.
  #
  #   languages { dirs = [ ../services ../tools ]; }
  #   => { rust = true; go = false; java = false; python = true; typescript = false; }
  languages =
    { dirs }:
    let
      markers = {
        rust = "Cargo.toml";
        go = "go.mod";
        java = "pom.xml";
        python = "pyproject.toml";
        typescript = "package.json";
      };
      projectDirs = lib.concatMap (dir: map (name: dir + "/${name}") (projectNames dir)) dirs;
    in
    lib.mapAttrs (
      _: marker: lib.any (project: builtins.pathExists (project + "/${marker}")) projectDirs
    ) markers;
}
