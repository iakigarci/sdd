#!/usr/bin/env bash
# Checks that every PR body opens with its issue links: `Closes #<issue>`
# first, then the optional `Part of #<parent>`, both before `## Changes`, in
# the `pr` skill template and in .github/pull_request_template.md. The rule is
# stated once in the coding standards and not in AGENTS.md.
#   .agents/skills/pr/scripts/pr-template_test.sh
set -uo pipefail

root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
skill="$root/.agents/skills/pr/SKILL.md"
template="$root/.github/pull_request_template.md"
fail=0

# skill_body: the first ```markdown block in SKILL.md, the body template.
skill_body() { awk '/^```markdown$/ {n++; next} n == 1 && /^```$/ {exit} n == 1' "$skill"; }

# template_body: the PR template without HTML comment lines and blank lines.
template_body() { grep -vE '^<!--.*-->$|^$' "$template"; }

# opens_with_links <name>: stdin's first lines are Closes, Part of, ## Changes.
opens_with_links() {
  local name=$1 lines
  mapfile -t lines < <(grep -v '^$')
  [[ ${lines[0]:-} == 'Closes #<issue>' ]] ||
    { echo "✗ $name: first line is '${lines[0]:-}', want 'Closes #<issue>'"; fail=1; }
  [[ ${lines[1]:-} =~ ^'Part of #<parent>' ]] ||
    { echo "✗ $name: second line is '${lines[1]:-}', want 'Part of #<parent>…'"; fail=1; }
  [[ ${lines[2]:-} == '## Changes' ]] ||
    { echo "✗ $name: third line is '${lines[2]:-}', want '## Changes'"; fail=1; }
  local closes
  closes=$(printf '%s\n' "${lines[@]}" | grep -c '^Closes #')
  ((closes == 1)) || { echo "✗ $name: $closes 'Closes #' lines, want 1"; fail=1; }
}

skill_body | opens_with_links "pr skill template"
template_body | opens_with_links "pull_request_template.md"

# The rule lives once in the coding standards' PR section, not in AGENTS.md.
n=$(grep -c 'Closes #<n>' "$root/docs/CODING_STANDARDS.md")
((n == 1)) || { echo "✗ CODING_STANDARDS.md states the issue-link rule $n times, want 1"; fail=1; }
section=$(awk '/^## / {s = $0} /Closes #<n>/ {print s}' "$root/docs/CODING_STANDARDS.md")
[[ $section == '## Branches and pull requests' ]] ||
  { echo "✗ CODING_STANDARDS.md states the rule under '$section'"; fail=1; }
grep -qE 'Closes #|Part of #' "$root/AGENTS.md" &&
  { echo "✗ AGENTS.md repeats the issue-link rule"; fail=1; }

# The local change survives an upstream refresh.
grep -qE '^- `pr`:.*`Closes #`.*first line.*`Part of #`' "$root/.agents/skills/VENDORED.md" ||
  { echo "✗ VENDORED.md does not record the issue-link change to pr"; fail=1; }

((fail)) && exit 1
echo "pr-template: all checks pass"
