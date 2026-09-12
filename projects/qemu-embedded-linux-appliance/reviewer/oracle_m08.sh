#!/usr/bin/env bash
# P3-M08 Assessment Reference Oracle (REVIEWER-ONLY)
#
# Grades a candidate appliance provenance/run record (manifest + run record +
# console log + the actual artifact bytes they reference) against the
# reviewer-only complete contract and the hidden seed mapping.
#
# The oracle is the only component that knows the hidden seed sentinels and the
# complete pin contract. The learner-safe `make check` only validates a labelled
# SYNTHETIC sample; the runtime binder grades argv/markers/hashes but does NOT
# grade pins and treats the hidden DT-MODEL sentinel as a non-empty value.
#
# Exit taxonomy (matches oracle_m07.sh):
#   0 = candidate satisfies the canonical contract (ACCEPT)
#   1 = well-formed candidate that violates a semantic invariant (REJECT)
#   2 = malformed/unreadable input or a missing tool (ERROR, never a REJECT)
#
# Usage:
#   oracle_m08.sh <candidate-dir> [assessment]
#     candidate-dir: directory containing appliance.manifest.json,
#                    appliance.run.json, console.log, and the artifact bytes
#                    (zImage, rootfs.cpio.gz, optionally qemu-virt.dtb).
#     assessment: gate | challenge (default gate; both use m08_seed.json here)
#
# Never reference or copy this file into learner-facing material.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJ_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$PROJ_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python
if ! command -v "$PY" >/dev/null 2>&1; then
    echo "FATAL: no python interpreter found (missing tool: tried python3/python)" >&2
    echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
    exit 2
fi

COMPLETE="reviewer/reference/appliance_complete.json"
SEED_FILE="reviewer/reference/m08_seed.json"
OVERLAY="overlay"

ASSESSMENT="gate"
CANDIDATE=""
for arg in "$@"; do
    case "$arg" in
        gate|challenge) ASSESSMENT="$arg" ;;
        *) if [ -z "$CANDIDATE" ]; then CANDIDATE="$arg"; fi ;;
    esac
done

[ -n "$CANDIDATE" ] || CANDIDATE="${ASSESSMENT}/build/candidate"

MANIFEST="$CANDIDATE/appliance.manifest.json"
RUN="$CANDIDATE/appliance.run.json"
LOG="$CANDIDATE/console.log"

FAILURES=0
REJECTED=0
fail() { echo "[FAIL] ASSESSMENT MISMATCH: $1" >&2; FAILURES=$((FAILURES + 1)); REJECTED=1; }

echo "=================================================================="
echo "=== P3-M08 Assessment Reference Oracle                         ==="
echo "=== Assessment: $ASSESSMENT"
echo "=== Candidate : $CANDIDATE"
echo "=================================================================="

# --- presence classification --------------------------------------------------
if [ ! -d "$CANDIDATE" ]; then
    fail "candidate directory missing: $CANDIDATE"
    echo "=== ASSESSMENT REFERENCE REJECT ===" >&2
    exit 1
fi
if [ ! -f "$COMPLETE" ]; then
    echo "FATAL: complete contract missing: $COMPLETE" >&2
    echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
    exit 2
fi
if [ ! -f "$SEED_FILE" ]; then
    echo "FATAL: seed mapping missing: $SEED_FILE" >&2
    echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
    exit 2
fi
if [ ! -f "$MANIFEST" ]; then
    fail "candidate manifest missing: $MANIFEST"
    echo "=== ASSESSMENT REFERENCE REJECT ===" >&2
    exit 1
fi
if [ ! -f "$RUN" ]; then
    fail "candidate run record missing: $RUN"
    echo "=== ASSESSMENT REFERENCE REJECT ===" >&2
    exit 1
fi
if [ ! -f "$LOG" ]; then
    fail "candidate console log missing: $LOG"
    echo "=== ASSESSMENT REFERENCE REJECT ===" >&2
    exit 1
fi

# --- 0. parseability: truncated/malformed => ERROR, never REJECT ---------------
if ! "$PY" - "$MANIFEST" "$RUN" "$LOG" <<'PY' >/dev/null 2>&1
import json
import sys
json.load(open(sys.argv[1], "r", encoding="utf-8"))
json.load(open(sys.argv[2], "r", encoding="utf-8"))
open(sys.argv[3], "r", encoding="utf-8").read()
PY
then
    echo "ERROR: candidate inputs are not parseable (truncated/malformed)" >&2
    echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
    exit 2
fi

# --- 1. complete-contract + pin + seed grade (self-contained semantic grade) ---
# Capture the grader's stdout via a temp file (not command substitution) so the
# heredoc is not nested inside $(...), which trips a bash 5.2 parse warning.
mkdir -p build/reviewer-m08-oracle
CONTRACT_TMP="build/reviewer-m08-oracle/.contract-grade.txt"
set +e
"$PY" - "$MANIFEST" "$RUN" "$LOG" "$COMPLETE" "$SEED_FILE" >"$CONTRACT_TMP" 2>&1 <<'PY'
import json
import re
import sys

manifest_path, run_path, log_path, complete_path, seed_path = sys.argv[1:6]

