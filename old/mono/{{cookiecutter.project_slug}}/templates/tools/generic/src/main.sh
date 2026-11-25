# shellcheck shell=bash
# __NAME__: command line tool (bash).
#
#   __NAME__ greet [--shout] [NAME]
#   __NAME__ version
#
# Packaged by nix/default.nix: the shebang, `set -euo pipefail`, PATH and
# $VERSION are provided by writeShellApplication.

usage() {
  cat <<USAGE
usage: __NAME__ <command> [options]

commands:
  greet [--shout] [NAME]  print a greeting for NAME (default: world)
  version                 print the version
USAGE
}

greet() {
  local shout=false name=world
  while [[ $# -gt 0 ]]; do
    case $1 in
      --shout) shout=true ;;
      *) name=$1 ;;
    esac
    shift
  done
  local message="Hello, $name!"
  if $shout; then message=${message^^}; fi
  echo "$message"
}

# shellcheck disable=SC2154 # VERSION is set by writeShellApplication (runtimeEnv)
case ${1:-} in
  greet) shift; greet "$@" ;;
  version) echo "$VERSION" ;;
  help | -h | --help) usage ;;
  *) usage >&2; exit 2 ;;
esac
