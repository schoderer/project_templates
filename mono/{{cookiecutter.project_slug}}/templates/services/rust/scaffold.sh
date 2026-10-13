# shellcheck shell=bash
# Runs once in the project's dev shell right after scaffolding, then is deleted.
# Resolve current dependency versions into a fresh Cargo.lock.
cargo generate-lockfile
