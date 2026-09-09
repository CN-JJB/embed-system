#!/bin/bash
set -euo pipefail

# P3-M03 Assessment Reference Oracle (REVIEWER-ONLY)
# Grades a learner's repaired candidate rootfs (directory, plus optional
# packaged archive) against the canonical production-init contract. This
# file is the single source of truth for the scored expectations and must
# never be referenced by or copied into learner-facing material.
#
# Usage: oracle_m03.sh <candidate-rootfs-dir> [candidate-archive.cpio.gz]
#   Grades structure, ELF identity, applet symlinks, mount semantics, and
#   inittab production contract. Failures print ASSESSMENT MISMATCH.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

CANDIDATE="${1:-$M03_ROOT/gate/build/candidate_rootfs}"
ARCHIVE="${2:-}"

FAILURES=0
fail() { echo "[FAIL] ASSESSMENT MISMATCH: $1" >&2; FAILURES=$((FAILURES + 1)); }

echo "=================================================================="
echo "=== P3-M03 Assessment Reference Oracle                         ==="
echo "=== Candidate: $CANDIDATE"
echo "=================================================================="

[ -d "$CANDIDATE" ] || { fail "candidate rootfs directory missing: $CANDIDATE"; echo "=== ASSESSMENT REFERENCE REJECT ===" >&2; exit 1; }

# 1. Generic structure + active mount semantics.
if ! bash "$M03_ROOT/scripts/verify_rootfs_structure.sh" "$CANDIDATE" >/dev/null 2>&1; then
    fail "candidate fails rootfs structure / active-mount contract"
    bash "$M03_ROOT/scripts/verify_rootfs_structure.sh" "$CANDIDATE" 2>&1 | tail -n 3 >&2 || true
fi

# 2. Teaching-binary ELF identity (synthetic multicall, NOT real BusyBox).
MULTICALL=""
[ -f "$CANDIDATE/bin/synthetic_multicall" ] && MULTICALL="$CANDIDATE/bin/synthetic_multicall"
[ -f "$CANDIDATE/bin/busybox" ] && MULTICALL="$CANDIDATE/bin/busybox"
if [ -z "$MULTICALL" ]; then
    fail "candidate has neither bin/synthetic_multicall nor bin/busybox"
else
    if ! bash "$M03_ROOT/scripts/audit_busybox_elf.sh" "$MULTICALL" >/dev/null 2>&1; then
        fail "candidate multicall binary fails static ARM ELF contract: $MULTICALL"
    fi
fi

# 3. Applet symlink closure (all must resolve inside the candidate).
for app in sh ls ps mount echo cat; do
    if [ ! -L "$CANDIDATE/bin/$app" ]; then
        fail "applet symlink bin/$app missing (must link to the multicall binary)"
    elif [ ! -f "$CANDIDATE/bin/$app" ]; then
        fail "applet symlink bin/$app is broken"
    fi
done
if [ ! -e "$CANDIDATE/sbin/init" ]; then
    fail "sbin/init missing"
elif [ ! -f "$CANDIDATE/sbin/init" ]; then
    fail "sbin/init is broken"
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

# 6. If a packaged archive is supplied, it must unpack to an equivalent
# passing tree (proves the learner's packaging step, not just the staging).
if [ -n "$ARCHIVE" ]; then
    [ -f "$ARCHIVE" ] || { fail "candidate archive missing: $ARCHIVE"; }
    if [ -f "$ARCHIVE" ]; then
        UNPACK=$(mktemp -d /tmp/m03_oracle_unpack_XXXXXX)
        if command -v cpio >/dev/null 2>&1; then
            ( cd "$UNPACK" && zcat "$ARCHIVE" | cpio -idm --quiet 2>/dev/null ) || true
        else
            RAW="$UNPACK/a.raw"; zcat "$ARCHIVE" > "$RAW"
            python3 "$M03_ROOT/scripts/pycpio.py" --extract "$RAW" "$UNPACK"; rm -f "$RAW"
        fi
        if ! bash "$M03_ROOT/scripts/verify_rootfs_structure.sh" "$UNPACK" >/dev/null 2>&1; then
            fail "unpacked candidate archive fails structure contract"
        fi
        rm -rf "$UNPACK"
    fi
fi

echo "------------------------------------------------------------------"
if [ "$FAILURES" -eq 0 ]; then
    echo "=== ASSESSMENT REFERENCE PASS (M03 candidate) ==="
    exit 0
else
    echo "=== ASSESSMENT REFERENCE REJECT: $FAILURES mismatch(es) ===" >&2
    exit 1
fi
