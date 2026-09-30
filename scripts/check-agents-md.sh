#!/usr/bin/env bash
# AGENTS.md is loaded on every agent turn; evals show gains reverse past ~150
# lines. Counts AGENTS.md plus the files it imports with `@path` lines.
#   check-agents-md.sh [max-lines]   (default 150)
set -euo pipefail

max=${1:-150}
file=AGENTS.md
[[ -f $file ]] || { echo "✗ $file not found"; exit 1; }

total=$(wc -l <"$file")
while IFS= read -r import; do
  path=${import#@}
  [[ -f $path ]] && total=$((total + $(wc -l <"$path")))
done < <(grep -E '^@[^[:space:]]+$' "$file" || true)

if ((total > max)); then
  echo "✗ AGENTS.md is $total lines (limit $max). Move detail into docs/ or a skill and point to it."
  exit 1
fi

echo "AGENTS.md: $total/$max lines"
