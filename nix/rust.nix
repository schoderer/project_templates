# Rust project library: crane build + tests + optional docker image.
#
#   lib.rust.mkProject { pkgs, src, ... } => { packages, checks, devShell, formatter }
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
      # null: auto-detect. A crate without src/main.rs, src/bin/ or [[bin]] is a
      # library (no packages, no docker). Workspaces count as binaries.
      library ? null,
      # null/true (defaults), false, or { name, tag, config, copyToRoot, entrypoint }.
      # Binaries only; see ./docker.nix.
      docker ? null,
      # Extra `nix flake check` gates.
      clippy ? false,
      fmt ? false,
      extraChecks ? { },
      # Extra programs for formatters you add to treefmt.toml (nixfmt, taplo and
      # the toolchain's rustfmt are always there).
      formatters ? [ ],
    }:
    let
      inherit (pkgs) lib;

      # Accept plain nixpkgs as well as nixpkgs with rust-overlay applied.
      pkgs' = if pkgs ? rust-bin then pkgs else pkgs.extend rust-overlay.overlays.default;
      resolve = v: if builtins.isFunction v then v pkgs' else v;

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

      cargoToml = builtins.readFile (src + "/Cargo.toml");
      hasBin =
        builtins.pathExists (src + "/src/main.rs")
        || builtins.pathExists (src + "/src/bin")
        || lib.hasInfix "[[bin]]" cargoToml
        || lib.hasInfix "[workspace]" cargoToml;
      isLibrary = if library != null then library else !hasBin;

      cargoArtifacts = craneLib.buildDepsOnly args;
      bin = craneLib.buildPackage (args // { inherit cargoArtifacts; });

      treefmt = import ./treefmt.nix {
        pkgs = pkgs';
        inherit src;
        formatters = [
          rustToolchain # rustfmt, same version as `cargo fmt`
          pkgs'.nixfmt
          pkgs'.taplo
        ]
        ++ resolve formatters;
      };

      docker' = import ./docker.nix {
        pkgs = pkgs';
        inherit bin pname;
        docker = resolve docker;
        library = isLibrary;
        where = "lib.rust.mkProject";
      };
    in
    {
      # A library installs nothing, so it gets no packages (`nix build` errors
      # clearly instead of producing an empty result).
      packages =
        lib.optionalAttrs (!isLibrary) {
          inherit bin;
          default = bin;
        }
        // docker';

      checks = {
        ${if isLibrary then "build" else "bin"} = bin;
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
      // treefmt.checks
      // resolve extraChecks;

      inherit (treefmt) formatter;

      devShell = craneLib.devShell {
        inputsFrom = [ bin ];
        packages = [
          pkgs'.bacon
          treefmt.formatter
        ];
      };
    };
}
