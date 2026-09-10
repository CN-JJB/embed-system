#!/bin/bash
set -euo pipefail

# P3-M03 Assessment Reference Oracle (REVIEWER-ONLY)
#
# Grades a learner's repaired candidate rootfs (directory, plus the packaged
# archive) against the canonical production-init contract. This file is the
# single source of truth for the scored expectations and must never be
# referenced by or copied into learner-facing material.
#
# The scored capability is PRODUCTION REAL-BUSYBOX INIT:
#   - the candidate's multicall/init provider must be a real BusyBox 1.36.1
#     artifact (a synthetic multicall or any non-BusyBox binary is rejected);
#   - /sbin/init must resolve to that real BusyBox binary;
#   - /etc/inittab must drive a sysinit rcS plus an askfirst console shell;
#   - /etc/init.d/rcS must actively mount proc/sys/dev.
# Static grading covers artifact identity and contract; the packaged archive's
# runtime behaviour is graded by review of the fresh candidate-bound QEMU
# capture produced by scripts/run_real_busybox_candidate.sh and verified by
# scripts/verify_busybox_candidate_runtime.sh.
#
# Usage: oracle_m03.sh <candidate-rootfs-dir> [candidate-archive.cpio.gz]

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

CANDIDATE="${1:-$M03_ROOT/gate/build/candidate_rootfs}"
ARCHIVE="${2:-}"

FAILURES=0
fail() { echo "[FAIL] ASSESSMENT MISMATCH: $1" >&2; FAILURES=$((FAILURES + 1)); }

echo "=================================================================="
echo "=== P3-M03 Assessment Reference Oracle                         ==="
echo "=== Candidate: $CANDIDATE"
[ -n "$ARCHIVE" ] && echo "=== Archive:   $ARCHIVE"
echo "=================================================================="

[ -d "$CANDIDATE" ] || { fail "candidate rootfs directory missing: $CANDIDATE"; echo "=== ASSESSMENT REFERENCE REJECT ===" >&2; exit 1; }

# 1. Generic structure + active mount semantics.
if ! bash "$M03_ROOT/scripts/verify_rootfs_structure.sh" "$CANDIDATE" >/dev/null 2>&1; then
    fail "candidate fails rootfs structure / active-mount contract"
    bash "$M03_ROOT/scripts/verify_rootfs_structure.sh" "$CANDIDATE" 2>&1 | tail -n 3 >&2 || true
fi

# 2. REAL BusyBox provider identity (static ARM ELF + BusyBox identity +
#    applet table + applet resolution). The synthetic pedagogical fixture and
#    any non-BusyBox binary masquerading as the multicall are rejected here.
if ! bash "$M03_ROOT/scripts/validate_real_busybox.sh" "$CANDIDATE" >/dev/null 2>&1; then
    fail "candidate multicall/init provider is not a verified real BusyBox 1.36.1 artifact"
    bash "$M03_ROOT/scripts/validate_real_busybox.sh" "$CANDIDATE" 2>&1 \
        | grep -E '^(REJECT|\[PASS\])' | tail -n 6 >&2 || true
fi

# 3. /sbin/init must be the real BusyBox init path, and /init must exist.
BB="$CANDIDATE/bin/busybox"
[ -f "$BB" ] || BB="$CANDIDATE/usr/bin/busybox"
if [ ! -e "$CANDIDATE/sbin/init" ]; then
    fail "sbin/init missing"
elif [ ! -f "$CANDIDATE/sbin/init" ]; then
    fail "sbin/init is broken"
elif [ -f "$BB" ] && [ "$(readlink -f "$CANDIDATE/sbin/init")" != "$(readlink -f "$BB")" ]; then
    fail "sbin/init does not resolve to the candidate's real BusyBox binary"
fi
if [ ! -e "$CANDIDATE/init" ]; then
    fail "/init missing"
elif [ ! -x "$CANDIDATE/init" ]; then
    fail "/init lacks executable permission"
fi

# 4. Production inittab contract (BusyBox init path).
INITTAB="$CANDIDATE/etc/inittab"
if [ ! -f "$INITTAB" ]; then
    fail "etc/inittab missing"
