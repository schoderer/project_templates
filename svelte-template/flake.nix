{
  description = "Svelte + Storybook component workshop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            # Storybook 10 is ESM-only: needs Node 20.16+, 22.19+, or 24+.
            nodejs_24
            pnpm

            # Editor tooling — drop these if your LSP setup lives elsewhere.
            svelte-language-server
            typescript-language-server
          ];

          # Uncomment if you enable Storybook's Vitest browser-mode testing.
          # Playwright's npm package downloads dynamically-linked browser
          # binaries that will not run on NixOS; point it at the nixpkgs build.
          #
          # PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
          # PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";

          shellHook = ''
            # Keep pnpm's store inside the project so the shell stays disposable.
            export PNPM_HOME="$PWD/.pnpm"
            export PATH="$PNPM_HOME:$PATH"

            echo "node $(node --version)  pnpm $(pnpm --version)"
            echo "  sv create .        scaffold a SvelteKit project"
            echo "  pnpm storybook     start Storybook on :6006"
          '';
        };
      }
    );
}
