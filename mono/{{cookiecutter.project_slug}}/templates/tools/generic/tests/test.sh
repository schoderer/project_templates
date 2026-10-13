# shellcheck shell=bash
# Black-box tests for __NAME__; run by `nix flake check` with the binary on PATH.
set -euo pipefail

expect() {
  local want=$1; shift
  local got
  got=$("$@")
  if [[ $got != "$want" ]]; then
    echo "FAIL: $* -> '$got', want '$want'" >&2
    exit 1
  fi
  echo "ok: $*"
}

expect "Hello, world!" __NAME__ greet
expect "HELLO, NIX!" __NAME__ greet --shout nix
expect "0.1.0" __NAME__ version

if __NAME__ nope 2>/dev/null; then
  echo "FAIL: unknown command must fail" >&2
  exit 1
fi
echo "ok: unknown command fails"
