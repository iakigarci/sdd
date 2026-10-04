set shell := ["bash", "-euo", "pipefail", "-c"]

default: check

# Fast subset of `check`, run by the Claude Code Stop hook when code changed.
fast: agents-md claude-md

# Template-level gates. Generated projects get their own justfile from templates/<language>/.
check: fast script-tests secrets workflows

# AGENTS.md stays small: it is loaded on every agent turn.
agents-md:
    scripts/check-agents-md.sh 150

# Claude Code loads AGENTS.md only through CLAUDE.md's `@AGENTS.md` import.
claude-md:
    scripts/check-claude-md.sh

# Tests for the scripts, the Claude Code hooks and the skills' helper scripts.
script-tests:
    .claude/hooks/review-bash-guard_test.sh
    .agents/skills/code-review/scripts/check-independence_test.sh
    .agents/skills/code-review/scripts/reviewer-agents_test.sh
    .agents/skills/pr/scripts/pr-template_test.sh
    .agents/skills/implement/scripts/security-pass_test.sh
    .agents/skills/implement/scripts/model-assignment_test.sh
    .agents/skills/implement/scripts/workflow-tracks_test.sh
    scripts/check-branch-name_test.sh
    scripts/dedup-rules_test.sh
    scripts/enforced-rules_test.sh
    scripts/epic-children_test.sh
    scripts/pinned-tools_test.sh
    scripts/pr-metrics_test.sh
    scripts/stale-refs_test.sh

# Known vulnerabilities. The template has no dependencies of its own, so this
# only scans when a generated project's manifest is present.
vuln:
    #!/usr/bin/env bash
    set -euo pipefail
    found=0
    if [ -f go.mod ]; then found=1; go run golang.org/x/vuln/cmd/govulncheck@v1.8.0 ./...; fi
    if [ -f uv.lock ]; then found=1; uv run --with pip-audit==2.10.1 pip-audit; fi
    [ "$found" = 1 ] || echo "vuln: no go.mod or uv.lock, nothing to scan"

# Secrets committed anywhere in git history.
secrets:
    gitleaks git --no-banner --redact

# GitHub Actions workflows: injection, unpinned actions, excessive permissions.
workflows:
    zizmor --no-progress --min-severity medium .github/workflows
