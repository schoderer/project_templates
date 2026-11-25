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
      docker = { }; # packages.dockerImage; false to drop it, options in the lib's Readme
      # `nix flake check` runs cargo test, clippy (--deny warnings) and treefmt;
      # turn the first two off with `test = false;` / `lint = false;`.
      # Native libraries beyond the defaults (pkg-config / openssl):
      # buildInputs = pkgs: [ pkgs.sqlite ];
    };
}
