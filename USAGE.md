# Usage

What to type, in order, for each kind of change. Every scenario is built from the same five procedures (P1–P5); pick your scenario in [Scenarios](#scenarios) and follow the procedures it lists.

The rules behind the steps live in `docs/workflow.md` (tracks, human checkpoint) and `docs/agents/models.md` (which model runs what). This file only says what to do.

## One-time setup

Per machine:

1. Install [`mise`](https://mise.jdx.dev) and the [`gh`](https://cli.github.com) CLI, then `gh auth login`.
2. Optional, for fewer tokens: `mise use -g rtk`, then `rtk init -g --hook-only --auto-patch`.

Per clone:

1. `mise install`, then `lefthook install` (pre-commit format/lint, pre-push `just check`).
2. Once per repo, create the approval label if it does not exist yet:

   ```bash
   gh label create ready-for-agent --color 0e8a16 --description "A person read this ticket and approved it for /implement"
   ```

## Procedures

### P1. Write the ticket

Turns an idea or a bug report into a GitHub issue.

| Situation | Do |
|---|---|
| The idea is unclear, or it touches the design, domain terms or `SPEC.md` | `/model opus`, `/grill-with-docs`, then `/to-spec`. ADRs and `GLOSSARY.md` are written as decisions land. |
| The idea is clear | `/to-spec` straight away, describing the change in the same prompt. |
| A trivial fix or chore, cause and change already known | `gh issue create`, with the symptom, the expected behaviour and acceptance criteria. |

The issue is the spec. `/to-spec` does not label it; that is P2.

### P2. Approve the ticket (human checkpoint)

The checkpoint rule is in [workflow.md](docs/workflow.md#human-checkpoint). Here is the step:

1. Read the issue on GitHub: acceptance criteria, out of scope, threat section if present.
2. Fix anything wrong by editing the issue, or ask the agent to rewrite it.
3. `gh issue edit <n> --add-label ready-for-agent`

Without the label, `/implement` refuses ([checkpoint](docs/workflow.md#human-checkpoint)).

### P3. Ship one ticket

1. Start clean: `/clear` (or a new session), then `git switch main && git pull`.
2. Pick the model for the ticket as [models.md](docs/agents/models.md) says; `/implement` stops and asks for Opus when a ticket needs it.
3. `/implement #<n>`. It branches, restates the criteria and `ASSUMP-#`, builds test-first, runs `just check`, runs `/code-review` (and `/security-review` when the diff is sensitive), opens the PR and watches CI until green.
4. Answer it if it pauses (a test seam crossing a public API or the database, an escalation).
5. Review the PR on GitHub: the Evidence table and Merge Danger, laid out as in the [pr skill template](.agents/skills/pr/SKILL.md). Ask for changes in the session or in PR comments.
6. Squash-merge on GitHub; the merge is yours ([guard rails](docs/CODING_STANDARDS.md#branches-and-pull-requests)).
7. Optional, for workflow metrics: `scripts/pr-metrics.sh <pr> --post`.

### P4. Diagnose

For a bug whose cause is not obvious, or a performance regression.

1. `/model opus`, then `/diagnosing-bugs` with the symptom and how to reproduce it.
2. It builds a failing reproduction, ranks hypotheses (check its list: you may know which to drop) and pins the cause.
3. Turn the outcome into a ticket (P1, usually `gh issue create` with the root cause and the failing test as acceptance criteria), then `/model sonnet`.

### P5. Close an epic

After every child ticket of a parent issue is merged.

1. `/model opus`, then `/close-epic <parent>`.
2. It refuses while any child is open, then runs an independent spec review over the whole epic, writes lasting decisions back (issue, ADR, `GLOSSARY.md`) after asking you, and closes the parent with a summary.
3. `/model sonnet`.

## Scenarios

| Scenario | Steps |
|---|---|
| Small fix, cause known | P1 (`gh issue create`) → P2 → P3 |
| Bug, cause unknown | P4 → P2 → P3 |
| Small feature | P1 → P2 → P3 |
| List of fixes | [Batches](#batches-a-list-of-fixes-or-features) |
| List of features | [Batches](#batches-a-list-of-fixes-or-features) |
| Big feature | [Big feature](#big-feature) |
| Hotfix | [Hotfix](#hotfix) |
| Refactor | `/model opus`, `/improve-codebase-architecture` → pick a candidate → treat it as a small or big feature |
| Docs, CI or chore | Same as a small fix; the PR title type is `docs:`, `ci:` or `chore:` |

A small change is one that fits a single PR a reviewer can hold in their head (size rule: [CODING_STANDARDS](docs/CODING_STANDARDS.md#branches-and-pull-requests)). Anything larger is a big feature.

### Batches: a list of fixes or features

Independent items that do not belong to one feature.

1. P1 for each item: one issue per logical change. Fixes that share a cause become one issue.
2. P2 for each issue. Approve only what you want built now.
3. Ship them with P3, one at a time, or in parallel (below) when they touch separate areas.

If the items depend on each other, they are a big feature, not a batch.

### Big feature

1. `/model opus`, `/grill-with-docs`, then `/to-spec`: this issue is the parent (the feature spec).
2. State how it ships in the parent issue ([workflow.md → Big feature](docs/workflow.md#big-feature)).
3. `/to-tickets #<parent>` (still on Opus). Iterate on the breakdown until it is right; it publishes child issues with blocked-by links.
4. P2 for each child you approve. Read the parent and every child before any code is written.
5. `/model sonnet`. P3 for each unblocked child, in parallel when they touch separate areas. Pull `main` after each merge; newly unblocked children become available.
6. P5 on the parent.
7. If you held the release PR, merge it now.

Context running out partway through a ticket: `/handoff`, then continue from the handoff document in a fresh session.

### Hotfix

Production is broken.

1. If a recent PR caused it, revert it first ([workflow.md → Hotfix](docs/workflow.md#hotfix)): `gh pr view <culprit>` for the merge commit, `git revert <sha>` on a `fix/<issue>-revert-<slug>` branch, PR titled `fix: revert …`, merge, release.
2. P4 to find the real cause (skip when the cause is obvious).
3. P1 (`gh issue create`) → P2 → P3 for the forward fix: smallest change, PR titled `fix: …`. Refactors go in a separate issue.
4. Merge the release PR that release-please opens (a `fix:` makes a patch release).
5. Confirm the symptom is gone in logs or metrics: [workflow.md → Hotfix](docs/workflow.md#hotfix).

## Running tickets in parallel

For 2–3 unblocked tickets that touch separate areas.

1. `git switch main && git pull` in the main checkout.
2. One terminal per ticket: `claude -w t<n>` (add `--tmux` for panes), then `/implement #<n>` in each.
3. Merge in the order [workflow.md → Parallel tickets](docs/workflow.md#parallel-tickets) gives.

## What the guard rails do

You will see these; they are working as intended. Each one's rule and where it is set: [CODING_STANDARDS → Branches and pull requests](docs/CODING_STANDARDS.md#branches-and-pull-requests), `.claude/settings.json`, `lefthook.yml`.

## Cheat sheet

| Command | When |
|---|---|
| `/grill-with-docs` | Unclear idea, design or domain question |
| `/to-spec` | Turn the conversation into an issue |
| `/to-tickets #<n>` | Break a big feature into child issues |
| `/implement #<n>` | Ship one approved ticket |
| `/code-review <ref>` | Review any branch by hand; `/implement` already runs it |
| `/diagnosing-bugs` | Bug with unknown cause, perf regression |
| `/close-epic <n>` | All children of a parent are merged |
| `/improve-codebase-architecture` | Every few days |
| `/handoff` | Continue in a fresh session |

The model each command runs on is in [docs/agents/models.md](docs/agents/models.md); this guide does not repeat that table.
