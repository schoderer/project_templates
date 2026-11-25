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
    project-templates.lib.python.mkFlake {
      src = ./.;
      # Builds from uv.lock: after `uv add`/`uv lock` there is nothing to update here.
      docker = { }; # packages.dockerImage; false to drop it, options in the lib's Readme
      # `nix flake check` runs pytest and ruff check; this adds ty:
      typecheck = true;
      # Interpreter (must satisfy requires-python), default nixpkgs python3:
      # python = pkgs: pkgs.python313;
      # Build fixes for dependencies that need them (pkgs first, then a normal overlay):
      # pythonOverrides = pkgs: final: prev: {
      #   somepkg = prev.somepkg.overrideAttrs (old: {
      #     nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkg-config ];
      #   });
      # };
    };
}
