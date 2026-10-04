#!/usr/bin/env bash
# Warns, never fails, when a PR changes more lines than a reviewer can hold in
# their head. Counts added + deleted lines between <base> and HEAD, leaving out
# binary files, lockfiles, generated code and anything marked
# `linguist-generated` in .gitattributes. Used by CI (.github/workflows/pr-shape.yml).
#   check-pr-size.sh <base> [max-lines]   (default 400)
set -euo pipefail

base=${1:?usage: $0 <base> [max-lines]}
max=${2:-400}

# generated <path>: true for lockfiles, generated code and linguist-generated files.
generated() {
  case $1 in
    go.sum | */go.sum | uv.lock | */uv.lock | CHANGELOG.md | */CHANGELOG.md) return 0 ;;
    *.pb.go | *_pb2.py | *_pb2.pyi | *_pb2_grpc.py | sqlcgen/* | */sqlcgen/*) return 0 ;;
  esac
  [[ $(git check-attr linguist-generated -- "$1") =~ :\ (set|true)$ ]]
}

total=0
while IFS=$'\t' read -r -d '' added deleted path; do
  [[ $added == - ]] && continue # binary
  generated "$path" && continue
  total=$((total + added + deleted))
done < <(git diff --numstat --no-renames -z "$base...HEAD")

if ((total > max)); then
  echo "::warning title=PR size::$total changed lines (guideline $max, generated files excluded). Consider splitting the PR (docs/CODING_STANDARDS.md)."
else
  echo "PR size: $total/$max changed lines (generated files excluded)"
fi
