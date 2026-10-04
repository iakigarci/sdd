#!/usr/bin/env bash
# Tests for pr-metrics.sh. A stub `gh` answers from fixtures and a throwaway
# git repo stands in for main, so no network is used.
#   scripts/pr-metrics_test.sh
set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd)/pr-metrics.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fx="$work/fixtures"
mkdir -p "$fx" "$work/bin"
fail=0

# Stub gh: `pr view N`, `api …/commits/SHA/check-runs`, `issue list`,
# `issue view N` read fixtures and apply --jq like the real CLI; `issue
# comment N` records its stdin as posted-N.md.
cat >"$work/bin/gh" <<'STUB'
#!/usr/bin/env bash
fx=$GH_FIXTURES
case "$1 $2" in
  "pr view") f=$fx/pr-$3.json ;;
  "api "*) sha=$(sed -E 's#.*/commits/([^/]+)/check-runs#\1#' <<<"$2"); f=$fx/checks-$sha.json ;;
  "issue list") f=$fx/issues.json ;;
  "issue view") f=$fx/issue-$3.json ;;
  "issue comment") cat >"$fx/posted-$3.md"; exit 0 ;;
  *) echo "stub gh: unexpected call: $*" >&2; exit 2 ;;
esac
filter=
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do [[ ${args[i]} == --jq ]] && filter=${args[i + 1]}; done
if [[ -n $filter ]]; then jq -r "$filter" "$f"; else cat "$f"; fi
STUB
chmod +x "$work/bin/gh"

export PATH="$work/bin:$PATH" GH_FIXTURES="$fx" PR_METRICS_BASE=main

# A throwaway main with a culprit PR (#41), its revert, and an unrelated commit.
repo="$work/repo"
mkdir "$repo" && cd "$repo" || exit 1
git init -q -b main
git config user.name test && git config user.email test@example.invalid
git commit -q --allow-empty -m "feat: widget export (#41)"
git commit -q --allow-empty -m "fix: revert widget export (#44)" -m "Reverts #41 after a regression."
git commit -q --allow-empty -m "feat: unrelated (#4)"
git commit -q --allow-empty -m "feat: later change (#411)" -m "Mentions revert in passing."
git commit -q --allow-empty -m "fix: revert of #40 (#42)" -m "Reverts #40." # PR #40 is reverted; its own squash commit is excluded

pr_json() { # pr_json <number> <sha> <body>
  jq -n --arg b "$3" --arg s "$2" '{number: 0, state: "MERGED", body: $b, commits: [{oid: $s}]}' >"$fx/pr-$1.json"
}
checks() { # checks <sha> <conclusions...>
  local sha=$1; shift
  printf '%s\n' "$@" | jq -R -s '{check_runs: [split("\n")[] | select(length > 0) | {conclusion: .}]}' >"$fx/checks-$sha.json"
}

pr_json 40 aaa "$(printf 'Closes #21\n\n## Changes\n\nReview findings: 3 raised, 2 acted on')"
checks aaa success skipped
pr_json 41 bbb "$(printf 'Closes #22\n\n## Changes\n\nNo review line here')"
checks bbb success failure
pr_json 43 ccc "$(printf 'Part of #9\n\n## Changes')"
checks ccc success

expect_line() { # expect_line <want> <got-output> <label>
  grep -qxF -- "$1" <<<"$2" || { echo "✗ $3: missing line '$1'"; echo "$2" | sed 's/^/    /'; fail=1; }
}

# 1. Green first push, review line parsed, no revert.
out=$("$script" 40)
expect_line '<!-- sdd-metrics v1 -->' "$out" "PR 40 marker"
expect_line 'issue: 21' "$out" "PR 40 issue"
expect_line 'ci_first_push: y' "$out" "PR 40 CI"
expect_line 'findings_raised: 3' "$out" "PR 40 raised"
expect_line 'findings_acted_on: 2' "$out" "PR 40 acted"
expect_line 'reverts_or_hotfixes: 1' "$out" "PR 40 reverts (revert of #40 is on main)"

# 2. Failing check, no review line, culprit with a revert on main.
out=$("$script" 41)
expect_line 'issue: 22' "$out" "PR 41 issue"
expect_line 'ci_first_push: n' "$out" "PR 41 CI"
expect_line 'findings_raised: ' "$out" "PR 41 blank findings"
expect_line 'reverts_or_hotfixes: 1' "$out" "PR 41 counts the revert, not its own squash commit or #411"

# 3a. A non-numeric PR number is refused before it reaches git or gh.
if "$script" "41|x" >/dev/null 2>&1; then echo "✗ non-numeric PR: want refusal"; fail=1; fi

# 3. A PR whose body has no Closes line is refused.
if "$script" 43 >/dev/null 2>&1; then echo "✗ PR 43 without Closes: want failure"; fail=1; fi

# 4. --post comments the record on the issue named by Closes.
"$script" 40 --post >/dev/null || { echo "✗ --post failed"; fail=1; }
[[ -f $fx/posted-21.md ]] || { echo "✗ --post did not comment on issue 21"; fail=1; }
expect_line 'pr: 40' "$(cat "$fx/posted-21.md" 2>/dev/null)" "posted record"

# 5. Summary reads the last record per closed issue and proposes cuts.
jq -n '[{number: 21}, {number: 22}, {number: 30}]' >"$fx/issues.json"
rec() { printf '<!-- sdd-metrics v1 -->\npr: %s\nissue: %s\nci_first_push: %s\nfindings_raised: %s\nfindings_acted_on: %s\nreverts_or_hotfixes: %s\nreview_minutes: \ntokens_cost: \n' "$@"; }
jq -n --arg b "$(rec 1 21 y 5 0 0)" '{comments: [{body: "unrelated"}, {body: $b}]}' >"$fx/issue-21.json"
jq -n --arg b "$(rec 2 22 n 0 0 1)" '{comments: [{body: $b}]}' >"$fx/issue-22.json"
jq -n '{comments: [{body: "no record here"}]}' >"$fx/issue-30.json"
out=$("$script" --summary 10)
expect_line 'records: 2' "$out" "summary counts issues with records"
expect_line 'ci green on first push: 1 of 2 known' "$out" "summary CI"
expect_line 'review findings acted on: 0 of 5 raised' "$out" "summary findings"
expect_line 'records with a later revert or hotfix: 1' "$out" "summary reverts"
grep -q 'cut or narrow the review step' <<<"$out" || { echo "✗ summary: want review-step proposal at 0 of 5"; fail=1; }
grep -q 'thin sample' <<<"$out" || { echo "✗ summary: want thin-sample note under 20 records"; fail=1; }

((fail)) && exit 1
echo "pr-metrics: all checks pass"
