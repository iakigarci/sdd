---
name: project-init
description: "Turn a fresh checkout of this template into a real project: interview, pick the stack, fill AGENTS.md and SPEC.md, apply the language template. Run once."
disable-model-invocation: true
---

Turn this template checkout into a real project. Run once, right after "Use this template".

## 1. Explore

Read `AGENTS.md`, `SPEC.md`, `release-please-config.json`, `templates/`, `git remote -v`, and any code already present (`go.mod`, `pyproject.toml`, source dirs).

If `AGENTS.md` contains no `{{` placeholders, the project is already initialised: stop and say so.

## 2. Grill

Invoke the `grilling` skill and the `domain-modeling` skill. Domain terms that come up in the interview go into `GLOSSARY.md` as they are resolved.

The design tree to resolve (answers open further branches; follow them):

- **Purpose**: the problem, who has it, a one-line pitch.
- **Shape**: HTTP service, worker/consumer, CLI, or library; one service or several microservices.
- **Bounded contexts**: the first contexts and their core terms (DDD, `docs/standards/go.md`). More than one context → multi-context glossary (`GLOSSARY-MAP.md`).
- **Language**: Go. Python only when the core problem needs a library Go lacks: name that library and the Go option rejected. This decision is always recorded as an ADR.
- **Module path / package name**: derive from `git remote -v` and confirm.
- **Dependencies**: PostgreSQL, NATS JetStream, gRPC between microservices, external APIs. The defaults in `docs/standards/go.md` apply unless the interview finds a reason not to.
- **Repository visibility**: public, or private with or without GitHub Code Security (decides CodeQL and dependency review).
- **Runtime**: container image or not, where it runs.
- **Release**: release-please tags and changelog (default); GoReleaser binaries for a CLI.
- **Scope**: goals as observable outcomes, non-goals, constraints (latency, security, compliance).

Completion: the frontier is empty and the user confirms the shared understanding.

## 3. Apply

Work on a `chore/project-init` branch.

1. Copy `templates/<language>/` into the repo root, merging `.github/` into the existing one.
2. Pick the delivery for the shape and copy it to `.github/workflows/release.yml`:
   - service → `templates/release/container.yml`; keep `Dockerfile` and `.dockerignore`, and add a `docker` entry to `.github/dependabot.yml`.
   - Go CLI → `templates/release/goreleaser.yml`; keep `.goreleaser.yaml`.
   - library → `templates/release/tag-only.yml`.
   Delete the delivery files the shape does not use, then delete `templates/`.
3. Delete the unused file in `docs/standards/`, and `.github/rulesets/template.json` (the template repo's own ruleset).
4. Trim to what the project uses:
   - No gRPC → no `buf.yaml`. gRPC → `buf config init` under `api/proto`, plus `buf.gen.yaml` for Go output.
   - No Postgres or NATS → delete the `integration` job in `ci.yml` and the `test-integration` recipe.
   - Private repo without GitHub Code Security → delete the `dependency-review` and `codeql` jobs and the `pull_request` trigger from `security.yml` (keep `scheduled-scan`).
5. Fill every placeholder (`{{UPPER_CASE}}`): `AGENTS.md`, `SPEC.md`, `release-please-config.json` (`RELEASE_TYPE` is `go` or `python`), `.goreleaser.yaml` and the Go `Dockerfile` (`BINARY`: the directory name under `cmd/`), the Python `Dockerfile` (`ENTRYPOINT`). `CODEQL_LANGUAGE` (`go` or `python`) in `security.yml`. `STANDARDS_FILE` is the kept `docs/standards/*.md`. A section the interview left empty says "None yet" rather than an invented answer.
6. Write `docs/adr/0001-<language>-as-primary-language.md` using the format in the `domain-modeling` skill's `ADR-FORMAT.md`.
7. `mise install`, then initialise the module with a minimal entry point for the chosen shape and a passing test that covers it, so the gate has something to run:
   - Go: `go mod init <module path>`, `cmd/<name>/main.go` (wiring only), the first context as `internal/<context>/{domain,app,adapters}`.
   - Python: `uv init --package <name>`, merge `pyproject.tools.toml` into `pyproject.toml` and delete it, `uv add --dev ruff ty pytest pytest-cov`, tests under `tests/`.
8. Replace `README.md` with a project README: pitch, prerequisites (`mise install`, `lefthook install`), the `just` commands, links to `SPEC.md` and `AGENTS.md`, and the `RELEASE_PLEASE_TOKEN` note from the template README.
9. Delete `.agents/skills/project-init/`: it is single-use.
10. Keep `.claude/` and `.github/workflows/hooks.yml` as they are: the guard hook is already active, and the format hook starts working once the justfile exists.

## 4. Configure GitHub

Show the user these commands, then run them once they confirm:

```bash
gh repo edit --enable-squash-merge --squash-merge-commit-message pr-title-description \
  --enable-rebase-merge=false --enable-merge-commit=false --delete-branch-on-merge --allow-update-branch
gh api -X PUT repos/{owner}/{repo}/actions/permissions/workflow \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true
gh api -X POST repos/{owner}/{repo}/rulesets --input .github/rulesets/main.json
```

Rulesets need a public repo or GitHub Pro/Team. On a private repo without them the last command returns 403: report that `main` is unprotected, and that the PR flow then rests on `AGENTS.md` alone.

## 5. Verify and ship

1. `grep -rnE '\{\{[A-Z_]+\}\}' --exclude-dir=.git --exclude-dir=.agents .` prints nothing.
2. `lefthook install`, then `just check` passes, and `python3 -m unittest discover -s .claude/hooks` passes.
3. Commit (`chore: initialise project from template`), push, open the PR with the `pr` skill, and `gh pr checks --watch` until `check` and `pr-title` are green.

A missing tool is reported with its install command; the gate is never skipped silently. Done when CI is green on the PR: report its URL for the user to review and squash-merge, then suggest `/grill-with-docs` for the first feature.
