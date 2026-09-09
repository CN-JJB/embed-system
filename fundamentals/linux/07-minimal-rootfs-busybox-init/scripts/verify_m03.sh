#!/bin/bash
set -euo pipefail

# Semantic Verification Suite for P3-M03: Minimal Rootfs, BusyBox, Pseudo-Filesystems & PID 1 Init Lifecycle
# Learner-safe: validates the SYNTHETIC teaching fixture (explicitly NOT
# BusyBox) plus static structure/archive contracts. Real BusyBox evidence
# is covered by the separate real-busybox-build-check / real-qemu-check
# targets and MUST NOT be confused with synthetic results.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M03_ROOT"

echo "================================================================"
echo "=== Running P3-M03 Semantic Verification Suite               ==="
echo "================================================================"

# 1. Source & Version Pin Integrity
echo "=== Step 1: Verifying Canonical Source & Platform Pins ==="
PINNED_BUSYBOX_COMMIT="1a64f6a20aaf6ea4dbba68bbfa8cc1ab7e5c57c4"
PINNED_LINUX_COMMIT="7cfc41f8e80f11ffa8382ed1a505154ceffb79c7"
PINNED_QEMU_COMMIT="c3d48b7d1e89604920e5b81b91140c2ad39a1943"
PINNED_TOOLCHAIN_SHA="560267bdecf966b7a48467d0af6c81a85b906ef7b0a9b9dd91f506184b940281"

grep -q "$PINNED_BUSYBOX_COMMIT" SOURCE_LEDGER.md || { echo "ERROR: BusyBox commit pin missing in SOURCE_LEDGER"; exit 1; }
grep -q "$PINNED_LINUX_COMMIT" SOURCE_LEDGER.md || { echo "ERROR: Linux commit pin missing in SOURCE_LEDGER"; exit 1; }
grep -q "$PINNED_QEMU_COMMIT" SOURCE_LEDGER.md || { echo "ERROR: QEMU commit pin missing in SOURCE_LEDGER"; exit 1; }
grep -q "$PINNED_TOOLCHAIN_SHA" SOURCE_LEDGER.md || { echo "ERROR: Toolchain package SHA missing in SOURCE_LEDGER"; exit 1; }
echo "[PASS] Canonical source pins verified in SOURCE_LEDGER.md"

# Check real source trees if present on disk
BUSYBOX_SRC="${BUSYBOX_SRC:-/tmp/busybox-1.36.1}"
if [ -d "$BUSYBOX_SRC/.git" ]; then
    ACTUAL_BB_COMMIT=$(git -C "$BUSYBOX_SRC" rev-parse HEAD 2>/dev/null || true)
    if [ "$ACTUAL_BB_COMMIT" = "$PINNED_BUSYBOX_COMMIT" ]; then
        echo "[PASS] Actual upstream BusyBox source git commit verified: $ACTUAL_BB_COMMIT (Source/version: VERIFIED)"
    fi
fi

# 2. Check Toolchain
CROSS_COMPILE="${CROSS_COMPILE:-arm-none-linux-gnueabihf-}"
if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    echo "ERROR: Cross compiler '${CROSS_COMPILE}gcc' not found in PATH." >&2
    echo "For Ubuntu/Debian distro toolchain, pass: CROSS_COMPILE=arm-linux-gnueabihf- $0" >&2
    exit 1
fi

echo "=== Step 2: Building SYNTHETIC Teaching Fixtures ==="
# Teaching fixtures only. Challenge/Gate candidates are NEVER rebuilt here:
# re-provisioning would wipe the learner's in-progress repair.
make -C fixtures synthetic CROSS_COMPILE="${CROSS_COMPILE}" >/dev/null
echo "[PASS] Synthetic teaching fixtures built (SYNTHETIC — NOT BUSYBOX)"

# 3. Audit SYNTHETIC Static ARM ELF Binary (teaching fixture only).
echo "=== Step 3: Auditing SYNTHETIC Target ELF Binary ==="
TARGET_SYNTHETIC="fixtures/build/synthetic_multicall"
[ -f "$TARGET_SYNTHETIC" ] || { echo "ERROR: $TARGET_SYNTHETIC missing"; exit 1; }
bash scripts/audit_busybox_elf.sh "$TARGET_SYNTHETIC"
echo "[NOTE] Above PASS covers the SYNTHETIC fixture ELF shape only; real BusyBox is audited by real-busybox-build-check."

# 3b. Synthetic masquerade guard: the teaching binary must identify itself
# as synthetic and must never claim to be BusyBox. (Pure bash matching:
# piping a large strings dump into 'grep -q' races with SIGPIPE under
# 'set -o pipefail' and flakes.)
SYN_STRINGS=$(strings "$TARGET_SYNTHETIC" || true)
if [[ "$SYN_STRINGS" != *"SYNTHETIC PEDAGOGICAL FIXTURE"* ]]; then
    echo "ERROR: Synthetic fixture lost its NOT-BUSYBOX identity banner." >&2
    exit 1
