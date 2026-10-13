# Documents

System architecture and business documentation for the whole platform. Nix
ignores this folder: it is not built, formatted or checked.

```
documents/
  adr/            architecture decision records (start here)
  architecture/   system context, component diagrams, data flows
  business/       domain glossary, requirements, process descriptions
  runbooks/       operational procedures per service
```

Create the other folders when their first document arrives. Keep documentation
about a single project's internals in that project's README; put cross-cutting
material here.

## Architecture decision records

One short markdown file per significant decision, numbered in order:
copy `adr/0000-template.md` to `adr/NNNN-short-title.md`. Records are never
deleted; a decision that changes gets a new record that supersedes the old one.
`adr/0001-nix-monorepo.md` records how this repository is organised.
