# Wrapper to build all docker-images
{ flake-parts-lib, ... }:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, lib, ... }:
    {
      options.dockerImages = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.package;
        default = { };
        description = "Container images contributed by services.";
      };

      # Every image is also reachable as packages.<name>-image,
      # so `nix build .#api-image` works without extra ceremony.
      config.packages = lib.mapAttrs' (
        name: image: lib.nameValuePair "${name}-dockerimage" image
      ) config.dockerImages;
    }
  );
}
