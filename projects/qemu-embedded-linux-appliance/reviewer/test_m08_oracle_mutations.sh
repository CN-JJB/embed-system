#!/usr/bin/env bash
# Oracle regression suite for P3-M08 (REVIEWER-ONLY).
#
# Verifies that the assessment oracle itself behaves correctly: it accepts a
# fully repaired provenance/run record, rejects each seeded/transfer defect
# family, classifies a truncated artifact as ERROR, and never reports a
# missing tool or unreadable input as an intended REJECT.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJ_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$PROJ_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

ORACLE_OUT="build/reviewer-m08-oracle"
WORK="build/reviewer-m08-oracle-mutations"

echo "=== materialising oracle fixtures (deterministic) ==="
bash reviewer/scripts/generate_m08_assessment_fixtures.sh >/dev/null

rm -rf "$WORK"
mkdir -p "$WORK/mut"

TOTAL=0
PASSED=0

run_oracle() {
    # run_oracle <expected-rc> <name> <candidate-dir>
    local expected="$1" name="$2" candidate="$3"
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] $name (expect rc=$expected) ... "
    set +e
    local out rc
    out=$(bash reviewer/oracle_m08.sh "$candidate" gate 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq "$expected" ]; then
        echo "PASS"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc)"; echo "$out"; exit 1
    fi
}

copy_to_mut() {
    local src="$1" name="$2"
    rm -rf "$WORK/mut/$name"
    cp -r "$ORACLE_OUT/$src" "$WORK/mut/$name"
}

echo "================================================================"
echo "=== P3-M08 Oracle Regression Suite (REVIEWER-ONLY)            ==="
echo "================================================================"

# --- 1. canonical repaired candidate accepted ---------------------------------
run_oracle 0 "fully-repaired candidate ACCEPT" "$ORACLE_OUT/repaired"
run_oracle 0 "fully-repaired explicit-DTB candidate ACCEPT" "$ORACLE_OUT/repaired-explicit"

# --- 2. opaque seeded candidate rejected --------------------------------------
run_oracle 1 "opaque seeded candidate REJECT" "$ORACLE_OUT/seeded"

# --- 3. half-repair: bootargs fixed, hidden DT-MODEL sentinel still present ----
copy_to_mut "seeded" "half-repaired"
"$PY" - "$WORK/mut/half-repaired" <<'PY'
import hashlib, json, re, shlex, sys
d = sys.argv[1]
FROZEN = "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/sbin/init panic=1"
run_path = d + "/appliance.run.json"
run = json.load(open(run_path, encoding="utf-8"))
run["bootargs"] = FROZEN
run["argv"][-1] = FROZEN
run["argv_fingerprint"] = hashlib.sha256(
    "\n".join(shlex.quote(a) for a in run["argv"]).encode("utf-8")).hexdigest()
json.dump(run, open(run_path, "w", encoding="utf-8"), indent=2)
open(run_path, "a", encoding="utf-8").write("\n")
log_path = d + "/console.log"
log = open(log_path, encoding="utf-8").read()
log = re.sub(r"Kernel command line:.*", "Kernel command line: " + FROZEN, log)
open(log_path, "w", encoding="utf-8").write(log)
PY
run_oracle 1 "half-repaired candidate (bootargs fixed, hidden DT-MODEL left) REJECT" \
    "$WORK/mut/half-repaired"

# --- 4. stale DTB paired with current kernel/rootfs ----------------------------
copy_to_mut "repaired-explicit" "stale-dtb"
printf 'STALE-DTB\n' >> "$WORK/mut/stale-dtb/qemu-virt.dtb"
run_oracle 1 "stale DTB + current kernel/rootfs REJECT" "$WORK/mut/stale-dtb"

# --- 5. correct filename but different bytes -----------------------------------
copy_to_mut "repaired" "diff-bytes"
printf 'DIFFERENT-BYTES\n' >> "$WORK/mut/diff-bytes/zImage"
run_oracle 1 "correct filename, different kernel bytes REJECT" "$WORK/mut/diff-bytes"

# --- 6. good-looking handwritten log (forged release) --------------------------
copy_to_mut "repaired" "forged-log"
"$PY" - "$WORK/mut/forged-log" <<'PY'
import re, sys
d = sys.argv[1]
log_path = d + "/console.log"
log = open(log_path, encoding="utf-8").read()
log = re.sub(r"^APPLIANCE-RELEASE=.*$", "APPLIANCE-RELEASE=FORGED-RELEASE",
             log, flags=re.MULTILINE)
open(log_path, "w", encoding="utf-8").write(log)
PY
run_oracle 1 "good-looking handwritten log (forged release) REJECT" "$WORK/mut/forged-log"

# --- 7. truncated/malformed manifest -> ERROR ----------------------------------
copy_to_mut "repaired" "truncated"
printf '{"schema": "m08-manifest-v1", "linux": {' > "$WORK/mut/truncated/appliance.manifest.json"
run_oracle 2 "truncated/malformed manifest ERROR" "$WORK/mut/truncated"

