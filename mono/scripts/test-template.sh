#!/usr/bin/env bash
# Self-test for the cookiecutter template.
#
#   scripts/test-template.sh [--docker] [output-dir]
#
# Generates a project, scaffolds one service and one tool from every language
# template, then runs everything a developer would: formatting, lock sync,
# `nix flake check`, all builds, the compose file, a standalone sub-flake and
# each tool binary. With --docker it also starts every service with `just up`
# and probes /health on each assigned port (needs a docker daemon).
#
# Requires nix (with flakes) and git; cookiecutter is taken from nixpkgs when
# it is not on PATH.
set -euo pipefail

with_docker=0
if [[ ${1:-} == "--docker" ]]; then with_docker=1; shift; fi

template=$(cd "$(dirname "$0")/.." && pwd)
out=${1:-$(mktemp -d)}
project="$out/template-test"
nix=(nix --extra-experimental-features "nix-command flakes")

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

step "generating project in $project"
rm -rf "$project"
if command -v cookiecutter >/dev/null; then
  cookiecutter --no-input -o "$out" "$template" project_name="Template Test"
else
  "${nix[@]}" shell nixpkgs#cookiecutter --command \
    cookiecutter --no-input -o "$out" "$template" project_name="Template Test"
fi
cd "$project"

services=()
for kind in services tools; do
  for dir in templates/"$kind"/*/; do
    lang=$(basename "$dir")
    # Project names are kebab-case; language names may contain `_` (java_maven).
    if [[ $kind == services ]]; then name="svc-${lang//_/-}"; services+=("$name"); else name="cli-${lang//_/-}"; fi
    step "scaffolding $kind/$name from templates/$kind/$lang"
    "${nix[@]}" run ".#new-${kind%s}" -- "$lang" "$name"
  done
done

step "formatting (templates must already be formatted)"
"${nix[@]}" fmt
git diff --exit-code

step "project locks match the root lock"
"${nix[@]}" run .#sync-locks -- --check

step "nix flake check"
"${nix[@]}" flake check -L

step "building all binaries and images"
"${nix[@]}" build -L .#default .#docker .#compose --out-link result
"${nix[@]}" run nixpkgs#docker-compose -- --file result-2 config --quiet

step "standalone sub-flake"
(cd "services/${services[0]}" && "${nix[@]}" flake check -L && "${nix[@]}" build .#docker --no-link)

step "running every tool"
for bin in result/bin/cli-*; do
  echo "$(basename "$bin"): $("$bin" greet template)"
done

if [[ $with_docker -eq 1 ]]; then
  step "starting every service with docker compose"
  "${nix[@]}" run .#up -- --detach --wait
  trap '"${nix[@]}" run .#down' EXIT
  for name in "${services[@]}"; do
    port=$(grep -oE '"[0-9]+:8080"' "services/$name/nix/default.nix" | tr -d '"' | cut -d: -f1)
    echo "$name (:$port): $(curl -sf "http://localhost:$port/health")"
  done
fi

step "template OK ($project)"
