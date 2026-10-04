#!/usr/bin/env bash
# Guards removed references from coming back: the triage-labels doc, the
# `.scratch/` spec folder and the setup skill that wrote them. Tracked files
# only; this test names the patterns, so it is excluded from its own search.
#   scripts/stale-refs_test.sh
set -uo pipefail

root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
fail=0
stale='triage-labels|\.scratch/|setup-matt-pocock-skills'

hits=$(git -C "$root" grep -nE "$stale" -- ':!scripts/stale-refs_test.sh' || true)
[[ -z $hits ]] || { echo "✗ stale reference:"; echo "$hits"; fail=1; }

((fail)) && exit 1
echo "stale-refs: all checks pass"
