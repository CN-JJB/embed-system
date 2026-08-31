#!/usr/bin/env bash
set -u
runs=${1:-10}
fail=0
for ((i=1; i<=runs; i++)); do
  if ./fault_race; then
    :
  else
    fail=$((fail+1))
  fi
done
printf 'mismatching runs: %d/%d\n' "$fail" "$runs"
