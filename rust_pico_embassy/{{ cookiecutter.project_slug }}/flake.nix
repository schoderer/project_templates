# in flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };
  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          overlays = [ (import rust-overlay) ];
          pkgs = import nixpkgs {
            inherit system overlays;
          };
          rustToolchain = pkgs.rust-bin.stable.latest.default.override {
            extensions = [ "rust-src" "rust-analyzer" ];
            targets = [ "thumbv6m-none-eabi" ];

          };
        in
        with pkgs;
        {
          checks = {
            inherit bin cargo-clippy;
          };
          packages =
            {
              inherit bin ;
              default = bin;
            };
          devShells.default = mkShell {
            nativeBuildInputs = with pkgs; [ rustToolchain pkg-config probe-rs-tools elf2uf2-rs flip-link];
            buildInputs = with pkgs; [];
          };
        }
      );
}
