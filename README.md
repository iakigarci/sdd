# sdd: spec-driven project template

A GitHub template for starting projects that all follow the same stack, standards and agent workflow. It works with any agent that reads `AGENTS.md` and `SKILL.md` (Claude Code, Codex, Cursor, Copilot, Gemini CLI, …).

## Start a project

1. **Use this template** on GitHub, then clone the new repo.
2. Install [`mise`](https://mise.jdx.dev) and the [`gh`](https://cli.github.com) CLI (logged in). Every other tool is pinned per project in `mise.toml`.
3. In your agent, run `/project-init`. It interviews you, picks the language (Go by default), fills `AGENTS.md` and `SPEC.md`, applies `templates/<language>/` and the release workflow for the project's shape, configures the GitHub repo (squash-only merges, ruleset on `main`), and delivers all of that as its first PR.
4. Start each feature with `/grill-with-docs`.

### Release token

release-please opens its release PR with `GITHUB_TOKEN` by default, and GitHub does not run workflows on PRs created by that token, so the required `check`/`pr-title` jobs never report. Add a fine-grained PAT (contents + pull requests: read/write on the repo) as the `RELEASE_PLEASE_TOKEN` secret; the workflow uses it when present.

## Git flow

`main` accepts changes only by PR, and each PR lands as one commit: squash merge only, with the PR title as the commit subject and the PR description as its body. Linear history, green `check` and `pr-title` jobs (`.github/rulesets/main.json`). Rulesets need a public repo or GitHub Pro/Team; on a free private repo `main` stays unprotected and the flow rests on `AGENTS.md`. Agents branch, commit, push, open the PR and get CI green; you review and merge on GitHub.

## Token reduction

Three layers, all agent-agnostic:

| Layer | What | Setup |
|---|---|---|
| Output | `caveman` skill, `full` level for chat (`AGENTS.md` → Token budget). Code, commits, PRs, issues and docs stay normal prose. | Vendored in `.agents/skills/caveman`. `/caveman lite` or `/caveman off` to change. |
| Tool output | [`rtk`](https://github.com/rtk-ai/rtk) compresses `git`, test, lint and build output before it reaches the context (60–90% on those commands). | Once per machine: `mise use -g rtk`, then `rtk init -g --hook-only --auto-patch` (Claude Code), `rtk init -g --codex`, `rtk init -g --agent cursor`, or `rtk init -g --gemini`. |
| Always-loaded context | `AGENTS.md` kept short; skill descriptions trimmed to one line (~1k tokens for all 30 model-invoked skills); workflow skills are user-invoked, so they cost nothing until typed. | Built in. |

## Workflow

```
/grill-with-docs   interview; writes GLOSSARY.md and docs/adr/ as decisions land
/to-spec           conversation → spec as a GitHub issue
/to-tickets        spec → tracer-bullet issues with blocking edges
/implement         criteria + ASSUMP-# → TDD → `just check` → evidence table → /code-review → commit
/code-review       Standards axis (docs/CODING_STANDARDS.md, docs/standards/) + Spec axis, in parallel
pr skill           PR body: Changes bullets, Summary, Evidence, Merge Danger
```

## Layout

| Path | What |
|---|---|
| `AGENTS.md` | Always-loaded agent instructions, kept short. `CLAUDE.md` imports it. |
| `SPEC.md` | Product-level scope; feature specs are GitHub issues. |
| `docs/CODING_STANDARDS.md`, `docs/standards/` | How code is written; read by `/code-review`. |
| `docs/agents/` | Issue tracker and domain-doc conventions for the skills. |
| `.agents/skills/` | Skills in the open `SKILL.md` format. `.claude/skills` is a symlink to it. |
| `templates/go`, `templates/python` | `mise.toml`, justfile, lint config, CI, dependabot, Dockerfile, gitignore per language (plus `.goreleaser.yaml` for Go CLIs). |
| `templates/release/` | Release workflow per shape: container (GHCR), goreleaser, tag-only. |
| `scripts/check-pr-title.sh` | Conventional Commit check for PR titles (CI). |
| `scripts/check-agents-md.sh` | Keeps `AGENTS.md` (with its `@` imports) at 150 lines or fewer; part of `just check`. |
| `.claude/settings.json`, `.claude/hooks/` | Claude Code hooks: deny force-push, push to `main` and PR merges; format the edited Go/Python file. Guard rails; the `main` ruleset is the real block. Tests run in `hooks.yml`. |
| `lefthook.yml` | pre-commit fmt/lint, pre-push `just check`. |
| `.github/` | PR template, PR-title check, security workflow (dependency review, CodeQL, weekly scans), `main` ruleset. |

## Security and dependency checks

Listed in `docs/CODING_STANDARDS.md` → Security and dependency checks: `govulncheck`/`pip-audit`, `gosec`/ruff `S`, CodeQL, dependency review, `gitleaks`, `zizmor`, `trivy` on release images, SHA-pinned actions, SBOM and provenance. CodeQL and dependency review are free on public repos and need GitHub Code Security on private ones.

## Skills

Vendored copies are listed with their source commits in `.agents/skills/VENDORED.md`. Local changes to vendored skills are listed there too, so they survive an upstream refresh.
