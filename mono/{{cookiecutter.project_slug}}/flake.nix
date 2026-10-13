# Root flake: orchestrates every project in services/ and tools/.
#
#   nix build                    all binaries (services + tools)
#   nix build .#docker           all service docker images  -> result/<name>.tar.gz
#   nix build .#<name>           one project's binary
#   nix build .#<name>-docker    one service's docker image
#   nix flake check              every project's checks + formatting
#   nix develop                  one shell with the tooling of every project
#   nix fmt                      format the whole repo (treefmt)
#   nix run .#up                 run every service locally (docker compose)
#
# Projects are discovered automatically (nix/lib.nix), so this file does not
# change when you add a service or tool. To add one:
#   nix run .#new-service -- <lang> <name>   /   nix run .#new-tool -- <lang> <name>
# The justfile wraps all of these (`just` lists them).
{
  description = "{{ cookiecutter.project_description }}";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/{{ cookiecutter.nixpkgs_branch }}";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    # Rust builds. Projects get every root input via their `inputs` argument;
    # a project's own flake.nix may only declare inputs that also exist here.
    crane.url = "github:ipetkov/crane";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Docker images are Linux-only. Adding darwin systems works for binaries
      # but then the docker outputs need a Linux builder.
      systems = [
{%- for system in cookiecutter.systems.split(",") %}
        "{{ system }}"
{%- endfor %}
      ];

      imports = [
        inputs.treefmt-nix.flakeModule
        ./nix/projects.nix # packages, checks and dev shells of all projects
        ./nix/apps.nix # scaffolding, lock syncing, docker-load
        ./nix/compose.nix # `just up`: run every service locally
        ./nix/treefmt.nix # `nix fmt` + formatting check
      ];
    };
}
