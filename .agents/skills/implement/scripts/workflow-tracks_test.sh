#!/usr/bin/env bash
# Checks docs/workflow.md (the three tracks and the human checkpoint), its
# one-line pointer from AGENTS.md, the SPEC.md constitution line, and that
# /implement gates on ready-for-agent and lists test seams beside ASSUMP-#.
#   .agents/skills/implement/scripts/workflow-tracks_test.sh
set -uo pipefail

root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
doc="$root/docs/workflow.md"
impl="$root/.agents/skills/implement/SKILL.md"
totickets="$root/.agents/skills/to-tickets/SKILL.md"
fail=0

# has <file> <fixed-string>: the file contains the text.
has() {
  grep -qF -- "$2" "$1" || { echo "✗ ${1#"$root"/}: missing '$2'"; fail=1; }
}

# 1. The doc covers the three tracks, in order.
if [[ -f $doc ]]; then
  for heading in '## Small feature' '## Big feature' '## Hotfix' '## Human checkpoint' '## Parallel tickets' '## Specs'; do
    has "$doc" "$heading"
  done
  # Big features ship behind a flag or hold the release PR.
  has "$doc" 'behind a flag'
  has "$doc" 'hold the release PR until the last ticket lands'
  # Hotfix: revert the culprit first, confirm the symptom after release.
  has "$doc" '`fix: revert …`'
  has "$doc" 'confirm the symptom is gone in logs or metrics'
  # Parallel tickets: worktrees from fresh main, one merge at a time, no stacks.
  has "$doc" 'worktree session'
  has "$doc" 'fresh `main`'
  has "$doc" 'one at a time'
  has "$doc" 'No stacked PRs'
  # The checkpoint is the label, and /implement refuses without it.
  has "$doc" '`ready-for-agent`'
  has "$doc" 'refuses a ticket without it'
else
  echo "✗ docs/workflow.md missing"; fail=1
fi

# 2. AGENTS.md points at the doc in one line.
refs=$(grep -c 'docs/workflow.md' "$root/AGENTS.md")
[[ $refs == 1 ]] || { echo "✗ AGENTS.md: $refs lines name docs/workflow.md, want 1"; fail=1; }

# 3. SPEC.md changes only through a grill outcome.
has "$root/SPEC.md" 'changes only through an approved `/grill-with-docs` outcome'

# 4. /implement refuses an unlabelled ticket and says why.
has "$impl" '`ready-for-agent`'
has "$impl" 'refuse:'
has "$impl" 'a person has not approved it'

# 5. /implement lists test seams beside ASSUMP-# and pauses only at boundaries.
has "$impl" 'list the test seam it goes through'
has "$impl" 'Pause for the user only when a seam crosses a public API or persistence boundary'

# 6. /to-tickets no longer applies the label on publish.
if grep -qE 'apply its `ready-for-agent`' "$totickets"; then
  echo "✗ to-tickets: still applies ready-for-agent on publish"; fail=1
fi
has "$totickets" 'Do not apply `ready-for-agent`'

# 7. AGENTS.md stays within its line gate.
"$root/scripts/check-agents-md.sh" 150 >/dev/null || { echo "✗ AGENTS.md over the line gate"; fail=1; }

((fail)) && exit 1
echo "workflow-tracks: all checks pass"
