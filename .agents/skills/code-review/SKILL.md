---
name: code-review
description: "Review the changes since a fixed point along two axes, Standards (the repo's coding standards) and Spec (the originating issue), as parallel named agents. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to \"review since X\"."

---

Two-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards**: does the code conform to this repo's documented coding standards?
- **Spec**: does the code faithfully implement the originating issue / spec?

Both axes run as **named, parallel agents** so they don't pollute each other's context, then this skill aggregates their findings:

- `standards-reviewer` (`.claude/agents/standards-reviewer.md`): Sonnet; carries the Standards brief and the smell baseline.
- `spec-reviewer` (`.claude/agents/spec-reviewer.md`): Opus, read-only, no project instructions. It sees only the fixed point and the spec reference, and fetches the spec and diff itself, so the review is independent of the session that wrote the code.

Both are read-only and have neither the Agent nor the Skill tool. Never invoke `/code-review` from inside this skill or its agents.

The issue tracker should have been provided to you. If `docs/agents/issue-tracker.md` is missing, tell the user to write it first.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point (a commit SHA, branch name, tag, `main`, `HEAD~5`, etc.). If they didn't specify one, ask for it.

Confirm it resolves (`git rev-parse <fixed-point>`) and that `git diff <fixed-point>...HEAD` (three-dot, against the merge-base) is non-empty. A bad ref or empty diff should fail here, not inside two parallel agents.

### 2. Identify the spec reference

Find a reference, not the contents; the Spec agent fetches the spec itself. In this order:

1. Issue references in the commit messages or branch name (`#123`, `Closes #45`, `feat/42-…`).
2. A path the user passed as an argument.
3. A spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name or feature.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, skip the Spec agent and report "no spec available".

### 3. Identify the standards sources

Anything in the repo that documents how code should be written: `docs/CODING_STANDARDS.md`, the language files under `docs/standards/`, `CONTRIBUTING.md`, and ADRs in `docs/adr/` that touch the changed area. The `standards-reviewer` agent already carries the brief and the smell baseline; pass it only the file list.

### 4. Check independence

Run `scripts/check-independence.sh <fixed-point> opus` from this skill's directory. It reads the `Co-Authored-By` trailers on the branch commits and prints one line: `Spec review independent`, `Spec review not independent` (the implementer is the spec reviewer's model, `opus`) or `Implementer model unknown`. Put that line at the top of the report.

### 5. Invoke both agents in parallel

Send both calls in one message, by name:

- `standards-reviewer` with: `Fixed point: <fixed-point>. Standards files: <list from step 3>.`
- `spec-reviewer` with exactly: `Fixed point: <fixed-point>. Spec: <reference from step 2>.`

The Spec prompt carries nothing else: no transcript, no `ASSUMP-#` list, no PR description, no summary of the change or of what you think it does. Anything more re-couples the review to the session that wrote the code.

An agent without named-agent support (e.g. Codex) spawns two generic sub-agents instead, each given the body of its agent file followed by the same one-line prompt.

### 6. Aggregate

Start with the independence line from step 4. Then present the two reports under `## Standards` and `## Spec` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings, because the two axes are deliberately separate (see _Why two axes_).

End with a one-line summary: total findings per axis, and the worst issue _within each axis_ (if any). Don't pick a single winner across axes: that's the reranking the separation exists to prevent.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.
