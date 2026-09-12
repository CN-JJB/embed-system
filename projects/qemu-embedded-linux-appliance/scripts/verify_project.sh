#!/bin/bash
# P3-M08 learner-safe project check (never grades hidden variants).
#
# Verifies packaging/format/safe invariants only:
#   1. sample manifest validates against m08-manifest-v1 (schema + pins,
#      hashes present in form, not bound to files on disk);
#   2. sample run record is well-formed (frozen argv shape, 64-hex
#      fingerprint, exact 4-token bootargs set, qemu dimensions);
#   3. final-image audit PASSES on a freshly materialised sample image
#      built from overlay/ (proves the audit path, not a real build);
#   4. fault workspaces + required sources/overlay files are present.
#
# Reviewer-gated paths (hidden seeds, oracles, grading fixtures) are never
# executed or imported here. Real QEMU boot is never attempted.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJ_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$PROJ_ROOT"

PY="${PYTHON:-python3}"
MANIFEST="fixtures/sample_manifest.json"
RUN="fixtures/sample_run.json"
OVERLAY="overlay"

echo "=================================================================="
echo "=== P3-M08 learner-safe project check                          ==="
echo "=================================================================="

# --- 1. manifest schema + pins + hash form --------------------------------
echo "--- [1/4] manifest schema (SYNTHETIC sample, files not bound) ---"
"$PY" scripts/manifest.py --validate "$MANIFEST"
echo "[PASS] manifest schema + pins + hash form"

# --- 2. run record well-formed ---------------------------------------------
echo "--- [2/4] run record well-formed ---"
"$PY" - "$RUN" <<'PY'
import json, sys
run = json.load(open(sys.argv[1], encoding="utf-8"))
assert run.get("schema") == "m08-run-v1", "run.schema must be m08-run-v1"
argv = run.get("argv", [])
assert isinstance(argv, list) and len(argv) >= 14, "argv too short"
for token in ("-machine", "-cpu", "-m", "-smp", "-nographic",
              "-kernel", "-initrd", "-append"):
    assert token in argv, f"argv lacks {token}"
mi = argv.index("-machine")
assert argv[mi + 1] == "virt,highmem=off,gic-version=2", "machine skew"
assert "highmem=on" not in argv[mi + 1], "highmem=on rejected"
assert argv[argv.index("-cpu") + 1] == "cortex-a7", "cpu skew"
assert argv[argv.index("-m") + 1] == "512M", "mem skew"
assert argv[argv.index("-smp") + 1] == "1", "smp skew"
fp = run.get("argv_fingerprint", "")
assert len(fp) == 64 and all(c in "0123456789abcdef" for c in fp), "fingerprint form"
boot = run.get("bootargs", "").split()
assert set(boot) == {"console=ttyAMA0,115200", "earlycon=pl011,0x09000000",
                      "rdinit=/sbin/init", "panic=1"} and len(boot) == 4, \
    f"bootargs exact 4-token set required, got {boot}"
qemu = run.get("qemu", {})
assert (qemu.get("machine"), qemu.get("cpu"), qemu.get("mem"), qemu.get("smp")) == \
    ("virt,highmem=off,gic-version=2", "cortex-a7", "512M", 1), "qemu dimensions"
print("[PASS] run record well-formed (frozen argv + 4-token bootargs)")
PY

# --- 3. image audit on a freshly materialised sample image ------------------
echo "--- [3/4] final-image audit on materialised sample image ---"
SAMPLE_WORK="build/verify-sample"
SAMPLE_IMG="$SAMPLE_WORK/sample-rootfs.cpio.gz"
rm -rf "$SAMPLE_WORK"
mkdir -p "$SAMPLE_WORK"
# Regression pin: the materialiser self-test enforces the newc header field
# layout (c_namesize at index 11, c_rdevminor at index 10) and round-trips
# entries through an independent reader, so a malformed archive cannot recur.
"$PY" scripts/materialise_sample_cpio.py --self-test
"$PY" scripts/materialise_sample_cpio.py --overlay "$OVERLAY" --out "$SAMPLE_IMG"
"$PY" scripts/audit_final_image.py --image "$SAMPLE_IMG" --overlay "$OVERLAY" --quiet
echo "[PASS] sample final-image audit (overlay.in-image / not-stale / no-decoy)"

# --- 4. required workspaces --------------------------------------------------
echo "--- [4/4] fault workspaces + sources ---"
for f in faults/fault-a-bootchain-rdinit-skew/README.md \
         faults/fault-b-userspace-sysfs/README.md \
         src/appliance-diag.c src/Makefile \
         overlay/etc/appliance-release overlay/etc/init.d/S99appliance-diag \
         BUILD_RUN_DEBUG.md SOURCE_LEDGER.md README.md \
         manifest.schema.json run.schema.json; do
    if [ ! -f "$f" ]; then
        echo "ERROR: required project file missing: $f" >&2
        exit 1
    fi
done
echo "[PASS] fault workspaces + sources present"

echo "=== P3-M08 LEARNER CHECK: PASS (static packaging only; no boot claimed) ==="
