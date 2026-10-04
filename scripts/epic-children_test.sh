#!/usr/bin/env bash
# Tests for epic-children.sh with a stub gh on PATH.
#   scripts/epic-children_test.sh
set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd)/epic-children.sh"
fail=0
stub=$(mktemp -d)
trap 'rm -rf "$stub"' EXIT

# Stub: answers the four gh calls the script makes from FAKE_* fixtures.
cat >"$stub/gh" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  "repo view"*) echo "acme/sdd" ;;
  *"/sub_issues"*) jq -r "${@: -1}" <<<"$FAKE_SUBS" ;;
  "issue view"*) jq -r "${@: -1}" <<<"$FAKE_ISSUE_PRS" ;;
  "pr view"*) echo "$FAKE_MERGE_SHA" ;;
  *) echo "unexpected gh call: $*" >&2; exit 2 ;;
esac
STUB
chmod +x "$stub/gh"
export PATH="$stub:$PATH"

# expect <want: pass|fail> <name> <subs-json> [stdout must contain]
expect() {
  local want=$1 name=$2 subs=$3 must=${4:-} out got=pass
  export FAKE_SUBS=$subs FAKE_ISSUE_PRS='{"closedByPullRequestsReferences":[{"number":21}]}' FAKE_MERGE_SHA=abc123
  out=$("$script" 20 2>&1) || got=fail
  [[ $got == "$want" ]] || { echo "✗ $name: want $want, got $got: $out"; fail=1; }
  [[ -z $must || $out == *"$must"* ]] || { echo "✗ $name: output lacks '$must': $out"; fail=1; }
}

closed='[{"number":14,"state":"closed","title":"a"},{"number":19,"state":"closed","title":"b"}]'
expect pass "all children closed" "$closed" "abc123"
export FAKE_SUBS=$closed FAKE_ISSUE_PRS='{"closedByPullRequestsReferences":[{"number":21}]}' FAKE_MERGE_SHA=abc123
exact=$(printf '14\t21\tabc123\n19\t21\tabc123')
[[ $("$script" 20 2>/dev/null) == "$exact" ]] || { echo "✗ all children closed: lines differ from one per child"; fail=1; }

# A closing PR that was never merged yields no line, with a warning.
export FAKE_SUBS='[{"number":14,"state":"closed","title":"a"}]' FAKE_ISSUE_PRS='{"closedByPullRequestsReferences":[{"number":21}]}' FAKE_MERGE_SHA=''
out=$("$script" 20 2>&1)
[[ $out == *"#14 is closed by unmerged PR #21"* && $out != *$'14\t'* ]] || { echo "✗ unmerged PR: $out"; fail=1; }
# A child with no closing PR warns, and gets no line.
no_pr='[{"number":14,"state":"closed","title":"a"}]'
export FAKE_ISSUE_PRS='{"closedByPullRequestsReferences":[]}'
out=$(FAKE_SUBS=$no_pr FAKE_MERGE_SHA=x "$script" 20 2>&1)
[[ $out == *"#14 has no closing PR"* ]] || { echo "✗ no closing PR: no warning: $out"; fail=1; }
[[ $out != *$'14\t'* ]] || { echo "✗ no closing PR: emitted a line for #14: $out"; fail=1; }

# A parent that is not a plain number never reaches the API path.
out=$(FAKE_SUBS=$closed "$script" "20/../x" 2>&1) && { echo "✗ path in parent accepted: $out"; fail=1; }

expect fail "no children" "[]" "no child issues"
expect fail "two children open" '[{"number":14,"state":"open","title":"First"},{"number":19,"state":"open","title":"Second"},{"number":20,"state":"closed","title":"Done"}]' "#14 First"
expect fail "one child open" '[{"number":14,"state":"closed","title":"a"},{"number":19,"state":"open","title":"Refuse me"}]' "#19 Refuse me"

((fail)) && exit 1
echo "epic-children: all checks pass"
