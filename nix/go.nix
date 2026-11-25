# Go project library: buildGoModule + go test/vet + optional docker image.
#
#   lib.go.mkProject { pkgs, src, ... } => { packages, checks, devShell, formatter }
#
# Same contract as nix/rust.nix. `mkFlake` (in ../flake.nix) wraps it for
# every system and turns it into flake outputs.
# Options are documented in ../Readme.md (common table + language section).
let
  project = import ./project.nix;
in
{
  mkProject =
    {
      pkgs,
      src,
      vendorHash ? null, # null while there are no dependencies (or they're vendored)
      pname ? null, # null: last element of the go.mod module path
      version ? "0.0.1",
      subPackages ? null, # null: every main package
      cgo ? false, # static binary by default
      ldflags ? [
        "-s"
        "-w"
      ],
      go ? null, # null: nixpkgs go
      nativeBuildInputs ? [ ],
      buildInputs ? [ ],
      goArgs ? { },
      library ? false, # explicit: detecting `package main` would mean parsing every .go file
      docker ? null,
      test ? true, # go test, in the build's check phase
      lint ? true, # go vet
      golangciLint ? false,
      extraChecks ? { },
      devPackages ? [ ],
      formatters ? [ ],
    }:
    let
      inherit (pkgs) lib;
      resolve = project.resolve pkgs;

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

      src' = project.filterSource pkgs src;

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
          doCheck = test;
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
    in
    project.mkOutputs {
      inherit
        pkgs
        bin
        docker
        extraChecks
        ;
      pname = pname';
      src = src';
      isLibrary = library;
      formatters = [ goPkg ] ++ resolve formatters; # gofmt

      checks =
        lib.optionalAttrs lint { lint = goCheck "lint" [ ] "go vet ./..."; }
        // lib.optionalAttrs golangciLint {
          golangci-lint = goCheck "golangci-lint" [ pkgs.golangci-lint ] ''
            export HOME=$TMPDIR GOLANGCI_LINT_CACHE=$TMPDIR/golangci-lint
            golangci-lint run ./...
          '';
        };

      devShell =
        formatter:
        pkgs.mkShell {
          inputsFrom = [ bin ];
          packages = [
            goPkg
            pkgs.gopls
            pkgs.delve
            pkgs.golangci-lint
            formatter
          ]
          ++ resolve devPackages;
        };
    };
}
