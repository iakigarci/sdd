#!/usr/bin/env bash
# Is the Spec review independent of the implementer? Compares the
# Co-Authored-By trailers on <fixed-point>..HEAD with the spec reviewer's model
# family and prints one line for the review report.
#   check-independence.sh <fixed-point> <reviewer-model>   e.g. main opus
# Exit 0 with the verdict line; exit 2 on bad arguments or an unknown ref.
set -euo pipefail

[[ $# == 2 ]] || { echo "usage: $0 <fixed-point> <reviewer-model>" >&2; exit 2; }
fixed=$1 reviewer=$2
git rev-parse --verify --quiet "$fixed^{commit}" >/dev/null || { echo "unknown ref: $fixed" >&2; exit 2; }

# Trailer key matching is case-insensitive, so GitHub's Co-authored-by counts.
# Only agent trailers name a model; human co-authors are dropped.
models=$(git log "$fixed..HEAD" --format='%(trailers:key=Co-Authored-By,valueonly)' |
  grep -iE 'claude|opus|sonnet|haiku|fable|gpt|codex|gemini|noreply@anthropic\.com' |
  sed -e 's/[[:space:]]*<[^>]*>[[:space:]]*$//' | sort -u || true)

if [[ -z $models ]]; then
  echo "Implementer model unknown: no Co-Authored-By trailer on $fixed..HEAD, so Spec review independence is unverified."
elif matched=$(grep -iw -- "$reviewer" <<<"$models"); then
  echo "Spec review not independent: implementer $(paste -sd, - <<<"$matched") matches the spec reviewer ($reviewer)."
else
  echo "Spec review independent: implementer $(paste -sd, - <<<"$models"), spec reviewer $reviewer."
fi