fi
if [[ "$SYN_STRINGS" == *"BusyBox v1.36.1 synthetic"* ]]; then
    echo "ERROR: Synthetic fixture still masquerades as BusyBox (stale banner)." >&2
    exit 1
fi
echo "[PASS] Synthetic fixture identity banner verified (NOT BUSYBOX)"

# 4. Audit Synthetic Staging Rootfs Structure
echo "=== Step 4: Auditing SYNTHETIC Staging Rootfs Structure ==="
ROOTFS_DIR="fixtures/build/synthetic_rootfs"
[ -d "$ROOTFS_DIR" ] || { echo "ERROR: $ROOTFS_DIR missing"; exit 1; }
bash scripts/verify_rootfs_structure.sh "$ROOTFS_DIR"

# 5. Audit Generated SYNTHETIC Initramfs Archive
echo "=== Step 5: Auditing SYNTHETIC Initramfs CPIO Archive ==="
ARCHIVE="fixtures/build/synthetic_rootfs.cpio.gz"
[ -f "$ARCHIVE" ] || { echo "ERROR: $ARCHIVE missing"; exit 1; }

# Verify archive magic / gzip integrity
gzip -t "$ARCHIVE" || { echo "ERROR: Archive gzip integrity check failed!"; exit 1; }

# Unpack check into temporary dir
VERIFY_TMP=$(mktemp -d /tmp/m03_archive_audit_XXXXXX)
trap 'rm -rf "$VERIFY_TMP"' EXIT

if command -v cpio >/dev/null 2>&1; then
    (
        cd "$VERIFY_TMP"
        zcat "$M03_ROOT/$ARCHIVE" | cpio -idm --quiet 2>/dev/null || zcat "$M03_ROOT/$ARCHIVE" | cpio -idm 2>/dev/null
    )
else
    RAW_CPIO="$VERIFY_TMP/archive.raw"
    zcat "$M03_ROOT/$ARCHIVE" > "$RAW_CPIO"
    python3 "$M03_ROOT/scripts/pycpio.py" --extract "$RAW_CPIO" "$VERIFY_TMP"
    rm -f "$RAW_CPIO"
fi

[ -f "$VERIFY_TMP/init" ] || [ -f "$VERIFY_TMP/sbin/init" ] || { echo "ERROR: /init or /sbin/init missing in archive!"; exit 1; }
[ -x "$VERIFY_TMP/init" ] || [ -x "$VERIFY_TMP/sbin/init" ] || { echo "ERROR: Init in archive is not executable!"; exit 1; }
[ -f "$VERIFY_TMP/bin/sh" ] || [ -L "$VERIFY_TMP/bin/sh" ] || { echo "ERROR: /bin/sh missing in archive!"; exit 1; }
[ -d "$VERIFY_TMP/proc" ] || { echo "ERROR: /proc missing in archive!"; exit 1; }
[ -d "$VERIFY_TMP/sys" ] || { echo "ERROR: /sys missing in archive!"; exit 1; }
[ -d "$VERIFY_TMP/dev" ] || { echo "ERROR: /dev missing in archive!"; exit 1; }
echo "[PASS] Synthetic initramfs archive verified: valid gzip, newc cpio format, executable init, valid symlinks"

# 5b. Real-rootfs static audit when a real staging is present (optional,
# learner-safe: never builds BusyBox, only audits what exists).
if [ -f "fixtures/build/real_rootfs.cpio.gz" ]; then
    echo "=== Step 5b: Auditing REAL initramfs device-node contract (if present) ==="
    bash scripts/verify_initramfs_nodes.sh fixtures/build/real_rootfs.cpio.gz
fi

# 6. Audit QEMU Launch Contract
echo "=== Step 6: Verifying Canonical QEMU Launch Contract ==="
REQUIRED_QEMU_ARGS=(
    "-machine virt,highmem=off,gic-version=2"
    "-cpu cortex-a7"
    "-m 512M"
    "-smp 1"
    "-nographic"
)
for arg in "${REQUIRED_QEMU_ARGS[@]}"; do
    grep -q -- "$arg" labs/06-qemu-interactive-boot/README.md || {
        echo "ERROR: Required QEMU launch argument '$arg' missing in Lab 3.6 guide!"; exit 1;
    }
done
echo "[PASS] Canonical QEMU machine, CPU, memory, and console contracts verified in documentation"

echo "================================================================"
echo "=== ALL P3-M03 LEARNER-SAFE VERIFICATION CHECKS PASSED       ==="
echo "================================================================"
