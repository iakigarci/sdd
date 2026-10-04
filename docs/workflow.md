# Workflow tracks

Every change reaches `main` as one squash-merged PR. Pick the track by size; the human checkpoint is the same on all three.

## Human checkpoint

Nothing is implemented until a person has read the ticket and added the `ready-for-agent` label to its GitHub issue. `/to-tickets` no longer applies the label on publish. `/implement` reads the label first and refuses a ticket without it, saying why, so the checkpoint is enforced rather than remembered.

## Small feature

One PR, one issue that fits a single context window.

1. `/grill-with-docs` only if the idea is still unclear.
2. `/to-spec`: the issue is both the spec and the ticket.
3. You read it and add `ready-for-agent`.
4. `/implement`, then `/code-review`, then the PR body from the `pr` skill.

## Big feature

Several tickets under one parent.

1. `/grill-with-docs`, then `/to-spec`: the parent issue is the feature spec.
2. `/to-tickets`: child issues are the tickets; you approve the breakdown.
3. The parent issue states how it ships: "behind a flag", or "hold the release PR until the last ticket lands".
4. You add `ready-for-agent` to each child you approve.
5. `/implement` each child. Unblocked tickets in separate areas may run in parallel (see below).

## Hotfix

For a production regression.

0. Revert the culprit PR first: a `fix: revert …` PR, merged before anything else.
1. Diagnose with `/diagnosing-bugs` (Opus).
2. Fix forward with `/implement` on its own ticket, with the usual checkpoint.
3. Release, then confirm the symptom is gone in logs or metrics. The last step is that check, not the merge.

## Parallel tickets

- Run 2 or 3 unblocked tickets at once, only when they touch separate areas.
- Each runs in its own worktree session, branched from a fresh `main`.
- Merge them one at a time. A branch that lands second merges `main` before its PR is ready.
- No stacked PRs: no branch is based on another open PR's branch.

## Specs

`SPEC.md` is the project constitution. It changes only through an approved `/grill-with-docs` outcome. Parent issue = feature spec; child issues = tickets.
