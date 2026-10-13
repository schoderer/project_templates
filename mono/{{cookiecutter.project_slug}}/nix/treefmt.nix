#
#   nix fmt              format everything
#   nix flake check      includes checks.treefmt (fails on unformatted files)
#
# Language formatters are enabled only when a project in services/ or tools/
# uses that language (detected by its marker file). This keeps the root dev
# shell small: rustfmt alone pulls in the whole Rust toolchain (~1.6 GiB),
# gofmt the Go toolchain, so a repo without Rust or Go projects should not
# download them on `nix develop` / `direnv allow`. Linting stays in each
# project's own checks; this only formats. Add a line here when a template for
# a new language is added.
{ lib, ... }:
let
  projectDirs =
    lib.concatMap
      (
        kind:
        let
          dir = ../. + "/${kind}";
          entries = if builtins.pathExists dir then builtins.readDir dir else { };
        in
        lib.mapAttrsToList (name: _: dir + "/${name}") (
          lib.filterAttrs (_: type: type == "directory") entries
        )
      )
      [
        "services"
        "tools"
      ];

  # True when any project contains `marker` (only git-tracked files count).
  uses = marker: lib.any (dir: builtins.pathExists (dir + "/${marker}")) projectDirs;
in
{
  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";

      # Always on: nix files and shell scripts (.envrc) exist in every repo.
      programs.nixfmt.enable = true;
      programs.shellcheck.enable = true;

      programs.rustfmt.enable = uses "Cargo.toml";
      programs.rustfmt.edition = "2024";

      # ruff reads the nearest pyproject.toml, so each project keeps its own settings.
      programs.ruff-format.enable = uses "pyproject.toml";
      programs.ruff-check.enable = uses "pyproject.toml";

      programs.gofmt.enable = uses "go.mod";

      # TypeScript, JavaScript and JSON. treefmt passes this config to biome
      # (overriding project biome.json files), so keep it in line with
      # templates/*/typescript/biome.json.
      programs.biome = {
        enable = uses "package.json";
        formatCommand = "format";
        settings.formatter.indentStyle = "space";
        validate.enable = false; # would download the schema
      };

      settings.global.excludes = [
        "*.lock"
        "**/package-lock.json"
        "documents/**"
        # Skeletons are formatted already (and checked by the template's
        # self-test); formatting them here would need every language's formatter.
        "templates/**"
      ];
    };
  };
}
