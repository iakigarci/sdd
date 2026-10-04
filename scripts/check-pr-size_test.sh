#!/usr/bin/env bash
# Tests for check-pr-size.sh against throwaway git repos.
#   scripts/check-pr-size_test.sh
set -uo pipefail

script="$(cd "$(dirname "$0")" && pwd)/check-pr-size.sh"
fail=0

# repo <path> <lines> ...: a fresh repo with a base commit tagged `base`, then
# one commit adding each <path> with <lines> lines.
repo() {
  local dir
  dir=$(mktemp -d)
  git -C "$dir" init -q
  git -C "$dir" -c user.name=t -c user.email=t@t commit -q --allow-empty -m base
  git -C "$dir" tag base
  while (($#)); do
    mkdir -p "$dir/$(dirname "$1")"
    seq "$2" >"$dir/$1"
    shift 2
  done
  git -C "$dir" add -A
  git -C "$dir" -c user.name=t -c user.email=t@t commit -q -m change
  echo "$dir"
}

# expect <name> <warn|quiet> <dir>: the script exits 0 and warns or stays quiet.
expect() {
  local name=$1 want=$2 dir=$3 out got=quiet
  if ! out=$(cd "$dir" && "$script" base 2>&1); then
    echo "✗ $name: exited non-zero: $out"
    fail=1
  fi
  grep -q '^::warning' <<<"$out" && got=warn
  [[ $got == "$want" ]] || { echo "✗ $name: want $want, got $got: $out"; fail=1; }
  rm -rf "$dir"
}

expect "small change" quiet "$(repo main.go 10)"
expect "at the limit" quiet "$(repo main.go 400)"
expect "over the limit" warn "$(repo main.go 401)"
expect "split over files" warn "$(repo a.go 200 b/c.py 201)"

expect "lockfiles excluded" quiet "$(repo go.sum 900 uv.lock 900 svc/go.sum 900 main.go 10)"
expect "generated code excluded" quiet \
  "$(repo api/v1/x.pb.go 900 x_pb2.py 900 x_pb2_grpc.py 900 internal/db/sqlcgen/q.go 900 CHANGELOG.md 900)"
expect "generated excluded, rest still counted" warn "$(repo go.sum 900 main.go 401)"

dir=$(repo main.go 1)
printf 'gen/** linguist-generated\n' >"$dir/.gitattributes"
mkdir -p "$dir/gen" && seq 900 >"$dir/gen/out.txt"
git -C "$dir" add -A && git -C "$dir" -c user.name=t -c user.email=t@t commit -q -m gen
expect "linguist-generated attribute" quiet "$dir"

dir=$(repo main.go 1)
seq 500 >"$dir/gen.txt"
printf 'gen.txt linguist-generated=false\n' >"$dir/.gitattributes"
git -C "$dir" add -A && git -C "$dir" -c user.name=t -c user.email=t@t commit -q -m gen
expect "linguist-generated=false still counted" warn "$dir"

dir=$(repo main.go 1)
head -c 100000 /dev/urandom >"$dir/blob.bin"
git -C "$dir" add -A && git -C "$dir" -c user.name=t -c user.email=t@t commit -q -m bin
expect "binary files excluded" quiet "$dir"

((fail)) && exit 1
echo "check-pr-size: all checks pass"
