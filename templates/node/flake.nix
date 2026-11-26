{
  description = "app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    project-templates = {
      url = "git+ssh://git@github.com/schoderer/project_templates";
      # Build with this project's nixpkgs (locked in its flake.lock), not the lib's pin.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { project-templates, ... }:
    project-templates.lib.node.mkFlake {
      src = ./.;
      # Builds from package-lock.json: after `npm install` there is nothing to update here.
      docker = { }; # packages.dockerImage; false to drop it, options in the lib's Readme
      # `nix flake check` runs `npm test` (vitest), `npm run typecheck` (tsc), biome lint and treefmt.
    };
}
