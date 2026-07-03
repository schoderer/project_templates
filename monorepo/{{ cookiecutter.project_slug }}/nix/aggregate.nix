# Cross-cutting outputs derived from whatever the service modules contribute.
# This file never needs to know which services exist.
{ ... }:
{
  perSystem =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      # All service packages, excluding the aggregates themselves.
      servicePkgs = lib.removeAttrs config.packages [
        "all"
        "default"
      ];

      dockerImages = lib.removeAttrs config.dockerImages [
        "all"
        "default"
      ];
    in
    {
      # `nix build .#all` — builds every service into one symlink forest.
      packages.all = pkgs.symlinkJoin {
        name = "all-services";
        paths = lib.attrValues servicePkgs;
      };

      packages.docker = pkgs.symlinkJoin {
        name = "all-docker-services";
        paths = lib.attrValues dockerImages;
      };

      packages.default = config.packages.all;

      # Every service package is also a check, so `nix flake check`
      # is the single CI entry point (plus treefmt's formatting check).
      checks = lib.mapAttrs' (name: drv: lib.nameValuePair "pkg-${name}" drv) servicePkgs;
    };
}
