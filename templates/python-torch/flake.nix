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
      systems = [ "x86_64-linux" ]; # ROCm wheels are x86_64 Linux only
      # Pinned minor, matching requires-python in pyproject.toml.
      python = pkgs: pkgs.python314;
      # torch (the `gpu` group) is installed by uv only; Nix checks run without it.
      checkGroups = [ "dev" ];
      # `nix flake check` runs pytest (torch tests skipped), ruff check and treefmt;
      # `just typecheck` runs ty locally, where torch is installed.
    };
}
