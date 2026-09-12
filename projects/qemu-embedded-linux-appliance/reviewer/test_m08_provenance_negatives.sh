#!/usr/bin/env bash
# P3-M08 provenance negative-control + validator fail-closed suite (REVIEWER-ONLY).
#
# Complements test_m08_transfer_mutations.sh (which already covers kernel-bytes
# mismatch, stale DTB, -m argv skew, short handwritten log, missing-dependency
# ERROR, highmem=on, host-QEMU-masquerade, decoy overlay and synthetic strings).
# This suite adds the genuinely-missing binder negatives, attacks the binder and
# the launch runner to prove they fail CLOSED, and demonstrates the one known
# fail-OPEN path (the runtime binder ignores qemu_exit_code) which the semantic
# oracle closes. A crash or unrelated environment failure never counts as an
# intended REJECT/ERROR.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJ_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$PROJ_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

echo "=== materialising provenance fixtures (deterministic) ==="
bash reviewer/scripts/generate_m08_assessment_fixtures.sh >/dev/null

WORK="build/reviewer-m08-provenance"
rm -rf "$WORK"
mkdir -p "$WORK/mut" "$WORK/run"
BASE="$PROJ_ROOT/build/reviewer-m08-oracle/repaired"
BASE_REL="build/reviewer-m08-oracle/repaired"

TOTAL=0
PASSED=0
DEFECTS=0

bind() { "$PY" scripts/verify_m08_runtime.py --manifest "$1" --run "$2" --log "$3" --overlay overlay; }

copy_to_mut() {
    local name="$1"
    rm -rf "$WORK/mut/$name"
    cp -r "$BASE_REL" "$WORK/mut/$name"
}

mut_run() {
    local name="$1" expr="$2"
    copy_to_mut "$name"
    "$PY" - "$WORK/mut/$name/appliance.run.json" "$expr" <<'PY'
import json, sys
p, expr = sys.argv[1], sys.argv[2]
doc = json.load(open(p, encoding="utf-8"))
exec(expr, {"doc": doc})
json.dump(doc, open(p, "w", encoding="utf-8"), indent=2)
open(p, "a", encoding="utf-8").write("\n")
PY
}

mut_log() {
    local name="$1" expr="$2"
    copy_to_mut "$name"
    "$PY" - "$WORK/mut/$name/console.log" "$expr" <<'PY'
import re, sys
p, expr = sys.argv[1], sys.argv[2]
ns = {"text": open(p, encoding="utf-8").read(), "re": re}
exec(expr, ns)
open(p, "w", encoding="utf-8").write(ns["text"])
PY
}

assert_bind_rc() {
    local expected="$1" name="$2" dir="$3"
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] $name (expect rc=$expected) ... "
    set +e
    local out rc
    out=$(bind "$dir/appliance.manifest.json" "$dir/appliance.run.json" "$dir/console.log" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq "$expected" ]; then
        echo "PASS"; PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected $expected)"; echo "$out" | tail -n 12; exit 1
    fi
}

echo "================================================================"
echo "=== P3-M08 Provenance Negative Controls (REVIEWER-ONLY)       ==="
echo "================================================================"

# --- A. binder transfer negatives (genuinely missing from the mutation suite) --

mut_run "stale-rootfs" "doc['rootfs']['sha256'] = 'd'*64"
assert_bind_rc 1 "stale rootfs record (run hash disagrees with manifest)" "$WORK/mut/stale-rootfs"

mut_log "missing-marker" "text = text.replace('APPLIANCE-OVERLAY-BOOT-MARKER\\n', '')"
assert_bind_rc 1 "missing guest overlay boot marker" "$WORK/mut/missing-marker"

# argv order/shape skew: move -smp 1 ahead of -m 512M (fingerprint recomputed).
copy_to_mut "argv-reorder"
"$PY" - "$WORK/mut/argv-reorder/appliance.run.json" <<'PY'
import hashlib, json, shlex, sys
p = sys.argv[1]
doc = json.load(open(p, encoding="utf-8"))
a = doc["argv"]
# original: [qemu, -machine, M, -cpu, C, -m, 512M, -smp, 1, -nographic, ...]
doc["argv"] = a[0:5] + a[7:9] + a[5:7] + a[9:]
doc["argv_fingerprint"] = hashlib.sha256(
    "\n".join(shlex.quote(t) for t in doc["argv"]).encode("utf-8")).hexdigest()
json.dump(doc, open(p, "w", encoding="utf-8"), indent=2)
open(p, "a", encoding="utf-8").write("\n")
PY
assert_bind_rc 1 "argv order/shape skew (reordered -smp/-m)" "$WORK/mut/argv-reorder"

mut_run "wrong-cpu" "doc['qemu']['cpu'] = 'cortex-a9'"
assert_bind_rc 1 "non-Cortex-A7 CPU" "$WORK/mut/wrong-cpu"

mut_run "gic-3" "doc['qemu']['machine'] = 'virt,highmem=off,gic-version=3'"
assert_bind_rc 1 "gic-version=3 mismatch" "$WORK/mut/gic-3"

mut_run "wrong-machine" "doc['qemu']['machine'] = 'versatilepb'"
assert_bind_rc 1 "wrong QEMU machine string" "$WORK/mut/wrong-machine"

mut_run "wrong-smp" "doc['qemu']['smp'] = 2"
assert_bind_rc 1 "different SMP" "$WORK/mut/wrong-smp"

mut_run "wrong-mem" "doc['qemu']['mem'] = '256M'"
assert_bind_rc 1 "different memory" "$WORK/mut/wrong-mem"

# --- B. binder fail-CLOSED attacks (missing tool / unreadable / parse error) ---
assert_bind_rc 2 "missing manifest input is ERROR" \
    "$WORK/mut/does-not-exist"

