#!/bin/sh
set -eu
BIN=${1:-./build/telemetry}
FIX=${2:-fixtures}
out=$($BIN --input "$FIX/valid.txt")
[ "$out" = "count=3 sum=25 min=-5 max=20 mean=8.333" ]
out=$(cat "$FIX/valid.txt" | $BIN --input -)
[ "$out" = "count=3 sum=25 min=-5 max=20 mean=8.333" ]
if $BIN --input "$FIX/invalid.txt" >/dev/null 2>&1; then echo "invalid record unexpectedly accepted" >&2; exit 1; fi
for i in 1 2 3; do $BIN --input "$FIX/valid.txt" >/dev/null; done
fifo=$(mktemp -u); out=$(mktemp); ready=$(mktemp); mkfifo "$fifo"
exec 3<>"$fifo"
$BIN --input "$fifo" >"$out" 2>"$ready" & pid=$!
printf '1 0 7 1\n' >&3
# bounded polling coordinates until signal handlers are installed; shutdown still depends on SIGTERM interrupting open input, not EOF.
n=0
while ! grep -q '^ready$' "$ready" 2>/dev/null; do
  n=$((n+1)); [ $n -lt 100 ] || { echo "service never became ready" >&2; kill "$pid" 2>/dev/null || true; exit 1; }
  sleep 0.01
done
kill -TERM "$pid"
wait "$pid"
exec 3>&-
rm -f "$fifo"
grep -q '^count=1 sum=7 min=7 max=7 mean=7.000$' "$out"
rm -f "$out" "$ready"
echo "integration: ok"
