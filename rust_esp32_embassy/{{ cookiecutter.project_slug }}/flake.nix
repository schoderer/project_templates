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
            # For ESP32-C2 and ESP32-C3
            targets = [ "riscv32imc-unknown-none-elf" ];
            # For ESP32-C6 and ESP32-H2
            # targets = ["riscv32imac-unknown-none-elf"]
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
            nativeBuildInputs = with pkgs; [ rustToolchain pkg-config bacon espflash ];
            buildInputs = with pkgs; [];
          };
        }
      );
}
