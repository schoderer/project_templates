# Shared by the language libs (nix/rust.nix, go.nix, python.nix, node.nix): the
# parts every `mkProject` has in common.
rec {
  # Options that reference packages may be given as `pkgs -> value`, because
  # mkFlake users have no per-system pkgs: buildInputs = pkgs: [ pkgs.sqlite ];
  resolve = pkgs: v: if builtins.isFunction v then v pkgs else v;

  # The project source without local build/tool state. With `path:` flakes (jj)
  # `./.` contains untracked dirs like target/ or .venv; without this, every
  # check would copy them and rebuild whenever they change. The fixed name also
  # keeps the unpack dir from being called e.g. `go` (clashes with GOPATH).
  filterSource =
    pkgs: src:
    let
      inherit (pkgs) lib;
      ignoredDirs = [
        "target"
        ".venv"
        "node_modules"
        "dist"
        ".direnv"
        "__pycache__"
        ".pytest_cache"
        ".ruff_cache"
        ".mypy_cache"
      ];
    in
    lib.cleanSourceWith {
      # cleanSource already drops VCS dirs (.git, .jj, …) and result* symlinks.
      src = lib.cleanSource src;
      name = "source";
      filter = path: type: !(type == "directory" && builtins.elem (baseNameOf path) ignoredDirs);
    };

  # A check that runs `cmd` in a writable copy of the (filtered) source.
  runInSource =
    pkgs: src: name: inputs: cmd:
    pkgs.runCommand name { nativeBuildInputs = inputs; } ''
      cp -r ${src} project
      chmod -R u+w project
      cd project
      export HOME=$TMPDIR
      ${cmd}
      touch $out
    '';

  # The common tail of every mkProject:
  #   - libraries get no packages (nothing to install) and no docker image
  #   - binaries get bin/default and, on Linux, dockerImage
  #   - the build check is `bin` (or `build` for libraries)
  #   - treefmt: `formatter` for `nix fmt` + the devShell, and checks.treefmt
  #     when src has a treefmt.toml
  # `docker`, `extraChecks` and `formatters` are the raw user options (resolved
  # here); `devShell` is a function of the treefmt wrapper.
  mkOutputs =
    {
      pkgs,
      src, # filtered source
      pname,
      # Executable in ${bin}/bin: docker entrypoint (Python scripts can differ from pname).
      mainProgram ? pname,
      bin,
      buildCheck ? bin,
      isLibrary,
      # null/true (defaults), false, or { name, tag, config, copyToRoot, entrypoint }.
      docker,
      checks,
      extraChecks,
      # The language's formatter programs; nixfmt and taplo are always added.
      formatters,
      devShell,
    }:
    let
      inherit (pkgs) lib;
      docker' = resolve pkgs docker;

      formatter = pkgs.writeShellApplication {
        name = "treefmt";
        runtimeInputs = [
          pkgs.treefmt
          pkgs.nixfmt
          pkgs.taplo
        ]
        ++ resolve pkgs formatters;
        text = ''exec treefmt "$@"'';
      };

      dockerOpts = {
        name = "ghcr.io/schoderer/${pname}";
        tag = "latest";
        config = { };
        copyToRoot = [ ];
        entrypoint = [ "${bin}/bin/${mainProgram}" ];
      }
      // (if builtins.isAttrs docker' then docker' else { });

      dockerImage = pkgs.dockerTools.buildImage {
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
    in
    {
      packages =
        lib.optionalAttrs (!isLibrary) {
          inherit bin;
          default = bin;
        }
        # Linux-only: building an image on darwin needs a Linux builder.
        // lib.optionalAttrs (!isLibrary && docker' != false && pkgs.stdenv.hostPlatform.isLinux) {
          inherit dockerImage;
        };

      checks = {
        ${if isLibrary then "build" else "bin"} = buildCheck;
      }
      // checks
      // lib.optionalAttrs (builtins.pathExists ((src.origSrc or src) + "/treefmt.toml")) {
        treefmt = runInSource pkgs src "treefmt-check" [ formatter ] "treefmt --ci";
      }
      // resolve pkgs extraChecks;

      inherit formatter;
      devShell = devShell formatter;
    };
}
