#!/bin/sh
set -eu
BIN=${1:-./build/telemetry}
FIX=${2:-fixtures/valid.txt}
$BIN --input "$FIX" >/dev/null 2>/dev/null & pid=$!
if [ -d "/proc/$pid/fd" ]; then ls -l "/proc/$pid/fd" || true; fi
wait "$pid"
