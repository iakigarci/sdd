#!/usr/bin/env bash
# Claude Code reads CLAUDE.md, not AGENTS.md: a CLAUDE.md that does not import
# AGENTS.md silently drops the shared instructions. Passes when CLAUDE.md is
# absent, is a symlink to AGENTS.md, or has a line holding only `@AGENTS.md`
# (stricter than Claude Code, which also reads inline imports).
#   check-claude-md.sh
set -euo pipefail

file=CLAUDE.md
[[ -e $file || -L $file ]] || exit 0

if [[ $file -ef AGENTS.md ]] || grep -qsE '^@(\./)?AGENTS\.md[[:space:]]*$' "$file"; then
  echo "CLAUDE.md: imports AGENTS.md"
  exit 0
fi

echo "✗ CLAUDE.md does not import AGENTS.md. Add a line containing only @AGENTS.md (docs/CODING_STANDARDS.md)."
exit 1
