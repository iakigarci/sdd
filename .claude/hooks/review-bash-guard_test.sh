#!/usr/bin/env bash
# shellcheck disable=SC2016  # fixtures quote $(...) and backticks on purpose
# Fixture tests for review-bash-guard.sh: hook JSON in, allow (0) or deny (2) out.
#   .claude/hooks/review-bash-guard_test.sh
set -uo pipefail

guard="$(dirname "$0")/review-bash-guard.sh"
fail=0

check() {
  local want=$1 cmd=$2 got
  jq -n --arg c "$cmd" '{tool_name: "Bash", tool_input: {command: $c}}' |
    "$guard" >/dev/null 2>&1
  got=$?
  if [[ $got != "$want" ]]; then
    echo "✗ want exit $want, got $got: $cmd"
    fail=1
  fi
}

allow() { check 0 "$1"; }
deny() { check 2 "$1"; }

allow 'git diff main...HEAD'
allow 'git diff --stat main...HEAD'
allow 'git log main..HEAD --oneline'
allow "git log --format='%H %(trailers:key=Co-Authored-By,valueonly)' main..HEAD"
allow 'git show HEAD:README.md'
allow 'git rev-parse main'
allow 'gh issue view 14'
allow 'gh issue view 14 --comments --repo iakigarci/sdd'
allow 'rtk git diff main...HEAD'
allow '  git diff main...HEAD  '

# Other commands and subcommands.
deny 'rm -rf .'
deny 'git push origin HEAD'
deny 'git checkout main'
deny 'git status'
deny 'gh pr merge 3'
deny 'gh issue edit 14 --add-label x'
deny 'gh issue comment 14 --body x'
deny 'gh api repos/x/y/pulls/1/merge -X PUT'
deny 'echo git diff'
deny 'GIT_PAGER=sh git log'
deny 'rtk rm -rf .'
deny ''

# Chaining, substitution and redirection.
deny 'git diff; rm -rf .'
deny 'git diff && rm -rf .'
deny 'git diff || rm -rf .'
deny 'git diff | sh'
deny 'git diff > out.txt'
deny 'git diff < in.txt'
deny 'git log $(rm -rf .)'
deny 'git log `rm -rf .`'
deny 'git diff &'
deny $'git diff\nrm -rf .'

# git options that write files, run programs or open a browser.
deny 'git diff --output=out.txt main'
deny 'git log --output out.txt'
deny 'git -c core.pager=sh log'
deny 'git -C /tmp log'
deny 'git diff --ext-diff main'
deny 'git log --exec=sh'
deny 'gh issue view 14 --web'
deny 'gh issue view 14 -w'

# Non-Bash input is not this hook's business.
echo '{"tool_name":"Read","tool_input":{"file_path":"x"}}' | "$guard" >/dev/null 2>&1 ||
  { echo "✗ non-Bash tool was denied"; fail=1; }

# Malformed input fails closed.
echo 'not json' | "$guard" >/dev/null 2>&1
[[ $? == 2 ]] || { echo "✗ malformed input was not denied"; fail=1; }

((fail)) && exit 1
echo "review-bash-guard: all fixtures pass"
