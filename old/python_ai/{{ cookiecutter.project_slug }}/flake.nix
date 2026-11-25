{
  description = "Flake for {{ cookiecutter.project_slug }}";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        # Must match the py3.X of the rocm/pytorch image in the Containerfile:
        # the container reuses the image's compiled torch.
        python = pkgs.python314;
        devDeps = with pkgs; [
          python
          uv
          ty
          ruff
          just
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = devDeps;
          env = {
            # uv must use the Nix python, never download its own
            UV_PYTHON = "${python}/bin/python";
            UV_PYTHON_DOWNLOADS = "never";
            # manylinux wheels (torch, numpy, ...) need libstdc++/zlib at runtime
            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib pkgs.zlib ];
          };
        };
      }
    );
}
