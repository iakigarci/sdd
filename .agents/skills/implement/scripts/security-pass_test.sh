#!/usr/bin/env bash
# Checks the security pass: the `to-spec` template carries a Threat Model
# section (trust boundaries, assets, one STRIDE pass), `/implement`'s
# pre-mortem draws from it, `/implement` runs `/security-review` on a diff that
# touches a sensitive area (language security skill as the fallback), and its
# findings are fixed or land in Merge Danger. Both local changes are recorded
# in VENDORED.md so they survive an upstream refresh.
#   .agents/skills/implement/scripts/security-pass_test.sh
set -uo pipefail

root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
implement="$root/.agents/skills/implement/SKILL.md"
to_spec="$root/.agents/skills/to-spec/SKILL.md"
vendored="$root/.agents/skills/VENDORED.md"
fail=0

# step <n>: the text of numbered step n in implement's SKILL.md, continuation
# lines included.
step() { awk -v n="$1" '$0 ~ "^"n"\\. " {on = 1; print; next} on && /^[0-9]+\. / {exit} on' "$implement"; }

# has <name> <text> <pattern...>: every pattern occurs in text, ignoring case.
has() {
  local name=$1 text=$2 pattern
  shift 2
  for pattern in "$@"; do
    grep -qiE -- "$pattern" <<<"$text" || { echo "✗ $name: missing '$pattern'"; fail=1; }
  done
}

review=$(step 6)
has "implement Review step" "$review" \
  '/security-review' '\bauth' 'input parsing' 'serialization' 'SQL' '\bexec\b' \
  'secrets' 'file paths' 'network' 'golang-security' 'Merge Danger'

# The review is conditional on the diff, and unfixed findings reach the PR.
has "implement Review step" "$review" \
  'When the diff touches auth[^.;]*also run `/security-review`' \
  'agents without that command run the language security skill' \
  'for Python[^;]*manual pass' \
  'security finding left unfixed goes into the PR.s Merge Danger'

has "implement Pre-mortem step" "$(step 3)" \
  'Pre-mortem' 'when the spec has a Threat Model section, draw the security failures from its threats'

# template: the spec template between the <spec-template> tags.
template=$(awk '/^<spec-template>$/ {on = 1; next} /^<\/spec-template>$/ {exit} on' "$to_spec")
threat=$(awk '/^## / {on = ($0 == "## Threat Model"); next} on' <<<"$template")
[[ -n $threat ]] || { echo "✗ to-spec template: no '## Threat Model' section"; fail=1; }
has "to-spec Threat Model" "$threat" \
  'Trust boundaries' 'Assets' 'STRIDE' 'Spoofing' 'Tampering' 'Repudiation' \
  'Information disclosure' 'Denial of service' 'Elevation of privilege'

# Every STRIDE letter gets its line: the pass cannot be skipped as a whole.
grep -qiE 'one line each for Spoofing' <<<"$threat" ||
  { echo "✗ to-spec Threat Model: STRIDE is not one line per letter"; fail=1; }
grep -qiE 'instead|skip|omit' <<<"$threat" &&
  { echo "✗ to-spec Threat Model: offers a way to skip the pass"; fail=1; }

# The threat model sits with the design, before the tests that cover it.
order=$(grep -E '^## (Implementation Decisions|Threat Model|Testing Decisions)$' <<<"$template" | tr '\n' '|')
[[ $order == '## Implementation Decisions|## Threat Model|## Testing Decisions|' ]] ||
  { echo "✗ to-spec template: section order is '$order'"; fail=1; }

grep -qE '^- `implement`:.*pre-mortem.*Threat Model.*`/security-review`.*Merge Danger' "$vendored" ||
  { echo "✗ VENDORED.md does not record the security pass in implement"; fail=1; }
grep -qE '^- `to-spec`:.*Threat Model' "$vendored" ||
  { echo "✗ VENDORED.md does not record the Threat Model section in to-spec"; fail=1; }

((fail)) && exit 1
echo "security-pass: all checks pass"