# --- 8. missing artifact -> ERROR ----------------------------------------------
copy_to_mut "repaired" "missing-artifact"
rm -f "$WORK/mut/missing-artifact/zImage"
run_oracle 2 "missing kernel artifact ERROR" "$WORK/mut/missing-artifact"

# --- 9. wrong QEMU machine string ----------------------------------------------
copy_to_mut "repaired" "wrong-machine"
"$PY" - "$WORK/mut/wrong-machine/appliance.run.json" <<'PY'
import json, sys
p = sys.argv[1]
doc = json.load(open(p, encoding="utf-8"))
doc["qemu"]["machine"] = "versatilepb"
json.dump(doc, open(p, "w", encoding="utf-8"), indent=2)
open(p, "a", encoding="utf-8").write("\n")
PY
run_oracle 1 "wrong QEMU machine string REJECT" "$WORK/mut/wrong-machine"

# --- 10. non-cortex-a7 CPU ------------------------------------------------------
copy_to_mut "repaired" "wrong-cpu"
"$PY" - "$WORK/mut/wrong-cpu/appliance.run.json" <<'PY'
import json, sys
p = sys.argv[1]
doc = json.load(open(p, encoding="utf-8"))
doc["qemu"]["cpu"] = "cortex-a9"
json.dump(doc, open(p, "w", encoding="utf-8"), indent=2)
open(p, "a", encoding="utf-8").write("\n")
PY
run_oracle 1 "non-cortex-a7 CPU REJECT" "$WORK/mut/wrong-cpu"

# --- 11. highmem=on --------------------------------------------------------------
copy_to_mut "repaired" "highmem-on"
"$PY" - "$WORK/mut/highmem-on/appliance.run.json" <<'PY'
import json, sys
p = sys.argv[1]
doc = json.load(open(p, encoding="utf-8"))
doc["qemu"]["machine"] = "virt,highmem=on,gic-version=2"
json.dump(doc, open(p, "w", encoding="utf-8"), indent=2)
open(p, "a", encoding="utf-8").write("\n")
PY
run_oracle 1 "highmem=on REJECT" "$WORK/mut/highmem-on"

# --- 12. gic-version=3 -----------------------------------------------------------
copy_to_mut "repaired" "gic-version-3"
"$PY" - "$WORK/mut/gic-version-3/appliance.run.json" <<'PY'
import json, sys
p = sys.argv[1]
doc = json.load(open(p, encoding="utf-8"))
doc["qemu"]["machine"] = "virt,highmem=off,gic-version=3"
json.dump(doc, open(p, "w", encoding="utf-8"), indent=2)
open(p, "a", encoding="utf-8").write("\n")
PY
run_oracle 1 "gic-version=3 REJECT" "$WORK/mut/gic-version-3"

# --- 13. differing SMP/memory -----------------------------------------------------
copy_to_mut "repaired" "wrong-smp-mem"
"$PY" - "$WORK/mut/wrong-smp-mem/appliance.run.json" <<'PY'
import json, sys
p = sys.argv[1]
doc = json.load(open(p, encoding="utf-8"))
doc["qemu"]["smp"] = 2
doc["qemu"]["mem"] = "256M"
json.dump(doc, open(p, "w", encoding="utf-8"), indent=2)
open(p, "a", encoding="utf-8").write("\n")
PY
run_oracle 1 "differing SMP/memory REJECT" "$WORK/mut/wrong-smp-mem"

# --- 14. manifest declares filenames but no hashes --------------------------------
copy_to_mut "repaired" "no-hashes"
"$PY" - "$WORK/mut/no-hashes/appliance.manifest.json" <<'PY'
import json, sys
p = sys.argv[1]
doc = json.load(open(p, encoding="utf-8"))
del doc["linux"]["image"]["sha256"]
json.dump(doc, open(p, "w", encoding="utf-8"), indent=2)
open(p, "a", encoding="utf-8").write("\n")
PY
run_oracle 1 "manifest-only filenames with no hashes REJECT" "$WORK/mut/no-hashes"

# --- 15. run-record argv differing from the manifest/contract argv ----------------
copy_to_mut "repaired" "argv-differs"
"$PY" - "$WORK/mut/argv-differs/appliance.run.json" <<'PY'
import hashlib, json, shlex, sys
p = sys.argv[1]
doc = json.load(open(p, encoding="utf-8"))
doc["argv"][6] = "256M"  # executed -m differs from the manifest's 512M
doc["argv_fingerprint"] = hashlib.sha256(
    "\n".join(shlex.quote(a) for a in doc["argv"]).encode("utf-8")).hexdigest()
json.dump(doc, open(p, "w", encoding="utf-8"), indent=2)
open(p, "a", encoding="utf-8").write("\n")
PY
run_oracle 1 "run-record argv differing from manifest argv REJECT" "$WORK/mut/argv-differs"

echo "================================================================"
echo "=== ALL $PASSED / $TOTAL P3-M08 ORACLE REGRESSION CHECKS PASSED ==="
echo "================================================================"
