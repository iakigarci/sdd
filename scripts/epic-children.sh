#!/usr/bin/env bash
# Lists the closed child issues (native sub-issues) of an epic, with the PR and
# squash commit that closed each, one "<child>\t<pr>\t<merge-sha>" line per PR.
# Refuses, listing them, while any child is still open. Used by /close-epic.
#   epic-children.sh <parent-issue>
set -euo pipefail

parent=${1:?usage: $0 <parent-issue>}
[[ $parent =~ ^[0-9]+$ ]] || { echo "✗ parent must be an issue number, got '$parent'" >&2; exit 2; }
repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
subs="repos/$repo/issues/$parent/sub_issues"

children=$(gh api "$subs" --paginate --jq '.[] | "\(.number)\t\(.state)\t\(.title)"')
if [[ -z $children ]]; then
  echo "✗ #$parent has no child issues (sub-issues)." >&2
  exit 1
fi

open_children=$(awk -F'\t' '$2 == "open" {printf "  #%s %s\n", $1, $3}' <<<"$children")
if [[ -n $open_children ]]; then
  echo "✗ #$parent has open child issues; close them first:" >&2
  echo "$open_children" >&2
  exit 1
fi

while IFS=$'\t' read -r child _ _; do
  prs=$(gh issue view "$child" --json closedByPullRequestsReferences \
    --jq '.closedByPullRequestsReferences[].number')
  # A child closed by hand has no squash commit to review; say so, don't skip it.
  [[ -n $prs ]] || echo "! #$child has no closing PR: its change is not in the epic diff" >&2
  while read -r pr; do
    [[ -n $pr ]] || continue
    sha=$(gh pr view "$pr" --json mergeCommit,mergedAt --jq 'select(.mergedAt != null) | .mergeCommit.oid')
    # A closing PR that was never merged has no squash commit to review.
    [[ -n $sha ]] || { echo "! #$child is closed by unmerged PR #$pr: skipped" >&2; continue; }
    printf '%s\t%s\t%s\n' "$child" "$pr" "$sha"
  done <<<"$prs"
done <<<"$children"
