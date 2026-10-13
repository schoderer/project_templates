# 0001. One Nix monorepo for all services and tools

- Status: accepted
- Date: {% now 'utc', '%Y-%m-%d' %}

## Context

{{ cookiecutter.project_name }} will consist of several services and internal
tools, possibly written in different languages. Every project needs
reproducible builds, container images, a way to run its tests and linters, and
a development environment, and the platform as a whole needs one place to
build, check and run everything.

## Decision

We keep all services and tools in one repository built with Nix flakes:

- every project in `services/` or `tools/` has its own flake and a
  `nix/default.nix` with a small contract (binary, docker image for services,
  checks, dev shell);
- the root flake discovers projects automatically and aggregates them:
  `nix build`, `nix build .#docker`, `nix flake check`, `just up`;
- all projects share one pinned nixpkgs (`flake.lock` at the root,
  `sync-locks` for the project flakes);
- new projects start from the language templates in `templates/`.

## Consequences

- Builds, images and tool versions are reproducible on every machine and in
  CI; the only prerequisites are Nix, git and docker.
- Each project stays independently buildable and could be moved to its own
  repository later.
- Developers need basic Nix knowledge to change build definitions; the
  templates and the contract keep that surface small.
- Updating nixpkgs updates the toolchains of all projects at once
  (`just update`), which keeps them consistent but must be tested together.
