# sdd: spec-driven project template

A GitHub template for starting projects that all follow the same stack, standards and agent workflow. It works with any agent that reads `AGENTS.md` and `SKILL.md` (Claude Code, Codex, Cursor, Copilot, Gemini CLI, …).

## Start a project

1. **Use this template** on GitHub, then clone the new repo.
2. Install [`mise`](https://mise.jdx.dev) and the [`gh`](https://cli.github.com) CLI (logged in). Every other tool is pinned per project in `mise.toml`.
3. In your agent, run `/project-init`. It interviews you, picks the language (Go by default), fills `AGENTS.md` and `SPEC.md`, applies `templates/<language>/` and the release workflow for the project's shape, configures the GitHub repo and its `main` ruleset ([rules](docs/CODING_STANDARDS.md#branches-and-pull-requests)), and delivers all of that as its first PR.
4. Start each feature with `/grill-with-docs`.

### Release token

release-please opens its release PR with `GITHUB_TOKEN` by default, and GitHub does not run workflows on PRs created by that token, so the required `check`/`pr-title` jobs never report. Add a fine-grained PAT (contents + pull requests: read/write on the repo) as the `RELEASE_PLEASE_TOKEN` secret; the workflow uses it when present.

## Git flow

The rules are in [CODING_STANDARDS → Branches and pull requests](docs/CODING_STANDARDS.md#branches-and-pull-requests). This template's own gates are the root `justfile` (`just check`), run by its CI jobs. Rulesets need a public repo or GitHub Pro/Team; on a free private repo `main` stays unprotected and the flow rests on the Claude Code hooks and `AGENTS.md`.

## Token reduction

The rules are in [AGENTS.md → Token budget](AGENTS.md#token-budget). Setup for the tool-output layer, once per machine:

- [`rtk`](https://github.com/rtk-ai/rtk): `mise use -g rtk`, then `rtk init -g --hook-only --auto-patch` (Claude Code), `rtk init -g --codex`, `rtk init -g --agent cursor`, or `rtk init -g --gemini`.
- `caveman` is vendored in `.agents/skills/caveman`; `/caveman lite` or `/caveman off` changes its level.

## Workflow

The agent chain is in [AGENTS.md → Workflow](AGENTS.md#workflow). The tracks and the human checkpoint are in [docs/workflow.md](docs/workflow.md), and the step-by-step guide per scenario is [USAGE.md](USAGE.md).

## Layout

- `AGENTS.md`: agent instructions, kept short; `CLAUDE.md` imports it ([rule](docs/CODING_STANDARDS.md#agent-instructions)).
- `SPEC.md`: product-level scope.
- `docs/`: coding standards ([`CODING_STANDARDS.md`](docs/CODING_STANDARDS.md), [`standards/`](docs/standards/)), workflow tracks, and [`agents/`](docs/agents/) for the issue tracker and model assignment.
- `.agents/skills/`: skills in the open `SKILL.md` format; `.claude/skills` is a symlink to it.
- `.claude/agents/`, `.claude/hooks/`: reviewer agents and the read-only Bash guard they share.
- `templates/go`, `templates/python`, `templates/release/`: per-language project files and release workflows.
- `scripts/`, `justfile`, `mise.toml`: the gates behind `just check`, and the tools they pin.
- `.github/`: PR template, CI, security workflow and rulesets.
- `lefthook.yml`: local pre-commit and pre-push hooks.

## Security and dependency checks

The list is in [CODING_STANDARDS → Security and dependency checks](docs/CODING_STANDARDS.md#security-and-dependency-checks).

## Skills

Vendored copies are listed with their source commits in `.agents/skills/VENDORED.md`. Local changes to vendored skills are listed there too, so they survive an upstream refresh.
