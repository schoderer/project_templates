# shellcheck shell=bash
# Runs once in the project's dev shell right after scaffolding, then is deleted.
# Resolve current dependency versions into a fresh package-lock.json (no install).
npm install --package-lock-only --no-audit --no-fund
