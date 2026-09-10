#!/bin/bash
set -euo pipefail

# P3-M04 Trusted Candidate Manifest Runner (SINGLE SOURCE OF TRUTH)
#
# Executes EXACTLY the QEMU argv that scripts/parse_candidate_manifest.py
# derives from the candidate's data-only manifest, and records the normalized
# argv/provenance next to the captured console log. The machine, CPU, RAM,
# SMP, nographic and bootargs values used at runtime are therefore the
# candidate's own declared values: nothing is substituted by this runner.
#
# A submitted console log is only accepted as evidence together with the
# provenance file produced here (scripts/verify_candidate_runtime.sh).
#
# Usage: run_candidate_manifest.sh <manifest> <console-log> [provenance-file]
#
# Environment:
#   LINUX_SRC / REAL_ZIMAGE : pinned real kernel (default /tmp/linux-6.18.50)
#   INITRD                  : real BusyBox initramfs (default M03 real_rootfs)
#   QEMU_BIN                : qemu-system-arm
#   TIMEOUT_SEC             : wall-clock capture budget (default 60; the guest
#                             probe sequence needs ~27 s plus boot time)
#   MANIFEST_PROBE=0        : passive capture (no guest shell probes)

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
LINUX_DIR=$(cd "${M04_ROOT}/.." && pwd)

MANIFEST="${1:-}"
CONSOLE_LOG="${2:-}"
PROVENANCE="${3:-}"

if [ -z "$MANIFEST" ] || [ ! -f "$MANIFEST" ]; then
    echo "ERROR: Candidate manifest required: '${MANIFEST:-<empty>}'" >&2
    exit 1
fi
if [ -z "$CONSOLE_LOG" ]; then
    echo "ERROR: Console log output path required." >&2
    exit 1
fi
if [ -z "$PROVENANCE" ]; then
    PROVENANCE="${CONSOLE_LOG%.log}.argv"
fi

LINUX_SRC="${LINUX_SRC:-/tmp/linux-6.18.50}"
REAL_ZIMAGE="${REAL_ZIMAGE:-$LINUX_SRC/arch/arm/boot/zImage}"
INITRD="${INITRD:-$LINUX_DIR/07-minimal-rootfs-busybox-init/fixtures/build/real_rootfs.cpio.gz}"
QEMU_BIN="${QEMU_BIN:-qemu-system-arm}"
TIMEOUT_SEC="${TIMEOUT_SEC:-60}"

if [ ! -f "$REAL_ZIMAGE" ]; then
    echo "ERROR: Pinned real kernel zImage not found: $REAL_ZIMAGE" >&2
    echo "       Build it with: bash 06-kernel-build-boot/scripts/build_real_kernel.sh" >&2
    exit 1
fi
if [ ! -f "$INITRD" ]; then
    echo "ERROR: Real BusyBox initramfs not found: $INITRD" >&2
    echo "       Build it with: make -C 07-minimal-rootfs-busybox-init real-rootfs-package" >&2
    exit 1
fi
case "$INITRD" in
    *synthetic*)
        echo "REJECT: synthetic teaching fixture is not a valid runtime initramfs: $INITRD" >&2
        exit 2
        ;;
esac
if ! command -v "$QEMU_BIN" >/dev/null 2>&1; then
    echo "ERROR: '$QEMU_BIN' not found in PATH (runtime UNVERIFIED)." >&2
    exit 1
fi

# 1. Parse the candidate manifest: declarations -> normalized argv.
#    Parser stdout is captured in a file (its progress text goes to stdout, so
#    command substitution with a pipe would race under 'set -o pipefail').
PARSE_OUT=$(mktemp /tmp/m04_manifest_parse_XXXXXX.txt)
trap 'rm -f "$PARSE_OUT"' EXIT
set +e
python3 "$SCRIPT_DIR/parse_candidate_manifest.py" \
    --manifest "$MANIFEST" \
    --kernel "$REAL_ZIMAGE" \
    --initrd "$INITRD" \
    --qemu-bin "$QEMU_BIN" \
    --require-executables > "$PARSE_OUT" 2>&1
PARSE_RC=$?
set -e
if [ "$PARSE_RC" -ne 0 ]; then
    echo "REJECT: candidate manifest failed parsing/normalization:" >&2
    sed 's/^/  /' "$PARSE_OUT" >&2
    exit 2
fi

