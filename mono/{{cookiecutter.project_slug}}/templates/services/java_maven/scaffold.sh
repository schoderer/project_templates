# shellcheck shell=bash
# Runs once in the project's dev shell right after scaffolding, then is deleted.
# Download the Maven plugins and dependencies once and pin their hash
# (`mvnHash` in nix/default.nix), which depends on the Maven in nixpkgs.
set -euo pipefail
system=$(nix eval --raw --impure --expr builtins.currentSystem)
hash=$(nix build --no-link ".#packages.$system.default.fetchedMavenDeps" 2>&1 |
  sed -n 's/^ *got: *\(sha256-[A-Za-z0-9+/=]*\)$/\1/p' || true)
if [[ -z $hash ]]; then
  echo "could not determine mvnHash; set it by hand (see nix/default.nix)" >&2
  exit 1
fi
sed -i "s|mvnHash = lib.fakeHash;|mvnHash = \"$hash\";|" nix/default.nix
echo "mvnHash = $hash"
