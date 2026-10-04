---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

**Escalate** a hard ticket to Opus: stop and ask the user to rerun `/implement` under `/model opus` when the restated criteria need more than three `ASSUMP-#`, the change touches concurrency, auth, crypto or a data migration, or the same test stays red after two root-cause attempts. This skill pins no model, so the escalation covers the whole turn (`docs/agents/models.md`); say in the PR's Merge Danger that the Spec review then shares the implementer's model.

0. **Gate**: read the ticket's labels (`gh issue view <n> --json labels`). Without `ready-for-agent`, refuse: stop and say: "Ticket #<n> has no `ready-for-agent` label, so a person has not approved it for implementation. Add the label after reading it, then rerun `/implement`." Do not start the work. (`docs/workflow.md`, Human checkpoint.)
1. **Restate** the acceptance criteria as a numbered list, each one concrete and observable (example input → output). Anything the spec leaves open becomes `ASSUMP-#`: keep them few, and each ends up backed by a test or marked `TODO(ASSUMP-#)` at the seam in code. Beside each `ASSUMP-#`, list the test seam it goes through (the function, handler or interface a test enters by). Pause for the user only when a seam crosses a public API or persistence boundary; otherwise go on.
2. **Check necessity**: where existing code already meets a criterion, say so and limit that criterion to tests or docs.
3. **Pre-mortem**: at most three ways this change fails in production, security and privacy included where relevant; when the spec has a Threat Model section, draw the security failures from its threats first. Each becomes a test or a line in the PR's Merge Danger.
4. **Build** with /tdd where possible, at pre-agreed seams. Run `just lint` and single test files regularly, and `just check` once at the end.
5. **Verify**: done means `just check` passed in this session and every criterion and `ASSUMP-#` maps to a passing test. Record the mapping, which becomes the PR's Evidence:

   | Criterion | Test | Result |
   |---|---|---|
   | 1 | `TestX_HappyPath` | pass |
   | ASSUMP-1 | `TestX_EmptyInput` | pass |

   A check you could not run is marked SIMULATED with the reason. When a check failed along the way, add a one-line root cause and fix.
6. **Review**: use /code-review against `main`. When the diff touches auth, input parsing, serialization, SQL or exec calls, secrets, file paths or network calls, also run `/security-review`; agents without that command run the language security skill in review mode instead (`golang-security` for Go; for Python, which has no vendored security skill, a manual pass over those same areas). Fix the actionable findings; each security finding left unfixed goes into the PR's Merge Danger. Rerun `just check`.
7. **Ship as a PR**, following `AGENTS.md` → Git and pull requests:
   - Work on a `<type>/<issue>-<slug>` branch (create it from `main` first when you are on `main`).
   - Commit as often as useful; the PR is squash-merged into one commit.
   - Push, then `gh pr create` with the title and body the `pr` skill returns. It runs as a fork that sees none of this conversation: give it the issue number, the evidence table and any Merge Danger notes as its arguments.
   - `gh pr checks --watch`; on a red check, read the log (`gh run view --log-failed`), fix, push, repeat until green.
   - Done when CI is green: report the PR URL. The user reviews and merges.