manifest = json.load(open(manifest_path, encoding="utf-8"))
run = json.load(open(run_path, encoding="utf-8"))
log = open(log_path, encoding="utf-8").read()
complete = json.load(open(complete_path, encoding="utf-8"))
seed = json.load(open(seed_path, encoding="utf-8"))

inv = complete.get("invariants", {}) if isinstance(complete, dict) else {}
pins = inv.get("pins", {}) if isinstance(inv, dict) else {}
machine = inv.get("machine")
cpu = inv.get("cpu")
mem = inv.get("mem")
smp = inv.get("smp")
bootargs_set = set(inv.get("bootargs", []))
markers = inv.get("markers", [])
log_floor = inv.get("log_floor_lines", 60)
hidden = set(seed.get("hidden_signatures", [])) if isinstance(seed, dict) else set()

results = {}
failed = []

def check(ident, ok, detail):
    results[ident] = bool(ok)
    print(("[PASS] " if ok else "[FAIL] ") + ident + " -- " + detail)
    if not ok:
        failed.append(ident)

qc = manifest.get("qemu_canonical", {}) if isinstance(manifest, dict) else {}
rq = run.get("qemu", {}) if isinstance(run, dict) else {}

# frozen machine contract (manifest + run record agree with the reviewer contract)
check("machine", qc.get("machine") == machine and rq.get("machine") == machine,
      "machine=%r/%r expected %r" % (qc.get("machine"), rq.get("machine"), machine))
check("cpu", qc.get("cpu") == cpu and rq.get("cpu") == cpu,
      "cpu=%r/%r expected %r" % (qc.get("cpu"), rq.get("cpu"), cpu))
check("mem", qc.get("mem") == mem and rq.get("mem") == mem,
      "mem=%r/%r expected %r" % (qc.get("mem"), rq.get("mem"), mem))
check("smp", qc.get("smp") == smp and rq.get("smp") == smp,
      "smp=%r/%r expected %r" % (qc.get("smp"), rq.get("smp"), smp))

# complete pin contract (version/tag/commit identities)
linux = manifest.get("linux", {}) if isinstance(manifest, dict) else {}
lp = pins.get("linux", {})
check("pin.linux", linux.get("version") == lp.get("version")
      and linux.get("tag") == lp.get("tag") and linux.get("commit") == lp.get("commit"),
      "linux pin (version/tag/commit) matches the complete contract")
qp = pins.get("qemu", {})
check("pin.qemu", qc.get("version") == qp.get("version")
      and qc.get("tag") == qp.get("tag") and qc.get("commit") == qp.get("commit"),
      "qemu pin (version/tag/commit) matches the complete contract")
bb = manifest.get("busybox", {})
bp = pins.get("busybox", {})
check("pin.busybox", bb.get("version") == bp.get("version")
      and bb.get("commit") == bp.get("commit"), "busybox pin matches")
br = manifest.get("buildroot", {})
brp = pins.get("buildroot", {})
check("pin.buildroot", br.get("version") == brp.get("version")
      and br.get("tag") == brp.get("tag") and br.get("commit") == brp.get("commit"),
      "buildroot pin matches")
dtc = manifest.get("dtc", {})
dtcp = pins.get("dtc", {})
check("pin.dtc", dtc.get("version") == dtcp.get("version")
      and dtc.get("commit") == dtcp.get("commit"), "dtc pin matches")
ds = manifest.get("dtspec", {})
dsp = pins.get("dtspec", {})
check("pin.dtspec", ds.get("version") == dsp.get("version")
      and ds.get("commit") == dsp.get("commit"), "dtspec pin matches")
tc = manifest.get("toolchain", {})
check("pin.toolchain", tc.get("sha256") == pins.get("toolchain_package_sha256"),
      "toolchain package sha256 pin matches")

# exact 4-token bootargs set in the run record
run_tokens = run.get("bootargs", "").split()
check("bootargs.exact-set",
      set(run_tokens) == bootargs_set and len(run_tokens) == len(bootargs_set),
      "run bootargs %r must be exactly the %d-token frozen set"
      % (run_tokens, len(bootargs_set)))

# exact 4-token bootargs set in the guest cmdline
cm = re.search(r"Kernel command line:\s*(.*)$", log.replace("\r", ""), re.MULTILINE)
if cm is None:
    check("log.cmdline-exact-set", False, "no 'Kernel command line:' line in capture")
else:
    logged = cm.group(1).strip().split()
    check("log.cmdline-exact-set",
          set(logged) == bootargs_set and len(logged) == len(bootargs_set),
          "logged cmdline %r must equal the frozen set" % (logged,))

# boot/diag markers present
missing_markers = [mk for mk in markers if mk not in log]
check("markers", not missing_markers,
      "all required boot/diag markers present" if not missing_markers
      else "missing markers: %r" % (missing_markers,))

# DT-MODEL must be a real model, not UNAVAILABLE/EMPTY/empty nor a hidden sentinel
dm = re.search(r"^DT-MODEL=(.*)$", log, re.MULTILINE)
if dm is None:
    check("guest.dt-model", False, "no DT-MODEL line")
