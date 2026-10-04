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
closing_keywords='\b(close[sd]?|fix(e[sd])?|resolve[sd]?) #'

# skill_body: the first ```markdown block in SKILL.md, the body template.
skill_body() { awk '/^```markdown$/ {n++; next} n == 1 && /^```$/ {exit} n == 1' "$skill"; }

# template_body: the PR template as the squash commit body sees it, comments
# included: GitHub copies the body verbatim into the commit message.
template_body() { cat "$template"; }

# opens_with_links <name>: stdin's first lines are Closes, Part of, ## Changes.
opens_with_links() {
  local name=$1 lines
  mapfile -t lines < <(grep -v '^$')
  [[ ${lines[0]:-} == 'Closes #<issue>' ]] ||
    { echo "✗ $name: first line is '${lines[0]:-}', want 'Closes #<issue>'"; fail=1; }
  [[ ${lines[1]:-} == 'Part of #<parent>' ]] ||
    { echo "✗ $name: second line is '${lines[1]:-}', want 'Part of #<parent>'"; fail=1; }
  [[ ${lines[2]:-} == '## Changes' ]] ||
    { echo "✗ $name: third line is '${lines[2]:-}', want '## Changes'"; fail=1; }
  # Only the issue is closed: GitHub's closing keywords appear once.
  local closes
  closes=$(printf '%s\n' "${lines[@]}" | grep -ciE "$closing_keywords")
  ((closes == 1)) || { echo "✗ $name: $closes lines with a closing keyword, want 1"; fail=1; }
}

opens_with_links "pr skill template" < <(skill_body)
opens_with_links "pull_request_template.md" < <(template_body)

# The rule lives once in the coding standards' PR section, not in AGENTS.md.
n=$(grep -ciE "$closing_keywords|Part of #" "$root/docs/CODING_STANDARDS.md")
((n == 1)) || { echo "✗ CODING_STANDARDS.md states the issue-link rule on $n lines, want 1"; fail=1; }
section=$(awk '/^## / {s = $0} /Closes #/ {print s}' "$root/docs/CODING_STANDARDS.md")
[[ $section == '## Branches and pull requests' ]] ||
  { echo "✗ CODING_STANDARDS.md states the rule under '$section'"; fail=1; }
grep -qiE "$closing_keywords|Part of #" "$root/AGENTS.md" &&
  { echo "✗ AGENTS.md repeats the issue-link rule"; fail=1; }

# The skill fills the template; it does not restate the rule outside it.
n=$(grep -ciE "$closing_keywords" "$skill")
((n == 1)) || { echo "✗ pr SKILL.md mentions a closing keyword on $n lines, want 1 (the template)"; fail=1; }

# The mirror has the skill template's sections, in the same order.
heads() { grep -E '^## ' | tr -d '\r'; }
[[ "$(skill_body | heads)" == "$(template_body | heads)" ]] ||
  { echo "✗ pull_request_template.md section headings differ from the pr skill template"; fail=1; }

# The local change survives an upstream refresh.
grep -qE '^- `pr`:.*`Closes #`.*first line.*`Part of #`' "$root/.agents/skills/VENDORED.md" ||
  { echo "✗ VENDORED.md does not record the issue-link change to pr"; fail=1; }

((fail)) && exit 1
echo "pr-template: all checks pass"