mkdir -p "$WORK/mut/manifest-is-dir/appliance.manifest.json"
cp "$BASE_REL/appliance.run.json" "$WORK/mut/manifest-is-dir/appliance.run.json"
cp "$BASE_REL/console.log" "$WORK/mut/manifest-is-dir/console.log"
assert_bind_rc 2 "unreadable manifest (path is a directory) is ERROR" "$WORK/mut/manifest-is-dir"

copy_to_mut "malformed-run"
printf '{"schema": "m08-run-v1", "argv": [' > "$WORK/mut/malformed-run/appliance.run.json"
assert_bind_rc 2 "parser exception (truncated run JSON) is ERROR" "$WORK/mut/malformed-run"

# --overlay nonexistent: the binder must ERROR, never VERIFY.
set +e
out=$("$PY" scripts/verify_m08_runtime.py \
    --manifest "$BASE_REL/appliance.manifest.json" \
    --run "$BASE_REL/appliance.run.json" \
    --log "$BASE_REL/console.log" \
    --overlay "$WORK/does-not-exist-overlay" 2>&1)
rc=$?
set -e
TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] nonexistent overlay tree is ERROR ... "
if [ "$rc" -eq 2 ]; then echo "PASS"; PASSED=$((PASSED + 1));
else echo "FAIL (rc=$rc)"; echo "$out" | tail -n 6; exit 1; fi

# --- C. launch runner fail-CLOSED attacks (never reports boot success) ---------
echo "--- runner fail-closed attacks ---"
# A fake QEMU that answers --version instantly and otherwise sleeps (so the
# runner's capture times out). It must NOT hang on the runner's version probe.
cat > "$WORK/fake-sleep-qemu" <<'SH'
#!/bin/sh
case "${1:-}" in
    --version) echo "fake-sleep-qemu 0.0"; exit 0 ;;
esac
exec sleep 300
SH
chmod +x "$WORK/fake-sleep-qemu"

runner() {
    # runner <name> <qemu-bin> <timeout> <expected-rc>
    local name="$1" qemu_bin="$2" timeout="$3" expected="$4"
    local log="$WORK/run/$name.log" run="$WORK/run/$name.run.json"
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] $name (expect rc=$expected) ... "
    set +e
    local out rc
    out=$(QEMU_BIN="$qemu_bin" TIMEOUT_SEC="$timeout" bash scripts/run_appliance.sh \
        --manifest "$BASE_REL/appliance.manifest.json" --log "$log" --run "$run" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq "$expected" ]; then
        echo "PASS"; PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected $expected)"; echo "$out" | tail -n 8; exit 1
    fi
}

runner "missing QEMU binary is LAUNCH-FAIL" "$WORK/does-not-exist-qemu" 120 2
runner "QEMU non-zero exit is RUNTIME-FAIL" "/bin/false" 120 2
runner "QEMU timeout is TIMEOUT (not success)" "$WORK/fake-sleep-qemu" 2 124
runner "QEMU exit 0 with no guest marker is GUEST-MARKER-ABSENT" "/bin/true" 120 3

# Verify the timeout run record is not a silent success.
"$PY" - "$WORK/run/QEMU timeout is TIMEOUT (not success).run.json" <<'PY'
import json, sys
p = sys.argv[1]
doc = json.load(open(p, encoding="utf-8"))
assert doc.get("timed_out") is True, "timed_out must be recorded as true"
assert doc.get("qemu_exit_code") == 124, "qemu_exit_code must be 124"
print("run record records timed_out=true, qemu_exit_code=124 (no silent success)")
PY

# --- D. fail-OPEN defect demonstration (binder) + oracle fail-closed reference ---
echo "--- fail-open defect demonstration + oracle fail-closed reference ---"
copy_to_mut "qemu-failed"
"$PY" - "$WORK/mut/qemu-failed/appliance.run.json" <<'PY'
import json, sys
p = sys.argv[1]
doc = json.load(open(p, encoding="utf-8"))
doc["qemu_exit_code"] = 1   # QEMU failed, but the log is complete
json.dump(doc, open(p, "w", encoding="utf-8"), indent=2)
open(p, "a", encoding="utf-8").write("\n")
PY

set +e
BIND_RC=$(bind "$WORK/mut/qemu-failed/appliance.manifest.json" \
    "$WORK/mut/qemu-failed/appliance.run.json" "$WORK/mut/qemu-failed/console.log" 2>&1 >/dev/null; echo $?)
set -e
echo "[DEFECT-DEMO] runtime binder rc on qemu_exit_code=1 + complete log: $BIND_RC"
echo "[DEFECT-DEMO]   rc=0 means the binder graded a failed QEMU run as VERIFIED (S2 fail-open,"
echo "[DEFECT-DEMO]   owned by scripts/verify_m08_runtime.py; the oracle below closes it)."
if [ "$BIND_RC" -eq 0 ]; then DEFECTS=$((DEFECTS + 1)); fi

TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] semantic oracle fail-closed on QEMU failure (expect rc=1) ... "
set +e
out=$(bash reviewer/oracle_m08.sh "$WORK/mut/qemu-failed" gate 2>&1)
rc=$?
set -e
if [ "$rc" -eq 1 ]; then
    echo "PASS"; PASSED=$((PASSED + 1))
else
    echo "FAIL (rc=$rc)"; echo "$out" | tail -n 8; exit 1
fi

echo "------------------------------------------------------------------"
echo "=== PROVENANCE NEGATIVES: $PASSED/$TOTAL fail-closed checks hold;"
echo "=== $DEFECTS known fail-open path(s) in scripts/ demonstrated above ==="
