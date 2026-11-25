# Go project library: buildGoModule + go test + optional docker image.
#
#   lib.go.mkProject { pkgs, src, ... } => { packages, checks, devShell, formatter }
#
# Same contract as nix/rust.nix. `mkFlake` (in ../flake.nix) wraps it for
# every system and turns it into flake outputs.
{ }:
{
  mkProject =
    {
      pkgs,
      src,
      # Hash of the module's dependencies. `null` is right while go.mod has no
      # requirements (or when deps are vendored in ./vendor). After adding a
      # dependency set it to "" and copy the real hash
      # from the `nix build` error.
      vendorHash ? null,
      # Default: last path element of the `module` line in go.mod.
      pname ? null,
      version ? "0.0.1",
      # Packages to build/install, relative to src (e.g. [ "cmd/server" ]).
      # Default: every main package.
      subPackages ? null,
      # Static binaries by default, which keeps the docker image to the binary alone.
      cgo ? false,
      ldflags ? [
        "-s"
        "-w"
      ],
      # Everything below may also be a function `pkgs -> value`, which is how
      # mkFlake users (who have no per-system pkgs) reference packages.
      go ? null,
      nativeBuildInputs ? [ ],
      buildInputs ? [ ],
      # Merged last into buildGoModule's arguments (escape hatch: tags, env, ...).
      goArgs ? { },
      # true for a library (no main package): no packages, no docker, and the
      # build/test check is called `build`. Explicit because detecting
      # `package main` reliably would mean parsing every .go file.
      library ? false,
      # null/true (defaults), false, or { name, tag, config, copyToRoot, entrypoint }.
      # Binaries only; see ./docker.nix.
      docker ? null,
      # Extra `nix flake check` gates.
      vet ? true,
      lint ? false, # golangci-lint
      extraChecks ? { },
      # devShell-only tools added to go, gopls, delve, golangci-lint.
      devPackages ? [ ],
      # Extra programs for formatters you add to treefmt.toml (gofmt, nixfmt and
      # taplo are always there).
      formatters ? [ ],
    }:
    let
      inherit (pkgs) lib;
      resolve = v: if builtins.isFunction v then v pkgs else v;

      goPkg = if go != null then resolve go else pkgs.go;
      buildGoModule = pkgs.buildGoModule.override { go = goPkg; };

      goMod = src + "/go.mod";
      moduleLine = lib.findFirst (lib.hasPrefix "module ") null (
        lib.splitString "\n" (builtins.readFile goMod)
      );
      modulePath =
        assert lib.assertMsg (moduleLine != null) "lib.go.mkProject: no `module` line in ${toString goMod}";
        lib.trim (lib.removePrefix "module " moduleLine);
      pname' = if pname != null then pname else baseNameOf modulePath;

      # Fixed store name: the unpacked source dir is named after it, and a dir
      # called `go` would collide with buildGoModule's GOPATH ($TMPDIR/go).
      src' = lib.cleanSourceWith {
        inherit src;
        name = "source";
      };

      bin = buildGoModule (
        {
          pname = pname';
          src = src';
          inherit
            version
            vendorHash
            ldflags
            ;
          nativeBuildInputs = resolve nativeBuildInputs;
          buildInputs = resolve buildInputs;
          env.CGO_ENABLED = if cgo then "1" else "0";
          # `go test ./...` runs in checkPhase, so building is testing.
          doCheck = true;
          meta.mainProgram = pname';
        }
        // lib.optionalAttrs (subPackages != null) { inherit subPackages; }
        // resolve goArgs
      );

      # Run `cmd` inside the module (with dependencies available) as a check.
      goCheck =
        name: extraNative: cmd:
        bin.overrideAttrs (old: {
          pname = "${pname'}-${name}";
          nativeBuildInputs = old.nativeBuildInputs ++ extraNative;
          buildPhase = ''
            runHook preBuild
            ${cmd}
            runHook postBuild
          '';
          doCheck = false;
          installPhase = "touch $out";
          fixupPhase = ":";
        });

      treefmt = import ./treefmt.nix {
        inherit pkgs src;
        formatters = [
          goPkg # gofmt
          pkgs.nixfmt
          pkgs.taplo
        ]
        ++ resolve formatters;
      };

      docker' = import ./docker.nix {
        inherit pkgs bin library;
        pname = pname';
        docker = resolve docker;
        where = "lib.go.mkProject";
      };
    in
    {
      # A library installs nothing, so it gets no packages (`nix build` errors
      # clearly instead of producing an empty result).
      packages =
        lib.optionalAttrs (!library) {
          inherit bin;
          default = bin;
        }
        // docker';

      checks = {
        ${if library then "build" else "bin"} = bin; # includes `go test ./...`
      }
      // lib.optionalAttrs vet { vet = goCheck "vet" [ ] "go vet ./..."; }
      // lib.optionalAttrs lint {
        lint = goCheck "lint" [ pkgs.golangci-lint ] ''
          export HOME=$TMPDIR GOLANGCI_LINT_CACHE=$TMPDIR/golangci-lint
          golangci-lint run ./...
        '';
      }
      // treefmt.checks
      // resolve extraChecks;

      inherit (treefmt) formatter;

      devShell = pkgs.mkShell {
        inputsFrom = [ bin ];
        packages = [
          goPkg
          pkgs.gopls
          pkgs.delve
          pkgs.golangci-lint
          treefmt.formatter
        ]
        ++ resolve devPackages;
      };
    };
}
