---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

1. **Restate** the acceptance criteria as a numbered list, each one concrete and observable (example input → output). Anything the spec leaves open becomes `ASSUMP-#`: keep them few, and each ends up backed by a test or marked `TODO(ASSUMP-#)` at the seam in code.
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
   - Push, then `gh pr create` with a Conventional Commit title and the body from the `pr` skill, evidence table included.
   - `gh pr checks --watch`; on a red check, read the log (`gh run view --log-failed`), fix, push, repeat until green.
   - Done when CI is green: report the PR URL. The user reviews and merges.
