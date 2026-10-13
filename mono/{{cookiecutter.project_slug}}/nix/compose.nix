# flake-parts module: run every service locally with docker compose.
#
#   nix run .#up [-- <docker compose up args>]   load all images and start them (`just up`)
#   nix run .#down                               stop and remove the containers (`just down`)
#   nix build .#compose                          the generated compose file
#
# Every project in services/ becomes a compose service running its nix-built
# image, extended with the project's `compose` attribute (ports, environment,
# depends_on, ...). Infrastructure that is not built here (databases, queues)
# goes into `infrastructure` below.
{ lib, ... }:
let
  # Extra compose services, e.g. for a database every service talks to.
  # Reference them from a service with `compose.depends_on = [ "postgres" ];`.
  infrastructure = {
    # postgres = {
    #   image = "postgres:17";
    #   environment.POSTGRES_PASSWORD = "postgres";
    #   ports = [ "5432:5432" ];
    # };
  };
in
{
  perSystem =
    {
      config,
      pkgs,
      monorepo,
      ...
    }:
    let
      composeFile = (pkgs.formats.json { }).generate "compose.json" {
        name = "{{ cookiecutter.project_slug }}";
        services =
          lib.mapAttrs (
            _: p:
            {
              image = "${p.packages.docker.imageName}:${p.packages.docker.imageTag}";
              restart = "unless-stopped";
            }
            // p.compose or { }
          ) monorepo.services
          // infrastructure;
      };

      compose =
        name: text:
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = [ pkgs.docker-compose ];
          inherit text;
        };
    in
    {
      packages.compose = composeFile;

      apps.up = {
        type = "app";
        meta.description = "Load every service image and start them with docker compose";
        program = lib.getExe (
          compose "up" ''
            ${config.apps.docker-load.program}
            docker-compose --file ${composeFile} up "$@"
          ''
        );
      };

      apps.down = {
        type = "app";
        meta.description = "Stop and remove the containers started by `up`";
        program = lib.getExe (
          compose "down" ''
            docker-compose --file ${composeFile} down "$@"
          ''
        );
      };
    };
}
