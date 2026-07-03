# Add those packages to every devshell
{ ... }:
{
  perSystem =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      devShells.default = pkgs.mkShell {
        inputsFrom = lib.attrValues (lib.removeAttrs config.devShells [ "default" ]);
        packages = [
          pkgs.just
          config.treefmt.build.wrapper # `treefmt` on PATH, configured repo-wide
        ];
      };
    };
}
