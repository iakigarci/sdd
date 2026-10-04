#!/usr/bin/env bash
# Claude Code reads CLAUDE.md, not AGENTS.md: a CLAUDE.md that does not import
# AGENTS.md silently drops the shared instructions. Passes when CLAUDE.md is
# absent, is a symlink to AGENTS.md, or has an `@AGENTS.md` line.
#   check-claude-md.sh
set -euo pipefail

file=CLAUDE.md
[[ -e $file ]] || exit 0

if [[ $file -ef AGENTS.md ]] || grep -qE '^@(\./)?AGENTS\.md[[:space:]]*$' "$file"; then
  echo "CLAUDE.md: imports AGENTS.md"
  exit 0
fi

echo "✗ CLAUDE.md does not import AGENTS.md. Add a line containing only @AGENTS.md."
exit 1
