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
    project-templates.lib.go.mkFlake {
      src = ./.;
      # Hash of the go.mod dependencies. null while there are none; after
      # `go get`, set it to "" and copy the real hash from the `nix build` error.
      vendorHash = null;
      docker = { }; # packages.dockerImage; false to drop it, options in the lib's Readme
      # `nix flake check` runs go test, go vet (`lint`) and treefmt; this adds golangci-lint:
      # golangciLint = true;
      # Only build some main packages:
      # subPackages = [ "cmd/server" ];
      # cgo = true;  # default false: static binary
    };
}
