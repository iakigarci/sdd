#!/usr/bin/env bash
# PRs are squash-merged: the PR title becomes the commit subject on main, so it
# must be a Conventional Commit. Used by CI (.github/workflows/pr-title.yml).
#   check-pr-title.sh "<title>"
set -euo pipefail

title=${1:?usage: $0 "<pr title>"}
pattern='^(feat|fix|perf|refactor|test|docs|build|ci|chore|revert)(\([a-z0-9._/-]+\))?!?: [^ ].*$'

if ! grep -qE "$pattern" <<<"$title" || ((${#title} > 72)); then
  echo "✗ $title"
  echo "PR title must be a Conventional Commit, max 72 chars: <type>(<scope>)!: <subject> (docs/CODING_STANDARDS.md)."
  exit 1
fi
