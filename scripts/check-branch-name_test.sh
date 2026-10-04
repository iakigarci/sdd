#!/usr/bin/env bash
# Tests for check-branch-name.sh.
#   scripts/check-branch-name_test.sh
set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd)/check-branch-name.sh"
fail=0

expect() {
  local want=$1 branch=$2 got=pass
  "$script" "$branch" >/dev/null 2>&1 || got=fail
  [[ $got == "$want" ]] || { echo "✗ $branch: want $want, got $got"; fail=1; }
}

expect pass feat/42-invoice-export
expect pass docs/16-trim-agents-md
expect pass fix/7-a
expect pass revert/108-undo-2fa-rollout

# Bot and one-off branches are exempt.
expect pass dependabot/go_modules/github.com/gin-gonic/gin-1.11.0
expect pass release-please--branches--main--components--sdd
expect pass chore/project-init

expect fail main
expect fail feat/invoice-export
expect fail feat/42
expect fail feat/42-
expect fail feature/42-invoice-export
expect fail feat/42-Invoice-Export
expect fail feat/42-invoice_export
expect fail feat/42-invoice/export
expect fail Feat/42-invoice-export
expect fail chore/project-init-2

((fail)) && exit 1
echo "check-branch-name: all checks pass"
