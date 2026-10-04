# Coding standards

Rules for every language in this repo. Language rules live in `docs/standards/`. Tooling enforces formatting and lint rules; this file covers what tooling cannot.

## Commits

Every commit on `main` is one squash-merged PR, and its message is the PR's title and description. Branch commits are free-form: they are squashed away.

The PR title is a [Conventional Commit](https://www.conventionalcommits.org/) subject; `scripts/check-pr-title.sh` (CI job `pr-title`) holds the allowed types and length.

- Subject: imperative, lower case, no trailing period.
- `!` or a `BREAKING CHANGE:` footer for anything that breaks a consumer. release-please derives versions and the changelog from these.
- One logical change per PR.

## Branches and pull requests

- Claude Code hooks (`.claude/settings.json`) deny force-pushes, pushes to `main` and PR merges. They are guard rails; on a free private repo without a ruleset they are the only ones.
- `.github/rulesets/main.json` protects `main`: PR only, squash merge only, linear history, and the CI jobs it lists must pass.
- Branch names are `<type>/<issue>-<slug>`, e.g. `feat/42-invoice-export`; `scripts/check-branch-name.sh` (CI job `branch-name`) checks them and lists the exempt bot branches.
- One PR = one commit on `main`. Review feedback goes in as new commits on the branch. Keep the branch current with GitHub's "Update branch" or by merging `main` in: the squash flattens it either way.
- The PR body follows the [`pr` skill](../.agents/skills/pr/SKILL.md) template ([`.github/pull_request_template.md`](../.github/pull_request_template.md) mirrors it), opens with `Closes #<n>` on its first line (then `Part of #<parent>` when the issue belongs to a larger feature, which links the parent without closing it), and becomes the commit message, so it describes the final change, not the review history.
- Aim for a diff a reviewer can hold in their head (roughly under 400 changed lines, excluding generated files).

## CI/CD

- CI (`.github/workflows/ci.yml`) runs `just check` with the toolchain pinned in `mise.toml`, so local and CI gates are identical. `pr-title.yml` checks the PR title, which becomes the commit subject; `branch-name.yml` checks the branch name.
- Releases: merging to `main` updates a release-please PR (version bump + changelog from commit types). Merging that PR tags the release and runs the publish job: container image to GHCR for services, GoReleaser binaries for CLIs, tag only for libraries.
- Dependabot config per language lives in `templates/*/.github/dependabot.yml`.

## Agent instructions

- `AGENTS.md` is loaded on every agent turn, so it holds only what every task needs, capped at 150 lines including its `@` imports (`scripts/check-agents-md.sh`, part of `just check`). Detail goes in `docs/` or a skill, reached by a one-line pointer.
- `CLAUDE.md`, when present, imports `AGENTS.md` with a line holding only `@AGENTS.md` (or is a symlink to it), so Claude Code loads the same instructions as every other agent (`scripts/check-claude-md.sh`, part of `just check`).

## Security and dependency checks

| Check | Tool | Where |
|---|---|---|
| Known vulnerabilities in dependencies | `govulncheck` / `pip-audit` | `just check` (every PR) and weekly on `main` |
| New vulnerable or copyleft dependencies in a PR | `dependency-review-action` | `security.yml` on PRs |
| Static analysis (SAST) | `gosec` via golangci-lint / ruff `S` rules; CodeQL `security-extended` | `just check`; `security.yml` |
| Secrets in git history | `gitleaks` | `just check`, pre-push hook, weekly |
| Workflow security (injection, unpinned actions, permissions) | `zizmor` | `just check` |
| Container image vulnerabilities | `trivy` (fixable HIGH/CRITICAL fail) | release job, before push |
| Supply chain | actions pinned by SHA, `permissions: contents: read` by default, SBOM + provenance on images | every workflow |
| Dependency tidiness and lockfile | `go mod tidy -diff` / `uv lock --check` | `just check` |

A finding is fixed, or suppressed inline with the reason (`//nolint:gosec // reason`, `.gitleaksignore` entry), never ignored by weakening the gate.

Tools a `just` recipe fetches from the network are pinned to an exact version: `go run <pkg>@vX.Y.Z`, `uv run --with <pkg>==X.Y.Z`. Never `@latest` or an unpinned `--with`; `scripts/pinned-tools_test.sh` checks the justfiles.

## Tests

- Coverage threshold is enforced by `just check` (default 80%), measured across packages. Left out: Go entry points under `cmd/` (they only wire dependencies), generated code, and infrastructure adapters (`adapters/postgres|nats|grpc`, `platform/postgres|nats`), which the integration tests cover.
- Go test mechanics: [`golang-testing`](../.agents/skills/golang-testing/SKILL.md).

## Errors

- Return errors to the caller with context; crash only on programmer errors at startup.
- Go wrapping, sentinels and the log-or-return rule: [`golang-error-handling`](../.agents/skills/golang-error-handling/SKILL.md).

## Logging and observability

- Log content rule for agents and code alike: [AGENTS.md](../AGENTS.md#working-rules).
- Services expose health endpoints and emit counters/histograms for request rate, errors and latency.
- Go logging and metrics: [`golang-observability`](../.agents/skills/golang-observability/SKILL.md).

## Dependencies

- Standard library first. A new third-party dependency is justified in the PR (why, licence, maintenance) and passes the vulnerability scan.
- Licences compatible with the project; no copyleft in services without an ADR.

## Compatibility

- Exported APIs, wire formats, CLI flags and database schemas change only with a spec that asks for it; breaking changes are marked `!`.
- Schema migrations are forward-only and deployable before the code that needs them.

## Configuration and secrets

- Configuration from environment variables, validated at startup, with sane defaults for local runs.
- Secrets never in the repo, logs or error messages.

## Review

- Findings carry a severity: **High** (bug, data loss, security), **Medium** (maintainability, missing test), **Low** (nit). The [`standards-reviewer`](../.claude/agents/standards-reviewer.md) applies it, and [`/code-review`](../.agents/skills/code-review/SKILL.md) runs it.
- Every review states its security findings, or that it saw none.
