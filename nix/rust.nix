# Rust project library: crane build + tests + optional docker image.
#
#   lib.rust.mkProject { pkgs, src, ... } => { packages, checks, devShell }
#
# Same contract as the (legacy) mono template's nix/default.nix, so a monorepo
# can call mkProject per service. `mkFlake` (in ../flake.nix) wraps it for
# every system and turns it into flake outputs.
{ crane, rust-overlay }:
{
  mkProject =
    {
      pkgs,
      src,
      # null: rust-toolchain.toml in `src` if present, else stable latest.
      # Otherwise a function `pkgs -> toolchain derivation`.
      toolchain ? null,
      # nativeBuildInputs, buildInputs, craneArgs, docker and extraChecks may
      # also be functions `pkgs -> value`, which is how mkFlake users (who have
      # no per-system pkgs) reference packages: buildInputs = p: [ p.sqlite ];
      #
      # Added to the defaults (pkg-config / openssl).
      nativeBuildInputs ? [ ],
      buildInputs ? [ ],
      # Merged last into crane's common args (escape hatch: pname, env vars,
      # cargoExtraArgs, ...).
      craneArgs ? { },
      # false, true (defaults) or { name, tag, config, copyToRoot, entrypoint }.
      docker ? true,
      # Extra `nix flake check` gates.
      clippy ? false,
      fmt ? false,
      extraChecks ? { },
    }:
    let
      inherit (pkgs) lib;

      # Accept plain nixpkgs as well as nixpkgs with rust-overlay applied.
      pkgs' = if pkgs ? rust-bin then pkgs else pkgs.extend rust-overlay.overlays.default;
      resolve = v: if builtins.isFunction v then v pkgs' else v;
      docker' = resolve docker;

      toolchainFile = src + "/rust-toolchain.toml";
      rustToolchain =
        if toolchain != null then
          toolchain pkgs'
        else if builtins.pathExists toolchainFile then
          pkgs'.rust-bin.fromRustupToolchainFile toolchainFile
        else
          pkgs'.rust-bin.stable.latest.default.override {
            extensions = [
              "rust-analyzer"
              "rust-src"
              "clippy"
              "rustfmt"
            ];
          };

      craneLib = (crane.mkLib pkgs').overrideToolchain (_: rustToolchain);
      cleanSrc = craneLib.cleanCargoSource src;

      args = {
        src = cleanSrc;
        strictDeps = true;
        nativeBuildInputs = [
          pkgs'.pkg-config
        ]
        ++ resolve nativeBuildInputs;
        buildInputs = [ pkgs'.openssl ] ++ resolve buildInputs;
      }
      // resolve craneArgs;

      pname = args.pname or (craneLib.crateNameFromCargoToml { inherit src; }).pname;

      cargoArtifacts = craneLib.buildDepsOnly args;
      bin = craneLib.buildPackage (args // { inherit cargoArtifacts; });

      dockerOpts = {
        name = "ghcr.io/schoderer/${pname}";
        tag = "latest";
        config = { };
        copyToRoot = [ ];
        entrypoint = [ "${bin}/bin/${pname}" ];
      }
      // (if builtins.isAttrs docker' then docker' else { });

      dockerImage = pkgs'.dockerTools.buildImage {
        inherit (dockerOpts) name tag;
        created = "now"; # breaks bit-for-bit reproducibility, but avoids epoch timestamps
        copyToRoot = [ bin ] ++ dockerOpts.copyToRoot;
        config = {
          Entrypoint = dockerOpts.entrypoint;
          User = "7337:7337"; # do not run as root
          Env = [ ];
        }
        // dockerOpts.config;
      };
      withDocker = docker' != false;
    in
    {
      packages = {
        inherit bin;
        default = bin;
      }
      // lib.optionalAttrs withDocker { inherit dockerImage; };

      checks = {
        inherit bin;
        test = craneLib.cargoTest (args // { inherit cargoArtifacts; });
      }
      // lib.optionalAttrs clippy {
        clippy = craneLib.cargoClippy (
          args
          // {
            inherit cargoArtifacts;
            cargoClippyExtraArgs = "--all-targets -- --deny warnings";
          }
        );
      }
      // lib.optionalAttrs fmt { fmt = craneLib.cargoFmt { src = cleanSrc; }; }
      // resolve extraChecks;

      devShell = craneLib.devShell {
        inputsFrom = [ bin ];
        packages = [ pkgs'.bacon ];
      };
    };
}
