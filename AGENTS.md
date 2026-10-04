# {{PROJECT_NAME}}

{{PURPOSE}}

## Stack

- Language: {{LANGUAGE}}. The reason is in `docs/adr/0001-*.md`. My default is Go; Python only when Go lacks a mature library for the core problem.
- How code is written here: `docs/CODING_STANDARDS.md` (all languages) and `{{STANDARDS_FILE}}`. Read both before writing or reviewing code.
- Scope, users and non-goals: `SPEC.md`. Read it before planning a feature.

## Commands

Every gate is a `just` recipe (`justfile`), run the same locally and in CI. Done means `just check` passed in this session.

## Token budget

- Chat replies use the `caveman` skill at `full` level. Code, comments, commits, PRs, issues and docs stay normal prose.
- When `rtk` is on PATH and your agent has no rtk hook, run noisy commands through it: `rtk git diff`, `rtk go test ./...`, `rtk golangci-lint run`.
- Read the part of a file you need, and search before reading whole files.

## Working rules

- Read the file, run the command, or say it is unknown: repo APIs, paths, command output and test results come from the repo, never from memory.
- A requirement the spec leaves open becomes an `ASSUMP-#` backed by a test (see `/implement`).
- Touch only what the task needs; leave unrelated code as you found it.
- Logs carry IDs, never secrets or personal data.

## Git and pull requests

Every change reaches `main` as a PR the user reviews; hooks, CI and the `main` ruleset enforce the rest (`docs/CODING_STANDARDS.md` → Branches and pull requests).

1. Branch from an up-to-date `main`; `scripts/check-branch-name.sh` holds the name format.
2. Push, open the PR with `gh pr create`, body from the `pr` skill.
3. Get CI green (`gh pr checks --watch`), then hand the user the PR URL.

## Workflow

`/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement` → `/code-review` → PR body via the `pr` skill.
`/diagnosing-bugs` for hard bugs, `/improve-codebase-architecture` every few days, `/handoff` to continue in a fresh session.

## Agent skills

### Issue tracker

GitHub Issues through the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
