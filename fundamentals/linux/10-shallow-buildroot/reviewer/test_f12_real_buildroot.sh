#!/usr/bin/env bash
# Real Buildroot fidelity regression test for F12 (REVIEWER-ONLY).
#
# Proves the actual Buildroot state-machine behaviour for local-site packages:
#   1. Baseline build produces image containing SOURCE-REV=1.0
#   2. External package source modified to SOURCE-REV=2.0
#   3. Plain make skips package (.stamp_target_installed), image remains STALE (1.0)
#   4. make appliance-diag-rebuild rebuilds existing build dir but skips re-extraction
#      (.stamp_extracted preserved), image remains STALE (1.0)
#   5. make appliance-diag-dirclean removes build dir, forcing re-extraction from
#      APPLIANCE_DIAG_SITE, rebuilds, and produces final image containing SOURCE-REV=2.0
#   6. Final rootfs image is inspected directly for the observable SOURCE-REV marker.
#
# Gated on BUILDROOT_SRC.  If not provided, exits cleanly with explicit UNVERIFIED status.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M06_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M06_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

BR_SRC="${BUILDROOT_SRC:-}"
if [ -z "$BR_SRC" ] || [ ! -f "$BR_SRC/Makefile" ]; then
    echo "[NOTE] BUILDROOT_SRC not supplied: real Buildroot F12 fidelity regression SKIPPED (UNVERIFIED on this host)."
    echo "       Canonical baseline: Buildroot 2026.05.2 (tag 2026.05.2, peeled commit 72d9d4fa636a371ef9eb99c92a735ce9f6d829d5)."
    exit 0
fi

echo "================================================================"
echo "=== P3-M06 Real Buildroot F12 Fidelity Regression (REVIEWER) ==="
echo "================================================================"

BR_SRC_ABS=$(cd "$BR_SRC" && { pwd -W 2>/dev/null || pwd; })
WORK_DIR="$M06_ROOT/build/f12-real-buildroot"
TEMP_EXT="$M06_ROOT/build/f12-br2-external"

cleanup() {
    rm -rf "$TEMP_EXT" 2>/dev/null || true
}
trap cleanup EXIT

rm -rf "$WORK_DIR" "$TEMP_EXT" 2>/dev/null || true
mkdir -p "$WORK_DIR" "$TEMP_EXT"
cp -r "$M06_ROOT/fixtures/br2-external/"* "$TEMP_EXT/"

# Ensure Windows/MSYS path compatibility for BR2_EXTERNAL
TEMP_EXT_ABS=$(cd "$TEMP_EXT" && { pwd -W 2>/dev/null || pwd; })
WORK_DIR_ABS=$(cd "$WORK_DIR" && { pwd -W 2>/dev/null || pwd; })

echo "[INFO] Step 1: Configuring Buildroot defconfig..."
make -C "$BR_SRC" O="$WORK_DIR_ABS" BR2_EXTERNAL="$TEMP_EXT_ABS" qemu_virt_a7_defconfig

echo "[INFO] Step 2: Running baseline build of appliance-diag and rootfs-cpio..."
make -C "$BR_SRC" O="$WORK_DIR_ABS" BR2_EXTERNAL="$TEMP_EXT_ABS" appliance-diag rootfs-cpio

# Inspect binary in target and image
if ! strings "$WORK_DIR/target/usr/bin/appliance-diag" | grep -q "SOURCE-REV=1.0"; then
    echo "FAIL: baseline binary does not contain SOURCE-REV=1.0" >&2
    exit 1
fi
echo "[PASS] Step 2: Baseline binary in target contains SOURCE-REV=1.0"

echo "[INFO] Step 3: Modifying external source tree to SOURCE-REV=2.0..."
sed -i 's/APPLIANCE_DIAG_SOURCE_REV "1.0"/APPLIANCE_DIAG_SOURCE_REV "2.0"/' \
    "$TEMP_EXT/package/appliance-diag/src/appliance-diag.c"

echo "[INFO] Step 4: Running plain make rootfs-cpio (stamp-gating test)..."
make -C "$BR_SRC" O="$WORK_DIR_ABS" BR2_EXTERNAL="$TEMP_EXT_ABS" rootfs-cpio

if ! strings "$WORK_DIR/target/usr/bin/appliance-diag" | grep -q "SOURCE-REV=1.0"; then
    echo "FAIL: plain make unexpectedly updated binary (expected stale 1.0)" >&2
    exit 1
fi
echo "[PASS] Step 4: Plain make preserved stale SOURCE-REV=1.0 due to .stamp_target_installed"

echo "[INFO] Step 5: Running appliance-diag-rebuild (local-site extraction cache test)..."
make -C "$BR_SRC" O="$WORK_DIR_ABS" BR2_EXTERNAL="$TEMP_EXT_ABS" appliance-diag-rebuild rootfs-cpio

if ! strings "$WORK_DIR/target/usr/bin/appliance-diag" | grep -q "SOURCE-REV=1.0"; then
    echo "FAIL: appliance-diag-rebuild unexpectedly updated binary (expected stale 1.0 for local site)" >&2
    exit 1
fi
echo "[PASS] Step 5: appliance-diag-rebuild preserved stale SOURCE-REV=1.0 (local site not re-extracted)"

echo "[INFO] Step 6: Running appliance-diag-dirclean all (forced re-extraction & recovery)..."
make -C "$BR_SRC" O="$WORK_DIR_ABS" BR2_EXTERNAL="$TEMP_EXT_ABS" appliance-diag-dirclean rootfs-cpio

if ! strings "$WORK_DIR/target/usr/bin/appliance-diag" | grep -q "SOURCE-REV=2.0"; then
    echo "FAIL: appliance-diag-dirclean failed to refresh binary to SOURCE-REV=2.0" >&2
    exit 1
fi
echo "[PASS] Step 6: appliance-diag-dirclean refreshed binary to SOURCE-REV=2.0"

echo "[INFO] Step 7: Inspecting real final image output/images/rootfs.cpio..."
IMAGE="$WORK_DIR/images/rootfs.cpio"
[ -f "$IMAGE.gz" ] && gunzip -k -f "$IMAGE.gz"
if ! strings "$IMAGE" | grep -q "SOURCE-REV=2.0"; then
    echo "FAIL: final rootfs image does not contain SOURCE-REV=2.0" >&2
    exit 1
fi
echo "[PASS] Step 7: Final rootfs image verified: contains updated SOURCE-REV=2.0 marker"
echo "[NOTE] Real guest boot runtime is UNVERIFIED (final image verified statically; boot log not fabricated)."
echo "=== REAL BUILDROOT F12 FIDELITY REGRESSION PASSED ==="
