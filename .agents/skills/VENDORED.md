# Vendored skills

Copied as editable files. Refresh by re-copying from upstream, then re-applying the local changes listed below.

## mattpocock/skills (MIT, `LICENSE-mattpocock`)

Commit `d81f3a183412e71a5b1e84ca21bc1a35eea03a60` (2026-09-29).

grilling, domain-modeling, grill-with-docs, setup-matt-pocock-skills, to-spec, to-tickets, implement, tdd, codebase-design, code-review, pr, diagnosing-bugs, improve-codebase-architecture, handoff, writing-for-agents

Local changes:

- `implement`: acceptance-criteria restatement, `ASSUMP-#`, pre-mortem, criteria → test evidence table, `just check` gate, review against `main`; ships as a PR that is squash-merged (branch commits free-form).
- `pr`: squash-merge framing (title = commit subject, body = commit message), Conventional Commit title, `Changes` bullet section, evidence table, `Closes #`.
- `setup-matt-pocock-skills`: writes the Agent skills block to `AGENTS.md` (`CLAUDE.md` only imports it).
- `to-spec`, `to-tickets`: apply `ready-for-agent` only when `docs/agents/triage-labels.md` exists.
- `code-review`: standards sources include `docs/standards/` and ADRs; findings carry severity and a Security line; sub-agent briefs ask for findings only instead of a word cap.

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
