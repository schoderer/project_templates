{
  description = "Flake for elixir_in_action";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let

        pkgs = import nixpkgs {
          inherit system;
        };

        devDeps = with pkgs; [
          bun
          typescript-language-server

        ];
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = devDeps;
        };
      }
    );
}
