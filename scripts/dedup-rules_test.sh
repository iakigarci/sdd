#!/usr/bin/env bash
# Each rule is stated once. README.md links to the docs that own the workflow,
# layout, model and standards; the model table lives only in docs/agents/models.md;
# go.md keeps project decisions and points to the golang-* skills for general
# Go rules; the three architecture skills share one definition each.
#   scripts/dedup-rules_test.sh
set -uo pipefail

root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
readme="$root/README.md"
standards="$root/docs/CODING_STANDARDS.md"
gostd="$root/docs/standards/go.md"
models="$root/docs/agents/models.md"
usage="$root/USAGE.md"
fail=0

want() { # want <file> <pattern> <what>: fail unless the file has the pattern
  local file=$1 pattern=$2 what=$3
  grep -qE -- "$pattern" "$file" || { echo "✗ ${file#"$root"/}: missing $what"; fail=1; }
}
forbid() { # forbid <file> <pattern> <why>
  local file=$1 pattern=$2 why=$3
  grep -qE -- "$pattern" "$file" && { echo "✗ ${file#"$root"/} restates $why ('$pattern')"; fail=1; }
  return 0
}

# Every relative link in a file resolves to an existing path.
links_resolve() {
  local file=$1 dir link target
  dir=$(dirname "$file")
  while read -r link; do
    target=${link%%#*}
    [[ -z $target || $target == http* || $target == mailto:* ]] && continue
    [[ -e "$dir/$target" ]] || { echo "✗ ${file#"$root"/}: link '$link' does not resolve"; fail=1; continue; }
    [[ $link == *#* ]] || continue
    anchor=${link#*#}
    # GitHub slug: lower case, punctuation dropped, spaces to dashes.
    grep -E '^#+ ' "$dir/$target" | sed -E 's/^#+ +//' | tr 'A-Z' 'a-z' |
      sed -E 's/[^a-z0-9 _-]//g; s/ /-/g' | grep -qxF -- "$anchor" ||
      { echo "✗ ${file#"$root"/}: anchor '#$anchor' is not a heading in $target"; fail=1; }
  done < <(grep -oE '\]\([^)]+\)' "$file" | sed -E 's/^\]\((.*)\)$/\1/')
}

# README.md: links, not copies. No table (its tables were the copies), no
# workflow chain, no model names, no duplicated security or git rules.
forbid "$readme" '^\|' 'a table (link to the owning doc instead)'
forbid "$readme" '/to-tickets|/code-review|/implement' 'the workflow chain (link to AGENTS.md → Workflow)'
forbid "$readme" 'Opus|Sonnet|Haiku' 'the model assignment (link to docs/agents/models.md)'
forbid "$readme" 'squash' 'the git flow (link to CODING_STANDARDS → Branches and pull requests)'
forbid "$readme" 'Trivy|trivy|gitleaks|govulncheck' 'the security checks (link to CODING_STANDARDS → Security)'
want "$readme" 'AGENTS\.md#workflow' 'a link to the workflow chain in AGENTS.md'
want "$readme" '\(docs/workflow\.md\)' 'a link to docs/workflow.md'
links_resolve "$readme"

# The model table is the only table that names models. USAGE.md's cheat sheet
# is a second copy: it links to models.md instead.
for f in "$root"/*.md "$root"/docs/*.md "$root"/docs/*/*.md "$root"/.agents/skills/*/*.md "$root"/.claude/agents/*.md; do
  [[ $f == "$models" ]] && continue
  grep -qE '^\|.*\b(Opus|Sonnet|Haiku)\b' "$f" &&
    { echo "✗ ${f#"$root"/} has a table naming models; only docs/agents/models.md may"; fail=1; }
done
want "$usage" 'docs/agents/models\.md' 'a link to docs/agents/models.md for the model table'

# README's Layout section: every entry is a link, not a description.
layout_bad=$(awk '/^## /{on = ($0 == "## Layout")} on && /^- / && !/\]\(/' "$readme")
[[ -z $layout_bad ]] || { echo "✗ README Layout has entries without a link: $layout_bad"; fail=1; }

# CODING_STANDARDS.md: the PR body rule links to the pr skill and its template.
want "$standards" '\.agents/skills/pr/SKILL\.md' 'a link to the pr skill template'
want "$standards" '\.github/pull_request_template\.md' 'a link to the PR template mirror'
links_resolve "$standards"

# go.md keeps the project decisions and drops the general rules the golang-*
# skills own. The skills it points to must exist.
for skill in golang-error-handling golang-observability golang-naming golang-testing \
  golang-context golang-concurrency golang-structs-interfaces; do
  [[ -f "$root/.agents/skills/$skill/SKILL.md" ]] || { echo "✗ skill $skill is missing"; fail=1; }
  want "$gostd" "\.agents/skills/$skill/" "a pointer to the $skill skill"
done
forbid "$gostd" 't\.Parallel|t\.Helper' 'table-driven test mechanics (golang-testing)'
forbid "$gostd" 'context\.Context. is the first parameter' 'context placement (golang-context)'
forbid "$gostd" 'Every goroutine has an owner' 'goroutine ownership (golang-concurrency)'
forbid "$gostd" 'accept interfaces, return concrete' 'interface design (golang-structs-interfaces)'
forbid "$gostd" 'Wrap errors with' 'error wrapping (golang-error-handling)'
forbid "$gostd" 'Standard library first' 'the dependency rule (CODING_STANDARDS → Dependencies)'
want "$gostd" 'CODING_STANDARDS\.md' 'a link to CODING_STANDARDS.md for the shared rules'
want "$gostd" 'Dependency rule' 'the project architecture rule kept'
links_resolve "$gostd"

# The three architecture skills: one definition each. The vocabulary lives in
# codebase-design, the ADR offer rule in domain-modeling, lazy file creation in
# domain-modeling.
arch="$root/.agents/skills/improve-codebase-architecture/SKILL.md"
forbid "$arch" "don't drift|don’t drift" 'the terms rule (codebase-design → Glossary)'
forbid "$arch" 'one adapter = hypothetical|the interface is the test surface' 'the principles text (codebase-design → Principles)'
forbid "$arch" 'lazily' 'lazy file creation (domain-modeling → File structure)'
want "$arch" 'codebase-design' 'a call to the codebase-design vocabulary'
want "$arch" 'domain-modeling' 'a call to the domain-modeling skill'

# Shared definitions stay in one place: the deletion-test and shallow-module
# definitions live in codebase-design; the ADR criteria in domain-modeling.
forbid "$arch" 'would deleting it concentrate' 'the deletion-test definition (codebase-design → Principles)'
forbid "$arch" 'nearly as complex as the implementation' 'the shallow-module definition (codebase-design → Deep vs shallow)'
forbid "$arch" 'Only offer when' 'the ADR criteria (domain-modeling → Offer ADRs sparingly)'
forbid "$usage" 'roughly under 400' 'the PR size rule (CODING_STANDARDS → Branches and pull requests)'
forbid "$usage" 'Update branch' 'the branch-update rule (CODING_STANDARDS → Branches and pull requests)'
want "$standards" 'AGENTS\.md#working-rules' 'a link to the agent logging rule in AGENTS.md'

# Rules the golang-* skills state are linked, not copied (see the go.md and
# CODING_STANDARDS sections removed in the dedupe).
forbid "$standards" 'Handle each error once' 'the log-or-return rule (golang-error-handling)'
forbid "$standards" 'Structured logs' 'structured logging (golang-observability)'
forbid "$gostd" 'ErrX' 'the sentinel naming rule (golang-naming)'
forbid "$gostd" 'race detector' 'the race rule (golang-concurrency)'
forbid "$gostd" 'injected rather than global' 'the logging injection rule (golang-observability)'

((fail)) && exit 1
echo "dedup-rules: all checks pass"
