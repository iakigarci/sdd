#!/usr/bin/env bash
# Rules that hooks, rulesets or CI enforce are not restated in prose:
# AGENTS.md (loaded every turn) leaves them out, and the coding standards point
# to the enforcing tool.
#   scripts/enforced-rules_test.sh
set -uo pipefail

root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
agents="$root/AGENTS.md"
standards="$root/docs/CODING_STANDARDS.md"
fail=0

# AGENTS.md: force-push and merge (guard hook, ruleset), title format
# (pr-title), branch format (branch-name), gate recipe detail (justfile).
for rule in 'force-push' 'force push' '--force' 'merg' 'conventional commit' \
  '<issue>-<slug>' 'just fmt' 'just lint' 'just test'; do
  grep -qiF -- "$rule" "$agents" && { echo "✗ AGENTS.md restates an enforced rule: '$rule'"; fail=1; }
done

# CODING_STANDARDS.md: no copy of the title check's type list or length limit.
grep -qE 'feat.*fix.*perf.*refactor' "$standards" &&
  { echo "✗ CODING_STANDARDS.md restates the PR title types"; fail=1; }
grep -qE '\b72\b' "$standards" &&
  { echo "✗ CODING_STANDARDS.md restates the PR title length"; fail=1; }

# It names the tool that enforces each rule instead.
for tool in scripts/check-pr-title.sh scripts/check-branch-name.sh scripts/check-pr-size.sh \
  .claude/settings.json .github/rulesets/main.json; do
  grep -qF "\`$tool\`" "$standards" || { echo "✗ CODING_STANDARDS.md does not point to $tool"; fail=1; }
done

"$root/scripts/check-agents-md.sh" >/dev/null || { echo "✗ AGENTS.md size gate fails"; fail=1; }

((fail)) && exit 1
echo "enforced-rules: all checks pass"