else
    grep -Eq '^::sysinit:/etc/init\.d/rcS' "$INITTAB" \
        || fail "inittab lacks '::sysinit:/etc/init.d/rcS' line"
    grep -Eq '^ttyAMA0::askfirst:-/bin/sh' "$INITTAB" \
        || fail "inittab lacks 'ttyAMA0::askfirst:-/bin/sh' console line"
    # No competing askfirst/console entry may hijack the serial console.
    OTHER_ASKFIRST=$(grep -cE 'askfirst' "$INITTAB" || true)
    if [ "$OTHER_ASKFIRST" -ne 1 ]; then
        fail "inittab declares $OTHER_ASKFIRST 'askfirst' entries (exactly one ttyAMA0 entry required)"
    fi
fi

# 5. rcS must be an executable script with active mounts (graded directly,
# not only via the /init-vs-rcS preference of the generic validator).
RCS="$CANDIDATE/etc/init.d/rcS"
if [ ! -f "$RCS" ]; then
    fail "etc/init.d/rcS missing"
else
    [ -x "$RCS" ] || fail "etc/init.d/rcS lacks executable permission"
    ACTIVE=$(grep -v '^[[:space:]]*#' "$RCS" | grep -vE '^[[:space:]]*echo([[:space:]]|$)' || true)
    echo "$ACTIVE" | grep -Eq "^[[:space:]]*mount.*-t[[:space:]]+proc[[:space:]]+[^[:space:]]+[[:space:]]+/proc([[:space:]]|$|;)" \
        || fail "rcS lacks ACTIVE 'mount -t proc ... /proc' (decoys do not count)"
    echo "$ACTIVE" | grep -Eq "^[[:space:]]*mount.*-t[[:space:]]+sysfs[[:space:]]+[^[:space:]]+[[:space:]]+/sys([[:space:]]|$|;)" \
        || fail "rcS lacks ACTIVE 'mount -t sysfs ... /sys' (decoys do not count)"
fi

# 6. Packaged archive: real BusyBox identity inside the archive, staged-archive
#    consistency, and structural equivalence after unpacking.
if [ -n "$ARCHIVE" ]; then
    if [ ! -f "$ARCHIVE" ]; then
        fail "candidate archive missing: $ARCHIVE"
    else
        if ! bash "$M03_ROOT/scripts/validate_real_busybox.sh" "$ARCHIVE" "$CANDIDATE" >/dev/null 2>&1; then
            fail "packaged archive does not carry the candidate's real BusyBox artifact / diverges from staging"
            bash "$M03_ROOT/scripts/validate_real_busybox.sh" "$ARCHIVE" "$CANDIDATE" 2>&1 \
                | grep -E '^REJECT' | tail -n 4 >&2 || true
        fi
        UNPACK=$(mktemp -d /tmp/m03_oracle_unpack_XXXXXX)
        trap 'rm -rf "$UNPACK"' EXIT
        RAW="$UNPACK/archive.raw"
        zcat "$ARCHIVE" > "$RAW"
        python3 "$M03_ROOT/scripts/pycpio.py" --extract "$RAW" "$UNPACK"
        rm -f "$RAW"
        if ! bash "$M03_ROOT/scripts/verify_rootfs_structure.sh" "$UNPACK" >/dev/null 2>&1; then
            fail "unpacked candidate archive fails structure contract"
        fi
        if [ -f "$UNPACK/etc/inittab" ]; then
            grep -Eq '^ttyAMA0::askfirst:-/bin/sh' "$UNPACK/etc/inittab" \
                || fail "unpacked archive inittab lacks the ttyAMA0 askfirst console line"
        fi
    fi
fi

echo "------------------------------------------------------------------"
if [ "$FAILURES" -eq 0 ]; then
    echo "=== ASSESSMENT REFERENCE PASS (M03 candidate) ==="
    exit 0
fi
echo "=== ASSESSMENT REFERENCE REJECT: $FAILURES mismatch(es) ===" >&2
exit 1
