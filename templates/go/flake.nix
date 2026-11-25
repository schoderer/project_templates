{
  description = "app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    project-templates.url = "git+ssh://git@github.com/schoderer/project_templates";
    # Build with this project's nixpkgs (locked in its flake.lock), not the lib's pin.
    project-templates.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { project-templates, ... }:
    project-templates.lib.go.mkFlake {
      src = ./.;
      # Hash of the go.mod dependencies. null while there are none; after
      # `go get`, set it to "" and copy the real hash from the `nix build` error.
      vendorHash = null;
      # Docker image as packages.dockerImage; set to false to drop it.
      # Options: name, tag, config (merged into the image config), copyToRoot, entrypoint.
      docker = { };
      # Extra `nix flake check` gates (go vet is on by default):
      # lint = true; # golangci-lint
      # Only build some main packages:
      # subPackages = [ "cmd/server" ];
      # cgo = true;  # default false: static binary
    };
}
