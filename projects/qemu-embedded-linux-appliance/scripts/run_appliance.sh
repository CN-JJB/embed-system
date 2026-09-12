#!/bin/bash
# P3-M08 appliance launch harness (fail-closed, non-interactive).
#
# Builds the single frozen Contract-A argv from the manifest, records
# provenance BEFORE execution, captures QEMU version + hashes, runs the
# capture, then finalises the run record with the QEMU exit code.
#
# Frozen argv:
#   qemu-system-arm -machine virt,highmem=off,gic-version=2 -cpu cortex-a7
#     -m 512M -smp 1 -nographic -kernel <zImage> [-dtb <explicit>]
#     -initrd <rootfs.cpio.gz>
#     -append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/sbin/init panic=1"
# DT dual-mode: manifest dt.source=qemu-generated -> no -dtb;
#               dt.source=explicit -> -dtb <path> (SHA256-bound).
#
# Exit taxonomy (fail-closed; exit 0 requires positive guest evidence):
#   0   capture-done AND guest success marker present (APPLIANCE-DIAG-END)
#   1   ERROR (bad usage / manifest validation failure / missing python3)
#   2   LAUNCH/RUNTIME-FAIL (missing kernel/initrd/dtb/QEMU, or QEMU exited non-zero)
#   3   GUEST-MARKER-ABSENT (QEMU exited 0 but no APPLIANCE-DIAG-END captured)
#   124 TIMEOUT
# This script NEVER prints [OK]/[PASS]/VERIFIED. It reports the QEMU return
# code and the log pointer; the richer boot verdict still belongs to
# verify_m08_runtime.py.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJ_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

MANIFEST=""
OUT_LOG=""
OUT_RUN=""
TIMEOUT_SEC="${TIMEOUT_SEC:-120}"
BR_OUTPUT=""
CLI_KERNEL=""
CLI_INITRD=""
CLI_DTB=""
QEMU_BIN="${QEMU_BIN:-qemu-system-arm}"

usage() {
    echo "usage: run_appliance.sh --manifest MANIFEST --log LOG --run RUN.json [options]" >&2
    echo "  options: --timeout SEC --output BR_OUTPUT_DIR --kernel K --initrd I --dtb D --qemu-bin Q" >&2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --manifest) MANIFEST="${2:-}"; shift 2 ;;
        --log) OUT_LOG="${2:-}"; shift 2 ;;
        --run) OUT_RUN="${2:-}"; shift 2 ;;
        --timeout) TIMEOUT_SEC="${2:-}"; shift 2 ;;
        --output) BR_OUTPUT="${2:-}"; shift 2 ;;
        --kernel) CLI_KERNEL="${2:-}"; shift 2 ;;
        --initrd) CLI_INITRD="${2:-}"; shift 2 ;;
        --dtb) CLI_DTB="${2:-}"; shift 2 ;;
        --qemu-bin) QEMU_BIN="${2:-}"; shift 2 ;;
        -h|--help) usage; exit 1 ;;
        *) echo "ERROR: unknown argument: $1" >&2; usage; exit 1 ;;
    esac
done

if [ -z "$MANIFEST" ] || [ ! -f "$MANIFEST" ]; then
    echo "ERROR: --manifest MANIFEST is required and must exist." >&2
    exit 1
fi
if [ -z "$OUT_LOG" ]; then
    echo "ERROR: --log LOG is required." >&2
    exit 1
fi
if [ -z "$OUT_RUN" ]; then
    echo "ERROR: --run RUN.json is required." >&2
    exit 1
fi

PY="${PYTHON:-python3}"
if ! command -v "$PY" >/dev/null 2>&1; then
    echo "ERROR: python3 not found (manifest validation needs it)." >&2
    exit 1
fi

# 1. Manifest must validate before anything is executed.
if ! "$PY" "$SCRIPT_DIR/manifest.py" --validate "$MANIFEST" >/dev/null; then
    echo "ERROR: manifest failed validation; refusing to launch." >&2
    exit 1
fi

# 2. Resolve kernel / initrd / dtb (CLI > env > manifest > --output/images).
MANIFEST_DIR=$(cd "$(dirname "$MANIFEST")" && pwd)
pick_manifest() { "$PY" - "$MANIFEST" "$1" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
node = data
for key in sys.argv[2].split("."):
    node = node.get(key, {})
if isinstance(node, str):
    print(node)
elif isinstance(node, bool):
    print("true" if node else "false")
elif isinstance(node, (int, float)):
    print(node)
else:
    print("")
PY
}

M_KERNEL_REL=$(pick_manifest "linux.image.path")
M_ROOTFS_REL=$(pick_manifest "rootfs.path")
M_DT_SOURCE=$(pick_manifest "dt.source")
M_DT_REL=$(pick_manifest "dt.path")
M_MACHINE=$(pick_manifest "qemu_canonical.machine")
M_CPU=$(pick_manifest "qemu_canonical.cpu")
M_MEM=$(pick_manifest "qemu_canonical.mem")
M_SMP=$(pick_manifest "qemu_canonical.smp")

