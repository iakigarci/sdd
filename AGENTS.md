# {{PROJECT_NAME}}

{{PURPOSE}}

## Stack

- Language: {{LANGUAGE}}. The reason is in `docs/adr/0001-*.md`. My default is Go; Python only when Go lacks a mature library for the core problem.
- How code is written here: `docs/CODING_STANDARDS.md` (all languages) and `{{STANDARDS_FILE}}`. Read both before writing or reviewing code.
- Scope, users and non-goals: `SPEC.md`. Read it before planning a feature.

## Commands

Every gate runs through `just`, locally and in CI:

- `just fmt`: format
- `just lint`: linters and static analysis
- `just test`: tests with the race detector
- `just check`: the full gate (format check, lint, coverage threshold, vulnerabilities, dependency tidiness). Done means `just check` passed in this session.

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

Every change reaches `main` through a GitHub PR that the user reviews and merges (rebase merge). Details in `docs/CODING_STANDARDS.md`.

1. Branch from an up-to-date `main`: `<type>/<issue>-<slug>`, e.g. `feat/42-invoice-export`.
2. Commit with Conventional Commits; each commit lands on `main` as-is, so each one builds and passes.
3. Push the branch and open the PR with `gh pr create`, body from the `pr` skill.
4. Watch CI (`gh pr checks --watch`) and fix until green.
5. Hand the user the PR URL. Merging is the user's step, on GitHub.

Force-push only your own feature branch, with `--force-with-lease`.

## Workflow

`/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement` → `/code-review` → PR body via the `pr` skill.
`/diagnosing-bugs` for hard bugs, `/improve-codebase-architecture` every few days, `/handoff` to continue in a fresh session.

## Agent skills

### Issue tracker

GitHub Issues through the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