else:
    value = dm.group(1).strip()
    ok = value not in ("", "UNAVAILABLE", "EMPTY") and value not in hidden
    check("guest.dt-model", ok,
          "DT-MODEL %r is a real model (not UNAVAILABLE/hidden)" % (value,))

# execution outcome: QEMU failure / timeout must never masquerade as success
exit_code = run.get("qemu_exit_code")
timed_out = bool(run.get("timed_out"))
if exit_code is None:
    check("qemu.execution", False, "qemu_exit_code is null (provenance not finalised)")
else:
    ok = isinstance(exit_code, int) and exit_code in (0, 124)
    if timed_out and exit_code != 124:
        ok = False
    if exit_code == 124 and not timed_out:
        ok = False
    check("qemu.execution", ok,
          "qemu_exit_code=%r timed_out=%r (must be 0 or 124; 124 <=> timed_out)"
          % (exit_code, timed_out))

# console log floor
nlines = len(log.splitlines())
check("log.length", nlines >= log_floor, "%d line(s) (floor %d)" % (nlines, log_floor))

# run <-> manifest hash agreement (file-byte binding delegated to the binder below)
rk = run.get("kernel", {})
mk = manifest.get("linux", {}).get("image", {}) if isinstance(manifest.get("linux"), dict) else {}
check("binding.kernel-manifest", rk.get("sha256") == mk.get("sha256"),
      "run kernel sha256 equals manifest linux.image sha256")
rr = run.get("rootfs", {})
mr = manifest.get("rootfs", {})
check("binding.rootfs-manifest", rr.get("sha256") == mr.get("sha256"),
      "run rootfs sha256 equals manifest rootfs sha256")
if (run.get("dt") or {}).get("source") == "explicit":
    rd = run.get("dt", {})
    md = manifest.get("dt", {})
    check("binding.dtb-manifest", rd.get("sha256") == md.get("sha256"),
          "run DTB sha256 equals manifest dt sha256 (stale DTB rejected)")

# seeded invariant families specifically must hold
for ident in seed.get("oracle_invariants", []) if isinstance(seed, dict) else []:
    ok = results.get(ident, False)
    if ok:
        print("[PASS] seeded invariant satisfied: " + ident)
    else:
        print("[FAIL] seeded invariant still violated: " + ident)
        failed.append(ident)

print("-" * 66)
if failed:
    print("SEMANTIC GRADE: %d invariant(s) violated: %r" % (len(failed), failed))
    sys.exit(1)
print("SEMANTIC GRADE: complete contract + pins + seed all hold")
sys.exit(0)
PY
CONTRACT_RC=$?
CONTRACT_OUTPUT="$(cat "$CONTRACT_TMP")"
rm -f "$CONTRACT_TMP"
set -e
echo "$CONTRACT_OUTPUT"
if [ "$CONTRACT_RC" -eq 2 ]; then
    echo "ERROR: candidate could not be evaluated" >&2
    echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
    exit 2
fi
if [ "$CONTRACT_RC" -ne 0 ]; then
    REJECTED=1
    FAILURES=$((FAILURES + $(echo "$CONTRACT_OUTPUT" | grep -c '^\[FAIL\]' || true)))
fi

# --- 2. manifest binding: schema + pins + artifact-byte hashes ------------------
set +e
MANIFEST_OUTPUT=$("$PY" scripts/manifest.py --validate "$MANIFEST" --check-files 2>&1)
MANIFEST_RC=$?
set -e
if [ "$MANIFEST_RC" -eq 2 ]; then
    echo "$MANIFEST_OUTPUT" >&2
    echo "ERROR: manifest could not be bound to files on disk" >&2
    echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
    exit 2
fi
if [ "$MANIFEST_RC" -ne 0 ]; then
    echo "$MANIFEST_OUTPUT" >&2
    fail "manifest violates the canonical contract (schema/pins/hash mismatch)"
fi

# --- 3. runtime binding: argv + markers + overlay + triple-hash -----------------
set +e
BIND_OUTPUT=$("$PY" scripts/verify_m08_runtime.py \
    --manifest "$MANIFEST" --run "$RUN" --log "$LOG" --overlay "$OVERLAY" 2>&1)
BIND_RC=$?
set -e
if [ "$BIND_RC" -eq 2 ]; then
    echo "$BIND_OUTPUT" >&2
    echo "ERROR: runtime evidence could not be evaluated" >&2
    echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
    exit 2
fi
if [ "$BIND_RC" -ne 0 ]; then
    echo "$BIND_OUTPUT" | grep -E '^\[FAIL\]' | head -n 8 >&2 || true
    fail "runtime evidence is not bound to the audited artifacts (argv/hash/marker skew)"
else
    echo "[PASS] runtime evidence bound (argv + markers + overlay + triple-hash)"
fi

echo "------------------------------------------------------------------"
if [ "$REJECTED" -ne 0 ]; then
    echo "=== ASSESSMENT REFERENCE REJECT: $FAILURES mismatch(es) ===" >&2
    exit 1
fi
echo "=== ASSESSMENT REFERENCE PASS (M08 $ASSESSMENT candidate) ==="
exit 0
