# Vendored skills

Copied as editable files. Refresh by re-copying from upstream, then re-applying the local changes listed below.

## mattpocock/skills (MIT, `LICENSE-mattpocock`)

Commit `d81f3a183412e71a5b1e84ca21bc1a35eea03a60` (2026-09-29).

Local changes by skill:

- `implement`: ticket gate on `ready-for-agent`; restates criteria; `ASSUMP-#` beside test seams (pause only at public API or persistence boundaries); pre-mortem drawing security failures from the Threat Model; `/security-review` pass (language security skill as fallback, manual for Python) with unfixed findings in Merge Danger; criteria → test evidence table; `just check` gate; review against `main`; pins no model and names `/model opus` escalation; ships as a squash-merged PR and passes the issue and evidence to the `pr` fork.
- `pr`: `Review findings` evidence line (`scripts/pr-metrics.sh` reads it); squash-merge framing, Conventional Commit title, `Changes` bullets and evidence table; the body opens with `Closes #` as its first line, then `Part of #`; runs as a fork with `model: haiku`, takes inputs from `$ARGUMENTS` and returns text. Its body template is the one PR template ([`pr/SKILL.md`](pr/SKILL.md)); `/implement`, `docs/agents/models.md` and `USAGE.md` link to it.
- `to-spec`: never applies `ready-for-agent`; Threat Model section in the template; `model: inherit`; description trimmed (always-loaded context).
- `to-tickets`: never applies `ready-for-agent`; opens with "Run under `/model opus`"; description trimmed (always-loaded context).
- `code-review`: standards sources include `docs/standards/` and ADRs; severity and Security line; findings-only sub-agent briefs (no word cap); both axes as named agents in `.claude/agents/` (Spec reviewer read-only via `review-bash-guard.sh`, no project instructions, given only the fixed point and spec reference), checked by `scripts/check-independence.sh`; generic sub-agents as fallback; description trimmed (always-loaded context).
- `handoff`: pins `model: sonnet`.
- `grill-with-docs`, `diagnosing-bugs`, `improve-codebase-architecture`: open with "Run under `/model opus`". `diagnosing-bugs` also has its description trimmed (always-loaded context). `improve-codebase-architecture` takes its vocabulary from `codebase-design` (link in the intro), links the deletion test to `codebase-design`, and offers ADRs through `domain-modeling` (the ADR offer moved out of the skill).
- `grilling`, `codebase-design`: description trimmed (always-loaded context); no other local changes.
- `domain-modeling`: ADR offer condition 4, "Not ephemeral" (the reason is more than "not worth it right now" or self-evident), in "Offer ADRs sparingly".
- `tdd`, `writing-for-agents`: no local changes.

grilling, domain-modeling, grill-with-docs, to-spec, to-tickets, implement, tdd, codebase-design, code-review, pr, diagnosing-bugs, improve-codebase-architecture, handoff, writing-for-agents

## samber/cc-skills-golang (MIT, `LICENSE-samber`)

Commit `19a0626` (2026-09-07). `evals/` folders dropped.

Local changes: every `description` shortened to one line (token budget: ~2.3k fewer always-loaded tokens); cross-reference bullets to skills that are not vendored removed (inline mentions remain); `golang-project-layout` defers architecture and DI to `docs/standards/go.md` instead of asking.

golang-code-style, golang-grpc, golang-naming, golang-error-handling, golang-concurrency, golang-context, golang-testing, golang-lint, golang-continuous-integration, golang-project-layout, golang-security, golang-safety, golang-observability, golang-database, golang-performance, golang-dependency-management, golang-modernize, golang-design-patterns, golang-structs-interfaces, golang-documentation

## trailofbits/skills (CC BY-SA 4.0, `LICENSE-trailofbits`)

Commit `82fe822` (2026-09-28).

modern-python

Local changes: description trimmed (always-loaded context); the change is covered by CC BY-SA 4.0.

## JuliusBrussee/caveman (MIT for `skills/`, `LICENSE-caveman`)

Commit `2fd153c` (2026-09-22). Only `skills/caveman`; the BSL-licensed engine/proxy is not vendored.

caveman

Local changes: the tool-call rule allows one short progress line on multi-step work; description shortened to one line (always-loaded context).

## Own

project-init
