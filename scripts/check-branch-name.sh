#!/usr/bin/env bash
# Branch names tie a PR to its issue: `<type>/<issue>-<slug>`, where type is a
# Conventional Commit type. Bot branches (dependabot, release-please) and the
# one-off `/project-init` branch are exempt. Used by CI
# (.github/workflows/pr-shape.yml).
#   check-branch-name.sh "<branch>"
set -euo pipefail

branch=${1:?usage: $0 "<branch>"}
pattern='^(feat|fix|perf|refactor|test|docs|build|ci|chore|revert)/[0-9]+-[a-z0-9]+(-[a-z0-9]+)*$'
exempt='^(dependabot/.+|release-please--.+|chore/project-init)$'

if ! grep -qE "$pattern|$exempt" <<<"$branch"; then
  echo "✗ $branch"
  echo "Branch name must be <type>/<issue>-<slug>, e.g. feat/42-invoice-export (docs/CODING_STANDARDS.md)."
  exit 1
fi
