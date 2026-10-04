---
name: close-epic
description: "Finish an epic (a parent issue with child issues): an independent spec review over the combined diff of its children, permanent decisions written back, and the parent closed with a summary. Refuses while any child issue is still open."
disable-model-invocation: true
---

Run under `/model opus`: the write-back step is judgement, and the skill stops for your confirmation. Switch back with `/model sonnet` afterwards (`docs/agents/models.md`).

The argument is the parent issue number. Use `gh` for every issue operation (`docs/agents/issue-tracker.md`).

## Process

### 1. Gate and collect

Run `scripts/epic-children.sh <n>`. It exits non-zero and lists the open children when any child is still open: stop there and report that list. Otherwise it prints one `<child>\t<pr>\t<merge-sha>` line per closed child's PR.

Order the merge SHAs by commit time (`git log --no-walk --date-order <shas>`). The oldest one's parent is the fixed point; the newest one is the end of the epic.

### 2. Pin the range

The spec reviewer diffs `<fixed point>...HEAD`, so HEAD must be the newest merge SHA and nothing after it. Confirm `git status --porcelain` is empty, then `git switch --detach <newest-sha>`. Never stash or discard someone's changes to do this.

### 3. Spec review

Run the `spec-reviewer` agent with the fixed point and `#<n>` only. It is Opus and independent of this session. Keep its three sections for the close summary. If it reports an unmet requirement, ask whether to fix it now or file a follow-up issue before closing.

### 4. Write back permanent decisions

Collect every `ASSUMP-#` from the children's PR bodies (their Evidence tables). Mark each one permanent (still true after the epic) or temporary (tied to one ticket or since superseded). Show the permanent list and ask for confirmation before writing anything.

- Architectural choices go to a new ADR in `docs/adr/`. Mark any ADR they supersede with `Superseded by ADR-NNNN` in its status line.
- Domain terms go to `GLOSSARY.md`.
- Both are repo changes: put them on a `docs/<n>-close-epic` branch and open a PR through the normal flow. Close the parent only after that PR merges. If nothing is permanent, skip this step.

### 5. Close with a summary

Draft the comment, show it, and post it on your confirmation:

- **Shipped**: each child issue, with its PR.
- **Open findings**: the spec review's unmet requirements and anything you chose to leave open.
- **Follow-up issues**: the issues created from those findings.
- **Permanent decisions**: links to the ADRs and glossary entries from step 4.

Then `gh issue close <n> --comment "<summary>"`.
