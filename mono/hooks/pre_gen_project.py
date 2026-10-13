"""Validate the answers before anything is generated."""

import re
import sys

slug = "{{ cookiecutter.project_slug }}"
branch = "{{ cookiecutter.nixpkgs_branch }}"

if not re.fullmatch(r"[a-z][a-z0-9]*(-[a-z0-9]+)*", slug):
    sys.exit(f"ERROR: project_slug '{slug}' must be kebab-case, e.g. my-platform")

if not re.fullmatch(r"[A-Za-z0-9._-]+", branch):
    sys.exit(f"ERROR: nixpkgs_branch '{branch}' is not a valid branch name")
