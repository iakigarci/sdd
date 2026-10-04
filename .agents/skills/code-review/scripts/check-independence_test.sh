#!/usr/bin/env bash
# Tests for check-independence.sh against throwaway git repos.
#   .agents/skills/code-review/scripts/check-independence_test.sh
set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd)/check-independence.sh"
fail=0

# repo <commit message>...: a fresh repo with a base commit tagged `base`,
# then one commit per message.
repo() {
  local dir
  dir=$(mktemp -d)
  git -C "$dir" init -q
  git -C "$dir" -c user.name=t -c user.email=t@t commit -q --allow-empty -m base
  git -C "$dir" tag base
  for msg in "$@"; do
    git -C "$dir" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "$msg"
  done
  echo "$dir"
}

expect() {
  local name=$1 want=$2 dir=$3 got
  got=$(cd "$dir" && "$script" base opus 2>&1)
  if [[ $got != "$want"* ]]; then
    echo "✗ $name: want prefix '$want', got '$got'"
    fail=1
  fi
  rm -rf "$dir"
}

expect "same model" "Spec review not independent" \
  "$(repo $'feat: x\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>')"

expect "same model, lowercase trailer key" "Spec review not independent" \
  "$(repo $'feat: x\n\nCo-authored-by: Claude Opus 5.5 <noreply@anthropic.com>')"

expect "mixed models, one matches" "Spec review not independent" \
  "$(repo $'feat: x\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>' \
    $'fix: y\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>')"

expect "different model" "Spec review independent" \
  "$(repo $'feat: x\n\nCo-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>')"

expect "no trailer" "Implementer model unknown" "$(repo 'feat: x')"

dir=$(repo 'feat: x')
(cd "$dir" && "$script" no-such-ref opus >/dev/null 2>&1)
[[ $? == 2 ]] || { echo "✗ bad ref did not exit 2"; fail=1; }
rm -rf "$dir"

((fail)) && exit 1
echo "check-independence: all tests pass"
