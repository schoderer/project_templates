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
    project-templates.lib.rust.mkFlake {
      src = ./.;
      # Docker image as packages.dockerImage; set to false to drop it.
      # Options: name, tag, config (merged into the image config), copyToRoot, entrypoint.
      docker = { };
      # Extra `nix flake check` gates:
      # clippy = true;
      # fmt = true;
      # Native libraries beyond the defaults (pkg-config / openssl):
      # buildInputs = pkgs: [ pkgs.sqlite ];
    };
}