resolve_rel() {
    local rel="$1"
    if [ -z "$rel" ]; then echo ""; return; fi
    case "$rel" in
        /*) echo "$rel" ;;
        *) echo "$MANIFEST_DIR/$rel" ;;
    esac
}

KERNEL="${CLI_KERNEL:-${KERNEL:-}}"
[ -n "$KERNEL" ] || KERNEL=$(resolve_rel "$M_KERNEL_REL")
INITRD="${CLI_INITRD:-${INITRD:-}}"
[ -n "$INITRD" ] || INITRD=$(resolve_rel "$M_ROOTFS_REL")
DTB="${CLI_DTB:-${DTB:-}}"
if [ -z "$DTB" ] && [ "$M_DT_SOURCE" = "explicit" ]; then
    DTB=$(resolve_rel "$M_DT_REL")
fi

# Primary path is Buildroot image reuse: honour --output/images when given.
if [ -n "$BR_OUTPUT" ] && [ -d "$BR_OUTPUT/images" ]; then
    for cand in "$BR_OUTPUT/images/zImage" "$BR_OUTPUT/images/Image"; do
        if [ -f "$cand" ] && [ ! -f "$KERNEL" ]; then KERNEL="$cand"; fi
    done
    for cand in "$BR_OUTPUT/images/rootfs.cpio.gz" "$BR_OUTPUT/images/rootfs.cpio"; do
        if [ -f "$cand" ] && [ ! -f "$INITRD" ]; then INITRD="$cand"; fi
    done
    if [ "$M_DT_SOURCE" = "explicit" ] && [ ! -f "$DTB" ]; then
        for cand in "$BR_OUTPUT/images/"*.dtb; do
            [ -f "$cand" ] && DTB="$cand" && break
        done
    fi
fi

if [ ! -f "$KERNEL" ]; then
    echo "ERROR: kernel image not found: ${KERNEL:-<empty>} (LAUNCH-FAIL)." >&2
    exit 2
fi
if [ ! -f "$INITRD" ]; then
    echo "ERROR: rootfs image not found: ${INITRD:-<empty>} (LAUNCH-FAIL)." >&2
    exit 2
fi
if [ "$M_DT_SOURCE" = "explicit" ] && [ ! -f "$DTB" ]; then
    echo "ERROR: explicit DTB required but not found: ${DTB:-<empty>} (LAUNCH-FAIL)." >&2
    exit 2
fi
if [ "$M_DT_SOURCE" != "qemu-generated" ] && [ "$M_DT_SOURCE" != "explicit" ]; then
    echo "ERROR: manifest dt.source must be qemu-generated|explicit." >&2
    exit 1
fi

if ! command -v "$QEMU_BIN" >/dev/null 2>&1; then
    echo "ERROR: QEMU binary not found: $QEMU_BIN (LAUNCH-FAIL)." >&2
    exit 2
fi
QEMU_PATH=$(command -v "$QEMU_BIN")
QEMU_VER=$("$QEMU_PATH" --version 2>/dev/null | head -n 1 || echo "unknown")

BOOTARGS="console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/sbin/init panic=1"

KERNEL_SHA=$(sha256sum "$KERNEL" | awk '{print $1}')
INITRD_SHA=$(sha256sum "$INITRD" | awk '{print $1}')
DTB_SHA=""
if [ "$M_DT_SOURCE" = "explicit" ]; then
    DTB_SHA=$(sha256sum "$DTB" | awk '{print $1}')
fi

# 3. Build the frozen argv.
ARGV=("$QEMU_PATH" -machine "$M_MACHINE" -cpu "$M_CPU" -m "$M_MEM" -smp "$M_SMP" -nographic -kernel "$KERNEL")
if [ "$M_DT_SOURCE" = "explicit" ]; then
    ARGV+=(-dtb "$DTB")
fi
ARGV+=(-initrd "$INITRD" -append "$BOOTARGS")

FINGERPRINT=$("$PY" - "${ARGV[@]}" <<'PY'
import hashlib, shlex, sys
print(hashlib.sha256("\n".join(shlex.quote(a) for a in sys.argv[1:]).encode()).hexdigest())
PY
)

mkdir -p "$(dirname "$OUT_LOG")" "$(dirname "$OUT_RUN")"

# 4. Provenance BEFORE execution (this exact argv is what runs).
# Write the pre-execution run record via python for safe JSON quoting.

# Build JSON with python to avoid shell-quoting hazards.
ARGV_JSON_FILE=$(mktemp /tmp/m08_argv_XXXXXX.json)
printf '%s\n' "${ARGV[@]}" | "$PY" -c "import json,sys; print(json.dumps([l.rstrip(chr(10)) for l in sys.stdin]))" > "$ARGV_JSON_FILE"
"$PY" - "$ARGV_JSON_FILE" "$OUT_RUN" "$QEMU_VER" "$FINGERPRINT" "$M_MACHINE" "$M_CPU" "$M_MEM" "$M_SMP" "$KERNEL" "$KERNEL_SHA" "$M_DT_SOURCE" "${DTB:-}" "${DTB_SHA:-}" "$INITRD" "$INITRD_SHA" "$BOOTARGS" "$TIMEOUT_SEC" "$OUT_LOG" <<'PY'
import json, sys
(argv_file, out_run, qemu_ver, fingerprint, machine, cpu, mem, smp,
 kernel, kernel_sha, dt_source, dtb, dtb_sha,
 initrd, initrd_sha, bootargs, timeout_sec, out_log) = sys.argv[1:]
argv = json.load(open(argv_file, encoding="utf-8"))
doc = {
    "schema": "m08-run-v1",
    "argv": argv,
    "argv_fingerprint": fingerprint,
    "qemu": {"machine": machine, "cpu": cpu, "mem": mem,
              "smp": int(smp), "version_actual": qemu_ver,
              "version_canonical": "11.1.1", "canonical_claim": False},
    "kernel": {"path": kernel, "sha256": kernel_sha},
    "dt": ({"source": "explicit", "path": dtb, "sha256": dtb_sha}
           if dt_source == "explicit" else {"source": "qemu-generated"}),
    "rootfs": {"path": initrd, "sha256": initrd_sha},
    "bootargs": bootargs,
    "timeout_sec": int(timeout_sec),
    "qemu_exit_code": None,
    "timed_out": False,
    "console_log": out_log,
    "repo": {"branch": "phase-3/m07-m08-arch-appliance"},
}
json.dump(doc, open(out_run, "w", encoding="utf-8"), indent=2)
open(out_run, "a", encoding="utf-8").write("\n")
PY
rm -f "$ARGV_JSON_FILE"

echo "[RUNNER] provenance recorded before execution: $OUT_RUN"
echo "[RUNNER] qemu: $QEMU_VER"

# 5. Execute exactly that argv.
rm -f "$OUT_LOG"
set +e
if command -v timeout >/dev/null 2>&1; then
    timeout "${TIMEOUT_SEC}s" "${ARGV[@]}" </dev/null >"$OUT_LOG" 2>&1
    QEMU_RC=$?
else
    "${ARGV[@]}" </dev/null >"$OUT_LOG" 2>&1 &
    QPID=$!
    ( sleep "$TIMEOUT_SEC"; kill "$QPID" 2>/dev/null ) &
    wait "$QPID"
    QEMU_RC=$?
fi
set -e

TIMED_OUT="false"
FINAL_RC=0
if [ "$QEMU_RC" -eq 124 ]; then
    TIMED_OUT="true"
fi

# 6. Finalise the run record with the capture outcome.
"$PY" - "$OUT_RUN" "$QEMU_RC" "$TIMED_OUT" <<'PY'
import json, sys
path, rc, timed = sys.argv[1], int(sys.argv[2]), sys.argv[3] == "true"
doc = json.load(open(path, encoding="utf-8"))
doc["qemu_exit_code"] = rc
doc["timed_out"] = timed
json.dump(doc, open(path, "w", encoding="utf-8"), indent=2)
open(path, "a", encoding="utf-8").write("\n")
PY

echo "[RUNNER] qemu exit code: $QEMU_RC"
echo "[RUNNER] console log: $OUT_LOG"
echo "[RUNNER] run record: $OUT_RUN"

# 7. Fail-closed classification. Exit 0 requires positive guest evidence:
#    the captured log must contain the diagnostic completion marker. Anything
#    else -- timeout, non-zero QEMU exit, or a clean exit with no marker --
#    is a non-zero failure. No [OK]/[PASS]/VERIFIED is ever printed here.
GUEST_SUCCESS_MARKER="APPLIANCE-DIAG-END"

if [ "$QEMU_RC" -eq 124 ]; then
    echo "[RUNNER] capture timed out after ${TIMEOUT_SEC}s (TIMEOUT)." >&2
    exit 124
fi
if [ "$QEMU_RC" -ne 0 ]; then
    echo "[RUNNER] QEMU exited non-zero (rc=$QEMU_RC) (LAUNCH/RUNTIME-FAIL)." >&2
    exit 2
fi
if [ -f "$OUT_LOG" ] && grep -q "$GUEST_SUCCESS_MARKER" "$OUT_LOG"; then
    echo "[RUNNER] capture-done: guest success marker present ($GUEST_SUCCESS_MARKER)."
    exit 0
fi
echo "[RUNNER] guest success marker absent ($GUEST_SUCCESS_MARKER not found in capture) (GUEST-MARKER-ABSENT)." >&2
exit 3
