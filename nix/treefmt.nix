# treefmt for a project, shared by nix/rust.nix and nix/go.nix.
#
# The project owns its treefmt.toml (shipped by the templates); the lib only
# supplies the formatter programs it references. Returns:
#   formatter  `nix fmt` / devShell wrapper: treefmt with `formatters` on PATH
#   checks     { treefmt = …; } when src has a treefmt.toml (fails on unformatted files), else { }
{
  pkgs,
  src,
  formatters,
}:
let
  formatter = pkgs.writeShellApplication {
    name = "treefmt";
    runtimeInputs = [ pkgs.treefmt ] ++ formatters;
    text = ''exec treefmt "$@"'';
  };
in
{
  inherit formatter;

  checks = pkgs.lib.optionalAttrs (builtins.pathExists (src + "/treefmt.toml")) {
    treefmt = pkgs.runCommand "treefmt-check" { nativeBuildInputs = [ formatter ]; } ''
      cp -r ${src} project
      chmod -R u+w project
      cd project
      export HOME=$TMPDIR
      treefmt --ci
      touch $out
    '';
  };
}
