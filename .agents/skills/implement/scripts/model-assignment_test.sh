#!/usr/bin/env bash
# Checks that each workflow step runs on the model docs/agents/models.md
# assigns it: the session default, skill frontmatter pins, the "/model opus"
# opener on multi-turn skills, and the forked Haiku PR writer.
#   .agents/skills/implement/scripts/model-assignment_test.sh
set -uo pipefail

root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
skills="$root/.agents/skills"
doc="$root/docs/agents/models.md"
fail=0

# frontmatter <file>: the lines between the first two `---`.
frontmatter() { awk '/^---$/ {n++; next} n == 1' "$1"; }

# body <file>: the first non-empty line after the frontmatter.
first_line() { awk '/^---$/ {n++; next} n >= 2 && NF {print; exit}' "$1"; }

model_of() { frontmatter "$skills/$1/SKILL.md" | sed -n 's/^model: //p'; }

# 1. The doc holds the table and the one-turn caveat.
if [[ -f $doc ]]; then
  for row in \
    '\| Opus \|.*grill-with-docs.*to-tickets.*diagnosing-bugs.*improve-codebase-architecture.*spec review.*hotfix diagnosis' \
    '\| Opus/Sonnet \|.*to-spec' \
    '\| Sonnet \|.*implement.*tdd.*standards review.*handoff.*hotfix fix' \
    '\| Haiku \|.*PR body'; do
    grep -qE -- "$row" "$doc" || { echo "✗ models.md: no table row /$row/"; fail=1; }
  done
  grep -qiE 'model:.*(rest of the|one|current) turn' "$doc" ||
    { echo "✗ models.md: no caveat that skill model: lasts one turn"; fail=1; }
else
  echo "✗ docs/agents/models.md missing"; fail=1
fi

# 2. Project settings default the session to Sonnet.
grep -qE '^  "model": "sonnet",?$' "$root/.claude/settings.json" ||
  { echo "✗ .claude/settings.json: no top-level \"model\": \"sonnet\""; fail=1; }

# 3. Single-turn skills pin their model.
want_model() {
  local skill=$1 want=$2 got
  got=$(model_of "$skill")
  [[ $got == "$want" ]] || { echo "✗ $skill: model is '$got', want '$want'"; fail=1; }
}
want_model handoff sonnet
want_model to-spec inherit # ASSUMP-2: Opus/Sonnet means the session's model
want_model pr haiku

# ASSUMP-3: /implement and the skills it invokes mid-turn never pin a model,
# so /model opus escalates the whole turn and nothing switches it back.
for skill in implement tdd code-review; do
  want_model "$skill" ''
done

# 4. Multi-turn skills open with the /model opus instruction and pin nothing.
# ASSUMP-1: to-tickets quizzes the user until approval, so it is multi-turn.
for skill in grill-with-docs diagnosing-bugs improve-codebase-architecture to-tickets; do
  first_line "$skills/$skill/SKILL.md" | grep -qF 'Run under `/model opus`' ||
    { echo "✗ $skill: does not open with 'Run under \`/model opus\`'"; fail=1; }
  want_model "$skill" ''
done

# Every skill that names a model points at the doc.
for skill in handoff to-spec pr grill-with-docs diagnosing-bugs improve-codebase-architecture to-tickets implement; do
  grep -qF 'docs/agents/models.md' "$skills/$skill/SKILL.md" ||
    { echo "✗ $skill: does not reference docs/agents/models.md"; fail=1; }
done

# 5. The PR body comes from a forked agent that gets its inputs as arguments
# (the fork sees no conversation) and returns text instead of opening the PR.
pr=$skills/pr/SKILL.md
frontmatter "$pr" | grep -qx 'context: fork' || { echo "✗ pr: not context: fork"; fail=1; }
grep -qF '$ARGUMENTS' "$pr" || { echo "✗ pr: does not read \$ARGUMENTS"; fail=1; }
grep -qiE 'return.*(title|body).*text' "$pr" || { echo "✗ pr: does not say it returns text"; fail=1; }
grep -qE 'pr` skill.*issue.*evidence.*arguments' "$skills/implement/SKILL.md" ||
  { echo "✗ implement: does not pass the issue and evidence to the pr skill"; fail=1; }

# 6. /implement names when to escalate to Opus.
grep -qE '\*\*Escalate\*\*.*`/model opus`' "$skills/implement/SKILL.md" ||
  { echo "✗ implement: no **Escalate** step naming \`/model opus\`"; fail=1; }

# Local changes survive an upstream refresh.
for skill in pr implement handoff to-spec to-tickets grill-with-docs diagnosing-bugs improve-codebase-architecture; do
  grep -qE "^- .*\`$skill\`.*(model|/model opus)" "$root/.agents/skills/VENDORED.md" ||
    { echo "✗ VENDORED.md does not record the model change to $skill"; fail=1; }
done

((fail)) && exit 1
echo "model-assignment: all checks pass"
