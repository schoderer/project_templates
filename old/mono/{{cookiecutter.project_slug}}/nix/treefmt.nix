# flake-parts module: repo-wide formatting via treefmt.
#
#   nix fmt              format everything
#   nix flake check      includes checks.treefmt (fails on unformatted files)
#
# nixfmt and shellcheck always run. Language formatters are only enabled when
# a project in services/ or tools/ uses that language (detected by marker
# files, see `languages` in nix/lib.nix), so the root dev shell and CI do not
# download toolchains nobody uses. Linting stays in each project's own checks;
# this only formats. When adding a language template, add its marker there
# and its formatter here.
{ lib, ... }:
let
  used = (import ./lib.nix { inherit lib; }).languages {
    dirs = [
      ../services
      ../tools
    ];
  };
in
{
  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";

      programs.nixfmt.enable = true;

      programs.rustfmt.enable = used.rust;
      programs.rustfmt.edition = "2024";

      # ruff reads the nearest pyproject.toml, so each project keeps its own settings.
      programs.ruff-format.enable = used.python;
      programs.ruff-check.enable = used.python;

      programs.gofmt.enable = used.go;

      programs.google-java-format.enable = used.java;

      # TypeScript, JavaScript and JSON. treefmt passes this config to biome
      # (overriding project biome.json files), so keep it in line with
      # templates/*/typescript/biome.json.
      programs.biome = {
        enable = used.typescript;
        formatCommand = "format";
        settings.formatter.indentStyle = "space";
        validate.enable = false; # would download the schema
      };

      programs.shellcheck.enable = true;

      settings.global.excludes = [
        "*.lock"
        "**/package-lock.json"
        "documents/**"
        # Skeletons for every language: formatting them would need every
        # toolchain. They are formatted once scaffolded into services/ or tools/.
        "templates/**"
      ];
    };
  };
}
