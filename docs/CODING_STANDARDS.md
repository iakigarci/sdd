# Coding standards

Rules for every language in this repo. Language rules live in `docs/standards/`. Tooling enforces formatting and lint rules; this file covers what tooling cannot.

## Commits

Every commit on `main` is one squash-merged PR, and its message is the PR's title and description. Branch commits are free-form: they are squashed away.

The PR title follows [Conventional Commits](https://www.conventionalcommits.org/): `<type>(<scope>)!: <subject>`.

- Types: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `build`, `ci`, `chore`, `revert`.
- Subject: imperative, lower case, no trailing period; the whole title at most 72 characters (CI checks it).
- `!` or a `BREAKING CHANGE:` footer for anything that breaks a consumer. release-please derives versions and the changelog from these.
- One logical change per PR.

## Branches and pull requests

- `main` is protected (`.github/rulesets/main.json`): changes arrive only by PR, with linear history, required `check` and `pr-title` jobs, and **squash merge** as the only merge method (commit title = PR title, commit message = PR description).
- Branch names: `<type>/<issue>-<slug>`, e.g. `feat/42-invoice-export`.
- One PR = one commit on `main`. Review feedback goes in as new commits on the branch; nothing is force-pushed. Keep the branch current with GitHub's "Update branch" or by merging `main` in: the squash flattens it either way.
- The PR body follows the `pr` skill (`.github/pull_request_template.md` mirrors it), closes its issue with `Closes #<n>`, and becomes the commit message, so it describes the final change, not the review history.
- Aim for a diff a reviewer can hold in their head (roughly under 400 changed lines, excluding generated files).

## CI/CD

- CI (`.github/workflows/ci.yml`) runs `just check` with the toolchain pinned in `mise.toml`, so local and CI gates are identical. `pr-title.yml` checks the PR title, which becomes the commit subject.
- Releases: merging to `main` updates a release-please PR (version bump + changelog from commit types). Merging that PR tags the release and runs the publish job: container image to GHCR for services, GoReleaser binaries for CLIs, tag only for libraries.
- Dependabot opens weekly grouped updates with Conventional Commit prefixes, including the SHA pins of GitHub Actions.

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

## Tests

- Test behaviour through the public interface of a module, not its internals.
- Every acceptance criterion and every `ASSUMP-#` maps to a test.
- Coverage threshold is enforced by `just check` (default 80%). Go entry points under `cmd/` are excluded: they only wire dependencies.

## Errors

- Return errors to the caller with context; crash only on programmer errors at startup.
- Handle each error once: either log it or return it.

## Logging and observability

- Structured logs (key/value). Log IDs and hashes; never secrets, tokens or personal data.
- Services expose health endpoints and emit counters/histograms for request rate, errors and latency.

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

- Findings carry a severity: **High** (bug, data loss, security), **Medium** (maintainability, missing test), **Low** (nit).
- Every review states its security findings, or that it saw none.
