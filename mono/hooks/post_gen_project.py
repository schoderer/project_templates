"""Finish the generated monorepo: optional CI, git repository, flake.lock.

Runs inside the generated project directory.
"""

import shutil
import subprocess
import sys
from pathlib import Path


def flag(value: str) -> bool:
    """Booleans arrive as True/False when prompted, as strings via --no-input key=value."""
    return value.strip().lower() in {"true", "yes", "y", "1"}


INCLUDE_CI = flag("{{ cookiecutter.include_github_ci }}")
INIT_GIT = flag("{{ cookiecutter.init_git }}")
LOCK_FLAKE = flag("{{ cookiecutter.lock_flake }}")


def run(*cmd: str) -> bool:
    print("+", " ".join(cmd))
    return subprocess.run(cmd, check=False).returncode == 0


if not INCLUDE_CI:
    shutil.rmtree(".github")

if INIT_GIT and not Path(".git").exists():
    if shutil.which("git"):
        # Nix flakes inside a git repository only see tracked files.
        run("git", "init", "--quiet", "--initial-branch=main")
        run("git", "add", "--all")
    else:
        print(
            "WARNING: git not found; run `git init && git add -A` before using nix",
            file=sys.stderr,
        )

if LOCK_FLAKE:
    if shutil.which("nix"):
        if run(
            "nix",
            "--extra-experimental-features",
            "nix-command flakes",
            "flake",
            "lock",
        ):
            if INIT_GIT and shutil.which("git"):
                run("git", "add", "flake.lock")
        else:
            print("WARNING: `nix flake lock` failed; run it manually", file=sys.stderr)
    else:
        print("nix not found; run `nix flake lock` once nix is installed")

print(
    """
Done. Next steps:
  cd {{ cookiecutter.project_slug }}
  nix develop                          # or: direnv allow
  just templates                       # available languages
  just new-service go my-api           # services/my-api
  just new-tool python my-cli          # tools/my-cli
  just check && just up                # check everything, run the services
"""
)
