{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };
    crane.url = "github:ipetkov/crane";
  };
  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Import packages with overlay
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

        # Configure the rust toolchain
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-analyzer" "rust-src" "clippy" "rustfmt" ];
        };
        
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
        src = craneLib.cleanCargoSource ./.;

        ##########
        # Required Packages
        ##########
        args = {
          nativeBuildInputs = with pkgs; [
            rustToolchain
            pkg-config
            bacon
          ];
          buildInputs = with pkgs; [
            openssl
          ];
          inherit src;
        };

        cargoArtifacts = craneLib.buildDepsOnly args;
        bin = craneLib.buildPackage (args // { inherit cargoArtifacts; });

        ##########
        # Tests — reuses the dependency artifacts, so only the crate is rebuilt
        ##########
        cargoTest = craneLib.cargoTest (args // { inherit cargoArtifacts; });
{%- if cookiecutter.docker_image == "yes" %}

        ##########
        # Dockerimage
        ##########
        # Example for adding a file to the image. Add this to the copyToRoot
        # baseConfigFile = pkgs.writeTextDir "/config_base.toml" (builtins.readFile ./config_base.toml);

        dockerImage = pkgs.dockerTools.buildImage {
          name = "ghcr.io/schoderer/{{ cookiecutter.project_slug }}";
          tag = "latest";
          created = "now"; # Breaks binary reproducable, but creation is not epoch

          copyToRoot = [ bin ];
          config = {
            Entrypoint = [ "${bin}/bin/{{ cookiecutter.project_slug }}" ];
            User = "7337:7337"; # Run this not as root
            Env = [];
          };
        };
{%- endif %}
      in with pkgs; {
        packages = {
          inherit bin{% if cookiecutter.docker_image == "yes" %} dockerImage{% endif %};
          default = bin;
        };
        # `nix flake check` (and the nix-check CI workflow) builds the binary
        # and runs `cargo test`. Add clippy/fmt gates here the same way:
        #   clippy = craneLib.cargoClippy (args // { inherit cargoArtifacts;
        #     cargoClippyExtraArgs = "--all-targets -- --deny warnings"; });
        #   fmt = craneLib.cargoFmt { inherit src; };
        checks = {
          inherit bin;
          test = cargoTest;
        };
        devShells.default = mkShell {
          nativeBuildInputs = args.nativeBuildInputs;
          buildInputs = args.buildInputs;
        };
      }
    );
}

