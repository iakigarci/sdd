#!/usr/bin/env bash
# PreToolUse hook for the read-only reviewer agents (.claude/agents/*-reviewer.md).
# Allows only `git diff|log|show|rev-parse` and `gh issue view`, optionally
# behind `rtk`. Exit 0 allows the call; exit 2 denies it, with stderr as the
# reason. Anything it cannot parse is denied.
set -uo pipefail

deny() {
  echo "review-bash-guard: $1. Reviewers may run only git diff|log|show|rev-parse and gh issue view, one command, no shell operators." >&2
  exit 2
}

command -v jq >/dev/null || deny "jq is not installed"
input=$(cat)
tool=$(jq -r '.tool_name // empty' <<<"$input" 2>/dev/null) || deny "unreadable hook input"
[[ $tool == Bash ]] || exit 0
cmd=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null) || deny "unreadable hook input"

# One plain command: no chaining, pipes, redirection, substitution or
# backgrounding, even inside quotes.
[[ $cmd == *$'\n'* || $cmd =~ [\;\&\|\<\>\$\`] ]] && deny "shell operators are not allowed"

read -ra words <<<"$cmd"
[[ ${words[0]:-} == rtk ]] && words=("${words[@]:1}")

case "${words[0]:-} ${words[1]:-}" in
  "git diff" | "git log" | "git show" | "git rev-parse")
    for w in "${words[@]:2}"; do
      case $w in
        --output | --output=* | --ext-diff | --exec | --exec=*) deny "git option $w is not allowed" ;;
      esac
    done
    ;;
  "gh issue")
    [[ ${words[2]:-} == view ]] || deny "only gh issue view is allowed"
    for w in "${words[@]:3}"; do
      case $w in
        -w | --web) deny "gh option $w is not allowed" ;;
      esac
    done
    ;;
  *) deny "command not allowed: ${words[0]:-<empty>} ${words[1]:-}" ;;
esac

exit 0
