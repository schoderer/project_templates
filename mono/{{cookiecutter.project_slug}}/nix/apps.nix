# flake-parts module: helper apps for working with the monorepo.
#
#   nix run .#new-service -- <lang> <name>   scaffold services/<name> from templates/services/<lang>
#   nix run .#new-tool -- <lang> <name>      scaffold tools/<name> from templates/tools/<lang>
#   nix run .#new-service                    list the available languages
#   nix run .#sync-locks [-- --check]        pin every project flake.lock to the root flake.lock
#   nix run .#docker-load                    build every service image and `docker load` it
#
# The scripts work on the git checkout (not the nix store copy), so run them
# from inside the repository.
_: {
  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # `nix` itself is deliberately not a runtime input: the scripts use the
      # nix already on PATH so they match the installed daemon version.
      sync-locks = pkgs.writeShellApplication {
        name = "sync-locks";
        runtimeInputs = with pkgs; [
          git
          jq
        ];
        text = ''
          # Every project flake has its own flake.lock for standalone use. This
          # pins each input it shares with the root to the root's locked revision,
          # so `cd services/x && nix build` and `nix build .#x` build the same thing.
          #
          #   sync-locks                  sync every project
          #   sync-locks <dir>...         sync specific project directories
          #   sync-locks --check [<dir>]  only report drift (exit 1), used in CI
          check=0
          if [[ ''${1:-} == "--check" ]]; then check=1; shift; fi

          root=$(git rev-parse --show-toplevel)
          root_lock="$root/flake.lock"

          if [[ $# -gt 0 ]]; then
            dirs=("$@")
          else
            mapfile -t dirs < <(find "$root/services" "$root/tools" -mindepth 2 -maxdepth 2 -name flake.nix -printf '%h\n' 2>/dev/null | sort)
          fi

          # Locked revision of input $2 in lock file $1 (empty when absent).
          locked_rev() {
            jq -r --arg n "$2" '.nodes[.nodes.root.inputs[$n] // "-"].locked.rev // empty' "$1" 2>/dev/null || true
          }
          # Pinned flake reference for root input $1, e.g. github:NixOS/nixpkgs/<rev>.
          root_ref() {
            jq -r --arg n "$1" '.nodes[.nodes.root.inputs[$n]].locked
              | if .type == "github" then "github:\(.owner)/\(.repo)/\(.rev)"
                else error("only github inputs are supported, got \(.type)") end' "$root_lock"
          }

          drift=0
          for dir in "''${dirs[@]}"; do
            dir=$(realpath "$dir")
            rel=''${dir#"$root"/}
            # Inputs declared by the project flake that also exist in the root.
            mapfile -t shared < <(nix eval --impure --json --expr \
              "builtins.attrNames ((import $dir/flake.nix).inputs or { })" | jq -r '.[]' |
              while read -r input; do
                [[ -n $(locked_rev "$root_lock" "$input") ]] && echo "$input"
              done)

            if [[ $check -eq 1 ]]; then
              for input in "''${shared[@]}"; do
                want=$(locked_rev "$root_lock" "$input")
                have=$(locked_rev "$dir/flake.lock" "$input")
                if [[ $want != "$have" ]]; then
                  echo "$rel: $input is ''${have:-unlocked}, root has $want" >&2
                  drift=1
                fi
              done
              continue
            fi

            overrides=()
            for input in "''${shared[@]}"; do
              overrides+=(--override-input "$input" "$(root_ref "$input")")
            done
            echo "syncing $rel (''${shared[*]})"
            nix flake lock "$dir" "''${overrides[@]}"
          done

          if [[ $drift -eq 1 ]]; then
            echo "project locks differ from the root flake.lock; run: nix run .#sync-locks" >&2
            exit 1
          fi
        '';
      };

      # Copies templates/<kind>/<lang> to <kind>/<name>, replacing these
      # placeholders in file names and file contents:
      #   __NAME__        my-api          package / binary / image name
      #   __NAME_SNAKE__  my_api          crate / module name
      #   __DIR__         services/my-api path from the repo root
      #   __PORT__        8081            services only: host port for `just up`
      #                                   (one above the highest port in use)
      #
      # A template may contain `scaffold.sh`: it runs once inside the new
      # project's own dev shell (e.g. to generate Cargo.lock) and is then deleted.
      # Adding a language is therefore just adding a template directory.
      mkScaffold =
        kind:
        let
          singular = lib.removeSuffix "s" kind;
        in
        pkgs.writeShellApplication {
          name = "new-${singular}";
          runtimeInputs = with pkgs; [
            git
            gnused
            gnugrep
            findutils
            coreutils
            sync-locks
          ];
          text = ''
            root=$(git rev-parse --show-toplevel)
            templates="$root/templates/${kind}"

            usage() {
              echo "usage: nix run .#new-${singular} -- <lang> <name>   (name in kebab-case, e.g. billing-api)" >&2
              echo "languages: $(find "$templates" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | xargs)" >&2
              exit 1
            }

            lang=''${1:-}
            name=''${2:-}
            [[ -n $lang && -d $templates/$lang ]] || usage
            [[ $name =~ ^[a-z][a-z0-9]*(-[a-z0-9]+)*$ ]] || usage

            snake=''${name//-/_}
            dir="${kind}/$name"
            dest="$root/$dir"
            if [[ -e $dest ]]; then
              echo "$dir already exists" >&2
              exit 1
            fi

            # Next free host port: one above the highest "<port>:8080" mapping.
            port=$(grep -rhoE '"[0-9]+:8080"' "$root"/services/*/nix/default.nix 2>/dev/null |
              tr -d '"' | cut -d: -f1 | sort -n | tail -n1 || true)
            port=$(( ''${port:-8080} + 1 ))

            mkdir -p "$root/${kind}"
            cp -r "$templates/$lang" "$dest"
            chmod -R u+w "$dest"

            # Rename placeholder paths, deepest first so parents are renamed last.
            find "$dest" -depth -name '*__NAME*' | while read -r path; do
              base=$(basename "$path")
              base=''${base//__NAME_SNAKE__/$snake}
              base=''${base//__NAME__/$name}
              mv "$path" "$(dirname "$path")/$base"
            done
            grep -rlZ -e __NAME__ -e __NAME_SNAKE__ -e __DIR__ -e __PORT__ "$dest" |
              xargs -0 -r sed -i \
                -e "s/__NAME_SNAKE__/$snake/g" \
                -e "s/__NAME__/$name/g" \
                -e "s|__DIR__|$dir|g" \
                -e "s/__PORT__/$port/g"

            # Flakes in a git repo only see tracked files: without this the new
            # project would be invisible to `nix build`.
            git -C "$root" add "$dest"
            sync-locks "$dest"

            if [[ -f $dest/scaffold.sh ]]; then
              echo "running $dir/scaffold.sh in the project's dev shell"
              git -C "$root" add "$dest"
              (cd "$dest" && nix develop "$dest" --command bash scaffold.sh)
              rm "$dest/scaffold.sh"
            fi
            git -C "$root" add --all "$dest"

            echo "created $dir from templates/${kind}/$lang; try: nix build .#$name"
          '';
        };

      docker-load = pkgs.writeShellApplication {
        name = "docker-load";
        runtimeInputs = [ pkgs.docker-client ];
        text = ''
          shopt -s nullglob # no services yet: nothing to load
          for image in ${config.packages.docker}/*.tar.gz; do
            docker load --input "$image"
          done
        '';
      };

      app = description: drv: {
        type = "app";
        program = lib.getExe drv;
        meta = { inherit description; };
      };
    in
    {
      apps = {
        new-service = app "Scaffold services/<name> from templates/services/<lang>" (mkScaffold "services");
        new-tool = app "Scaffold tools/<name> from templates/tools/<lang>" (mkScaffold "tools");
        sync-locks = app "Pin project flake.lock files to the root flake.lock" sync-locks;
        docker-load = app "Build every service image and load it into docker" docker-load;
      };
    };
}
