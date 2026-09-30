#!/usr/bin/env bash
# Conventional Commit check, shared by the lefthook commit-msg hook and CI.
#   check-commits.sh --file <commit-msg-file>   one message (hook); allows fixup!/squash!
#   check-commits.sh --range <base>..<head>      every commit in a PR (CI); fixups must be squashed
set -euo pipefail

pattern='^(feat|fix|perf|refactor|test|docs|build|ci|chore|revert)(\([a-z0-9._/-]+\))?!?: .{1,72}$'
fail=0

check() {
  local subject=$1 mode=$2
  if [[ $mode == file && $subject =~ ^(fixup|squash|amend)!\  ]]; then return; fi
  if [[ $mode == file && $subject =~ ^Merge\  ]]; then return; fi
  if ! grep -qE "$pattern" <<<"$subject"; then
    echo "✗ $subject"
    fail=1
  fi
}

case "${1:-}" in
  --file) check "$(head -n1 "$2")" file ;;
  --range)
    while IFS= read -r subject; do check "$subject" range; done < <(git log --no-merges --format=%s "$2")
    ;;
  *) echo "usage: $0 --file <msg-file> | --range <base>..<head>" >&2; exit 2 ;;
esac

if ((fail)); then
  echo "Commit subjects must follow Conventional Commits: <type>(<scope>)!: <subject>, max 72 chars (docs/CODING_STANDARDS.md)."
  exit 1
fi
