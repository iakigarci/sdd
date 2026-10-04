#!/usr/bin/env bash
# Per-ticket workflow metrics: one record per merged PR (issue #21). Collects
# what GitHub and git already hold; manual fields are typed in on a terminal
# and left blank otherwise. The record is a comment on the closed issue in a
# fixed format, which --summary reads back to propose steps to cut.
#   scripts/pr-metrics.sh <pr> [--post]   print the record; --post comments it on the issue
#   scripts/pr-metrics.sh --summary [N]   summarise the last N closed issues (default 20)
set -euo pipefail

marker='<!-- sdd-metrics v1 -->'
base=${PR_METRICS_BASE:-main}
min_findings=5 # findings needed before the acted-on rate is judged
min_acted_pct=20 # below this, the review step is proposed for cutting

# collect <pr>: print the record for a merged PR.
collect() {
  local pr=$1 json body issue sha ci line nums raised= acted= reverts review_min= cost=
  json=$(gh pr view "$pr" --json number,body,commits,state)
  body=$(jq -r .body <<<"$json")

  issue=$(grep -m1 -oE '^Closes #[0-9]+' <<<"$body" | grep -oE '[0-9]+' || true)
  [[ -n $issue ]] || { echo "✗ PR #$pr: body has no 'Closes #<issue>' first line" >&2; return 1; }

  ci=unknown
  sha=$(jq -r '.commits[0].oid // empty' <<<"$json")
  if [[ -n $sha ]]; then
    ci=$(gh api "repos/:owner/:repo/commits/$sha/check-runs" --jq '
      if (.check_runs | length) == 0 then "unknown"
      elif all(.check_runs[]; .conclusion == "success" or .conclusion == "skipped" or .conclusion == "neutral") then "y"
      else "n" end')
  fi

  line=$(grep -m1 -oE 'Review findings: [0-9]+ raised, [0-9]+ acted on' <<<"$body" || true)
  if [[ -n $line ]]; then
    mapfile -t nums < <(grep -oE '[0-9]+' <<<"$line")
    raised=${nums[0]}
    acted=${nums[1]}
  fi

  # Commits on the base that revert or hotfix this PR. The PR's own squash
  # commit ends in "(#pr)" and is never counted, even when the PR is a revert.
  reverts=$(git log "$base" -i -E --all-match --grep='revert|hotfix' \
    --grep="#$pr([^0-9]|\$)" --format='%s' | grep -vcE "\(#$pr\)$" || true)

  if [[ -t 0 ]]; then
    read -r -p "review minutes (blank to skip): " review_min
    read -r -p "tokens/cost (blank to skip): " cost
  fi

  printf '%s\npr: %s\nissue: %s\nci_first_push: %s\nfindings_raised: %s\nfindings_acted_on: %s\nreverts_or_hotfixes: %s\nreview_minutes: %s\ntokens_cost: %s\n' \
    "$marker" "$pr" "$issue" "$ci" "$raised" "$acted" "$reverts" "$review_min" "$cost"
}

# field <key> <record>: the value of one `key: value` line.
field() { awk -v k="$1" -F': ' '$1 == k { sub(/^[^:]*: */, ""); print; exit }' <<<"$2"; }

# summary <n>: read the last n closed issues' records and propose cuts.
summary() {
  local n=$1 num body r a v records=0 ci_green=0 ci_known=0 raised=0 acted=0 reverted=0
  local nums
  mapfile -t nums < <(gh issue list --state closed --limit "$n" --json number --jq '.[].number')
  for num in "${nums[@]}"; do
    body=$(gh issue view "$num" --json comments --jq "[.comments[].body | select(contains(\"$marker\"))] | last // empty")
    [[ -n $body ]] || continue
    records=$((records + 1))
    case $(field ci_first_push "$body") in
      y) ci_green=$((ci_green + 1)); ci_known=$((ci_known + 1)) ;;
      n) ci_known=$((ci_known + 1)) ;;
    esac
    # Blank fields (a PR with no review line, or no revert field) count as zero.
    r=$(field findings_raised "$body")
    a=$(field findings_acted_on "$body")
    v=$(field reverts_or_hotfixes "$body")
    raised=$((raised + ${r:-0}))
    acted=$((acted + ${a:-0}))
    ((${v:-0} > 0)) && reverted=$((reverted + 1))
  done

  echo "records: $records"
  echo "ci green on first push: $ci_green of $ci_known known"
  echo "review findings acted on: $acted of $raised raised"
  echo "records with a later revert or hotfix: $reverted"
  echo "proposals:"
  if ((raised >= min_findings && acted * 100 < raised * min_acted_pct)); then
    echo "- cut or narrow the review step (/code-review): $acted of $raised findings acted on, below $min_acted_pct%"
  fi
  ((reverted > 0)) && echo "- read the $reverted record(s) with a later revert or hotfix before cutting any step"
  ((records < 20)) && echo "- $records records is a thin sample; propose cuts from 20 or more"
  return 0
}

case ${1:-} in
  "" | -h | --help)
    echo "usage: $0 <pr> [--post] | $0 --summary [N]" >&2
    exit 2
    ;;
  --summary)
    [[ ${2:-20} =~ ^[0-9]+$ ]] || { echo "✗ --summary N must be a number" >&2; exit 2; }
    summary "${2:-20}"
    ;;
  *)
    pr=$1
    [[ $pr =~ ^[0-9]+$ ]] || { echo "✗ PR must be a number, got '$pr'" >&2; exit 2; }
    record=$(collect "$pr")
    if [[ ${2:-} == --post ]]; then
      issue=$(field issue "$record")
      gh issue comment "$issue" --body-file - <<<"$record" >/dev/null
      echo "posted metrics for PR #$pr on issue #$issue"
    else
      echo "$record"
    fi
    ;;
esac
