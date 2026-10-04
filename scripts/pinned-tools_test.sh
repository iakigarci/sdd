#!/usr/bin/env bash
# Every tool a `just` recipe runs from the network has an exact version:
# `go run <pkg>@vX.Y.Z`, `uv run --with <pkg>==X.Y.Z`. No `@latest`, no
# unpinned `--with`. CODING_STANDARDS → Security and dependency checks states
# the rule; this test keeps the root and the template justfiles to it.
#   scripts/pinned-tools_test.sh
set -uo pipefail

root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
fail=0

# problems <justfile>: one line per unpinned tool invocation in the file.
problems() {
  {
    grep -nE '@latest' "$1" | sed "s|^|$1:|"
    grep -nE 'go (run|install) [^ ]+@' "$1" | grep -vE '@v[0-9]+\.[0-9]+\.[0-9]+' | sed "s|^|$1:|"
    grep -nE -- '--with [A-Za-z0-9._-]+( |$)' "$1" | sed "s|^|$1:|"
  } | sort -u
}

# The check must catch each form, or a clean run proves nothing.
fixture=$(mktemp)
trap 'rm -f "$fixture"' EXIT
printf '%s\n' 'go run example.com/tool@latest ./...' 'uv run --with pip-audit pip-audit' >"$fixture"
[[ $(problems "$fixture" | wc -l) == 2 ]] || { echo "✗ pinned-tools check misses an unpinned form"; fail=1; }
printf '%s\n' 'go run example.com/tool@v1.2.3 ./...' 'uv run --with pip-audit==2.10.1 pip-audit' >"$fixture"
[[ -z $(problems "$fixture") ]] || { echo "✗ pinned-tools check flags a pinned form"; fail=1; }

for justfile in "$root/justfile" "$root"/templates/*/justfile; do
  out=$(problems "$justfile")
  [[ -z $out ]] || { echo "✗ unpinned tool: ${out//$root\//}"; fail=1; }
done

((fail)) && exit 1
echo "pinned-tools: all checks pass"