kv() { grep -E "^$1=" "$PARSE_OUT" | head -n 1 | cut -d= -f2-; }
MACHINE=$(kv MACHINE); CPU=$(kv CPU); MEM=$(kv MEM); SMP=$(kv SMP)
BOOTARGS=$(kv BOOTARGS); ARGV_FINGERPRINT=$(kv ARGV_FINGERPRINT)
KERNEL_PATH=$(kv KERNEL); INITRD_PATH=$(kv INITRD)

# Reconstruct the normalized argv with shell-quoting semantics identical to
# the parser's provenance rendering (single shlex.quote round-trip).
mapfile -t QEMU_ARGV < <(python3 - "$PARSE_OUT" <<'PY'
import shlex, sys
lines = open(sys.argv[1], encoding='utf-8').read().splitlines()
try:
    begin = lines.index('ARGV_BEGIN')
    end = lines.index('ARGV_END')
except ValueError:
    sys.exit("normalized argv block missing")
for tok in shlex.split(" ".join(lines[begin + 1:end])):
    print(tok)
PY
)

if [ "${#QEMU_ARGV[@]}" -lt 10 ]; then
    echo "ERROR: normalized QEMU argv reconstruction failed (${#QEMU_ARGV[@]} tokens)." >&2
    exit 1
fi

# 2. Record provenance BEFORE execution (this is the argv that is executed).
QEMU_PATH=$(command -v "$QEMU_BIN")
QEMU_SHA=$(sha256sum "$QEMU_PATH" | awk '{print $1}')
MANIFEST_SHA=$(sha256sum "$MANIFEST" | awk '{print $1}')
KERNEL_SHA=$(sha256sum "$KERNEL_PATH" | awk '{print $1}')
INITRD_SHA=$(sha256sum "$INITRD_PATH" | awk '{print $1}')
mkdir -p "$(dirname "$PROVENANCE")"
{
    echo "# P3-M04 executed-candidate launch provenance (reviewer-binding)."
    echo "MANIFEST=$MANIFEST"
    echo "MANIFEST_SHA256=$MANIFEST_SHA"
    echo "MACHINE=$MACHINE"
    echo "CPU=$CPU"
    echo "MEM=$MEM"
    echo "SMP=$SMP"
    echo "NOGRAPHIC=true"
    echo "BOOTARGS=$BOOTARGS"
    echo "KERNEL=$KERNEL_PATH"
    echo "KERNEL_SHA256=$KERNEL_SHA"
    echo "INITRD=$INITRD_PATH"
    echo "INITRD_SHA256=$INITRD_SHA"
    echo "QEMU_BIN=$QEMU_PATH"
    echo "QEMU_SHA256=$QEMU_SHA"
    echo "ARGV_FINGERPRINT=$ARGV_FINGERPRINT"
    echo "TIMEOUT_SEC=$TIMEOUT_SEC"
    echo "ARGV_BEGIN"
    sed -n '/^ARGV_BEGIN$/,/^ARGV_END$/p' "$PARSE_OUT" | sed '1d;$d'
    echo "ARGV_END"
} > "$PROVENANCE"

# 3. Execute exactly that configuration.
rm -f "$CONSOLE_LOG"
MANIFEST_PROBE="${MANIFEST_PROBE:-1}"
set +e
if [ "$MANIFEST_PROBE" = "0" ]; then
    timeout "${TIMEOUT_SEC}s" "${QEMU_ARGV[@]}" \
        < /dev/null > "$CONSOLE_LOG" 2>&1
else
    # Guest userspace probes. The guest shell consumes stdin only after the
    # keystroke that triggers BusyBox init's 'askfirst' console activation, so
    # this sequencing budget (~27 s) must fit inside TIMEOUT_SEC.
    ( sleep 6; echo "busybox | head -n 2"; sleep 2; echo "ps"; \
      sleep 2; echo "cat /proc/mounts"; sleep 2 ) \
        | timeout "${TIMEOUT_SEC}s" "${QEMU_ARGV[@]}" > "$CONSOLE_LOG" 2>&1
fi
RC=$?
set -e

echo "[MANIFEST-RUNNER] Executed candidate configuration exactly as declared."
echo "[MANIFEST-RUNNER] machine=$MACHINE cpu=$CPU mem=$MEM smp=$SMP nographic=true"
echo "[MANIFEST-RUNNER] bootargs=$BOOTARGS"
echo "[MANIFEST-RUNNER] argv fingerprint=$ARGV_FINGERPRINT"
echo "[MANIFEST-RUNNER] console log: $CONSOLE_LOG (qemu exit $RC)"
echo "[MANIFEST-RUNNER] provenance:  $PROVENANCE"
