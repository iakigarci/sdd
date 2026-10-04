#!/usr/bin/env bash
# Checks the reviewer agents' frontmatter (.claude/agents/) and that
# /code-review's independence check names the spec reviewer's model.
#   .agents/skills/code-review/scripts/reviewer-agents_test.sh
set -uo pipefail

root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
skill="$root/.agents/skills/code-review/SKILL.md"
fail=0

# frontmatter <file>: the lines between the first two `---`.
frontmatter() { awk '/^---$/ {n++; next} n == 1' "$1"; }

has() {
  local file=$1 pattern=$2
  frontmatter "$root/$file" | grep -qE -- "$pattern" ||
    { echo "✗ $file: frontmatter lacks /$pattern/"; fail=1; }
}

for agent in spec-reviewer standards-reviewer; do
  f=.claude/agents/$agent.md
  [[ -f $root/$f ]] || { echo "✗ $f missing"; fail=1; continue; }
  has "$f" "^name: $agent$"
  has "$f" '^tools: Read, Grep, Glob, Bash$'
  has "$f" '^disallowedTools: .*\bAgent\b'
  has "$f" '^disallowedTools: .*\bSkill\b'
  has "$f" '^disallowedTools: .*\bEdit\b'
  has "$f" '^disallowedTools: .*\bWrite\b'
  has "$f" 'matcher: "Bash"'
  has "$f" 'command: .*/\.claude/hooks/review-bash-guard\.sh'
done

has .claude/agents/spec-reviewer.md '^model: opus$'
has .claude/agents/spec-reviewer.md '^omitClaudeMd: true$'
has .claude/agents/standards-reviewer.md '^model: sonnet$'

# The independence check compares against the spec reviewer's model.
model=$(frontmatter "$root/.claude/agents/spec-reviewer.md" | sed -n 's/^model: //p')
grep -qF "check-independence.sh <fixed-point> $model\`" "$skill" ||
  { echo "✗ SKILL.md independence check does not use the spec reviewer's model ($model)"; fail=1; }

# Both agents are invoked by name.
for agent in spec-reviewer standards-reviewer; do
  grep -qF "\`$agent\` with" "$skill" || { echo "✗ SKILL.md does not invoke $agent by name"; fail=1; }
done

((fail)) && exit 1
echo "reviewer-agents: all checks pass"
