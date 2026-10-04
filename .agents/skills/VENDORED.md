# Vendored skills

Copied as editable files. Refresh by re-copying from upstream, then re-applying the local changes listed below.

## mattpocock/skills (MIT, `LICENSE-mattpocock`)

Commit `d81f3a183412e71a5b1e84ca21bc1a35eea03a60` (2026-09-29).

grilling, domain-modeling, grill-with-docs, setup-matt-pocock-skills, to-spec, to-tickets, implement, tdd, codebase-design, code-review, pr, diagnosing-bugs, improve-codebase-architecture, handoff, writing-for-agents

Local changes:

- `implement`: a ticket gate on the `ready-for-agent` label, test seams listed beside `ASSUMP-#` (pause only at public API or persistence boundaries), acceptance-criteria restatement, `ASSUMP-#`, pre-mortem, criteria → test evidence table, `just check` gate, review against `main`; ships as a PR that is squash-merged (branch commits free-form); pre-mortem draws its security failures from the spec's Threat Model; review adds `/security-review` (language security skill as fallback, a manual pass for Python) when the diff touches a sensitive area, unfixed findings going into Merge Danger.
- `pr`: a `Review findings: <raised> raised, <acted on> acted on` line in the evidence (`scripts/pr-metrics.sh` reads it); squash-merge framing (title = commit subject, body = commit message), Conventional Commit title, `Changes` bullet section, evidence table; the body opens with `Closes #` as its first line, then `Part of #` for a parent issue.
- `setup-matt-pocock-skills`: writes the Agent skills block to `AGENTS.md` (`CLAUDE.md` only imports it).
- `to-spec`: never applies `ready-for-agent`; the user adds it after reading (`docs/workflow.md`).
- `to-tickets`: never applies `ready-for-agent`; the user adds it after reading (`docs/workflow.md`).
- `to-spec`: template gains a Threat Model section (trust boundaries, assets, one STRIDE pass).
- `code-review`: standards sources include `docs/standards/` and ADRs; findings carry severity and a Security line; sub-agent briefs ask for findings only instead of a word cap.
- `code-review`: both axes run as named agents in `.claude/agents/` (Sonnet `standards-reviewer` carrying the brief and smell baseline; Opus `spec-reviewer`, read-only through `.claude/hooks/review-bash-guard.sh`, no project instructions, given only the fixed point and spec reference); `scripts/check-independence.sh` flags "Spec review not independent" from the `Co-Authored-By` trailers; generic sub-agents remain the fallback for agents without named agents.
- Model assignment (`docs/agents/models.md`): `handoff` pins `model: sonnet` and `to-spec` `model: inherit`; `grill-with-docs`, `to-tickets`, `diagnosing-bugs`, `improve-codebase-architecture` open with "Run under `/model opus`"; `pr` runs as a forked agent (`context: fork`, `model: haiku`) that takes its inputs from `$ARGUMENTS` and returns text; `implement` pins no model, names when to escalate to `/model opus`, and passes the issue and evidence to the `pr` fork.

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
