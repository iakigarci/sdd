# Vendored skills

Copied as editable files. Refresh by re-copying from upstream, then re-applying the local changes listed below.

## mattpocock/skills (MIT, `LICENSE-mattpocock`)

Commit `d81f3a183412e71a5b1e84ca21bc1a35eea03a60` (2026-09-29).

Local changes, one line per skill:

- `implement`: ticket gate on `ready-for-agent`, `ASSUMP-#` beside test seams, pre-mortem drawing security failures from the Threat Model, `/security-review` pass with unfixed findings in Merge Danger, criteria → test evidence, pins no model and names `/model opus` escalation, ships as a PR via the `pr` fork.
- `pr`: `Review findings` evidence line, squash-merge framing, the body opens with `Closes #` as its first line, then `Part of #`; runs as a fork with `model: haiku`.
- `to-spec`: never applies `ready-for-agent`; Threat Model section in the template; `model: inherit`.
- `to-tickets`: never applies `ready-for-agent`; opens with "Run under `/model opus`".
- `code-review`: standards sources include `docs/standards/` and ADRs; severity and Security line; both axes as named agents in `.claude/agents/`, checked by `scripts/check-independence.sh`.
- `handoff`: pins `model: sonnet`.
- `grill-with-docs`, `diagnosing-bugs`, `improve-codebase-architecture`: open with "Run under `/model opus`".
- `grilling`, `domain-modeling`, `tdd`, `codebase-design`, `writing-for-agents`: no local changes.

grilling, domain-modeling, grill-with-docs, to-spec, to-tickets, implement, tdd, codebase-design, code-review, pr, diagnosing-bugs, improve-codebase-architecture, handoff, writing-for-agents

## samber/cc-skills-golang (MIT, `LICENSE-samber`)

Commit `19a0626` (2026-09-07). `evals/` folders dropped.

Local changes: every `description` shortened to one line (token budget: ~2.3k fewer always-loaded tokens); cross-reference bullets to skills that are not vendored removed (inline mentions remain); `golang-project-layout` defers architecture and DI to `docs/standards/go.md` instead of asking.

golang-code-style, golang-grpc, golang-naming, golang-error-handling, golang-concurrency, golang-context, golang-testing, golang-lint, golang-continuous-integration, golang-project-layout, golang-security, golang-safety, golang-observability, golang-database, golang-performance, golang-dependency-management, golang-modernize, golang-design-patterns, golang-structs-interfaces, golang-documentation

## trailofbits/skills (CC BY-SA 4.0, `LICENSE-trailofbits`)

Commit `82fe822` (2026-09-28).

modern-python

## JuliusBrussee/caveman (MIT for `skills/`, `LICENSE-caveman`)

Commit `2fd153c` (2026-09-22). Only `skills/caveman`; the BSL-licensed engine/proxy is not vendored.

caveman

Local changes: the tool-call rule allows one short progress line on multi-step work.

## Own

project-init
