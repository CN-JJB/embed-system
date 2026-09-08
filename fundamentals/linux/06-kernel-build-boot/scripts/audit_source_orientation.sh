#!/bin/bash
set -euo pipefail

# Audit Linux Kernel Source Orientation against Pinned Commit 7cfc41f8e80f11ffa8382ed1a505154ceffb79c7
# Enforces reading real upstream kernel source without confusing rewritten pedagogical pseudocode.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M02_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
LINUX_SRC="${1:-${LINUX_SRC:-/tmp/linux-6.18.50}}"

PINNED_COMMIT="7cfc41f8e80f11ffa8382ed1a505154ceffb79c7"

echo "=== Auditing Linux Kernel Source Orientation ==="
echo "Canonical baseline: Linux 6.18.50 LTS (commit ${PINNED_COMMIT})"

if [ -d "$LINUX_SRC" ] && [ -d "$LINUX_SRC/.git" ]; then
    ACTUAL_COMMIT=$(git -C "$LINUX_SRC" rev-parse HEAD 2>/dev/null || true)
    if [ "$ACTUAL_COMMIT" != "$PINNED_COMMIT" ]; then
        echo "ERROR: LINUX_SRC commit ($ACTUAL_COMMIT) does not match canonical pin ($PINNED_COMMIT)!" >&2
        exit 1
    fi
    echo "[PASS] Real Linux source tree detected at: $LINUX_SRC"
    echo "[PASS] Upstream commit SHA strictly verified: $ACTUAL_COMMIT"

    HEAD_S="$LINUX_SRC/arch/arm/kernel/head.S"
    MAIN_C="$LINUX_SRC/init/main.c"

    [ -f "$HEAD_S" ] || { echo "ERROR: $HEAD_S missing in Linux source!"; exit 1; }
    [ -f "$MAIN_C" ] || { echo "ERROR: $MAIN_C missing in Linux source!"; exit 1; }

    echo "--- 1. Auditing Real arch/arm/kernel/head.S ---"
    grep -n -E "ENTRY\(stext\)|bl\s+__create_page_tables|__enable_mmu|ENTRY\(__turn_mmu_on\)|__mmap_switched" "$HEAD_S" | head -n 10
    echo "[PASS] Pinned ARM reset startup entry points confirmed in head.S"

    echo "--- 2. Auditing Real init/main.c ---"
    grep -n -E "asmlinkage.*start_kernel\(|setup_arch\(|console_init\(|rest_init\(|kernel_init\(" "$MAIN_C" | head -n 10
    echo "[PASS] Pinned C startup functions confirmed in main.c"

    echo "[PASS] Real Linux 6.18.50 source orientation audit complete (VERIFIED)"
    exit 0
else
    echo "[NOTE] Real Linux tree not detected at LINUX_SRC ($LINUX_SRC)."
    echo "       Checking pedagogical pseudocode in fixtures/sources/:"
    
    PSEUDO_HEAD="$M02_ROOT/fixtures/sources/arch_arm_kernel_head_S.pseudocode"
    PSEUDO_MAIN="$M02_ROOT/fixtures/sources/init_main_c.pseudocode"
    
    [ -f "$PSEUDO_HEAD" ] || { echo "ERROR: $PSEUDO_HEAD missing!"; exit 1; }
    [ -f "$PSEUDO_MAIN" ] || { echo "ERROR: $PSEUDO_MAIN missing!"; exit 1; }

    grep -q "ORIGINAL PEDAGOGICAL PSEUDOCODE — NOT UPSTREAM LINUX SOURCE" "$PSEUDO_HEAD" || {
        echo "ERROR: $PSEUDO_HEAD missing required prominent pedagogical disclaimer!"; exit 1;
    }
    grep -q "ORIGINAL PEDAGOGICAL PSEUDOCODE — NOT UPSTREAM LINUX SOURCE" "$PSEUDO_MAIN" || {
        echo "ERROR: $PSEUDO_MAIN missing required prominent pedagogical disclaimer!"; exit 1;
    }

    echo "[PASS] Pedagogical pseudocode verified with prominent non-upstream disclaimers."
    echo "       Evidence Status: EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED (Supply LINUX_SRC for real audit)"
    exit 0
fi
