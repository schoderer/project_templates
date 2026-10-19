# flake-parts module: repo-wide formatting via treefmt.
#
#   nix fmt              format everything
#   nix flake check      includes checks.treefmt (fails on unformatted files)
#
# One formatter per language that has a template in templates/. Linting stays
# in each project's own checks; this only formats. Add a formatter here when a
# template for a new language is added.
_: {
  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";

      programs.nixfmt.enable = true;

      programs.rustfmt.enable = true;
      programs.rustfmt.edition = "2024";

      # ruff reads the nearest pyproject.toml, so each project keeps its own settings.
      programs.ruff-format.enable = true;
      programs.ruff-check.enable = true;

      programs.gofmt.enable = true;

      programs.google-java-format.enable = true;

      # TypeScript, JavaScript and JSON. treefmt passes this config to biome
      # (overriding project biome.json files), so keep it in line with
      # templates/*/typescript/biome.json.
      programs.biome = {
        enable = true;
        formatCommand = "format";
        settings.formatter.indentStyle = "space";
        validate.enable = false; # would download the schema
      };

      programs.shellcheck.enable = true;

      settings.global.excludes = [
        "*.lock"
        "**/package-lock.json"
        "documents/**"
      ];
    };
  };
}
