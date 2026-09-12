#!/usr/bin/env bash
# Adversarial mutation suite for the P3-M06 validators (REVIEWER-ONLY).
#
# Every mutation must produce the *intended* outcome class.  A crash, a parser
# error or an unrelated environment failure does not count as an intended
# semantic rejection, and is asserted separately as ERROR.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M06_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M06_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

CANONICAL="fixtures/br2-external/configs/qemu_virt_a7_defconfig"
TAUGHT_PROFILE="fixtures/profiles/buildroot-2026.05.2-taught.json"
COMPLETE_PROFILE="reviewer/reference/buildroot-2026.05.2-complete.json"
SYMBOLS="fixtures/buildroot-symbols.json"
OVERLAY="fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay"

WORK="build/reviewer-m06-mutations"
rm -rf "$WORK" 2>/dev/null || true
mkdir -p "$WORK"

TOTAL=0
PASSED=0

mutate() {
    # mutate <outfile> <python-expression-file>
    local out="$1"; shift
    "$PY" - "$CANONICAL" "$out" "$@" <<'PYEOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
rules = {}
for spec in sys.argv[3:]:
    old, new = spec.split("=>", 1)
    rules[old] = new
out = []
for line in open(src, "r", encoding="utf-8"):
    stripped = line.strip()
    if stripped in rules:
        out.append(rules[stripped] + "\n")
    else:
        out.append(line)
open(dst, "w", encoding="utf-8").writelines(out)
PYEOF
}

assert_reject() {
    local name="$1" fragment="$2" profile="$3"
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] semantic REJECT expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/verify_br_config.py "$fragment" --profile "$profile" \
          --symbol-table "$SYMBOLS" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 1 ] && grep -q "REJECT" <<<"$out"; then
        echo "PASS (intended semantic REJECT)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 1)"
        echo "$out"
        exit 1
    fi
}

assert_pass() {
    local name="$1" fragment="$2" profile="$3"
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] PASS expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/verify_br_config.py "$fragment" --profile "$profile" \
          --symbol-table "$SYMBOLS" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then
        echo "PASS"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 0)"
        echo "$out"
        exit 1
    fi
}

assert_audit_reject() {
    local name="$1" output="$2"
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] audit REJECT expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/audit_output_tree.py --output "$output" --overlay "$OVERLAY" --quiet 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 1 ]; then
        echo "PASS (intended audit REJECT)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 1)"
        echo "$out"
        exit 1
    fi
}

assert_audit_error() {
    local name="$1" output="$2"
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] audit ERROR expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/audit_output_tree.py --output "$output" --overlay "$OVERLAY" --quiet 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 2 ]; then
        echo "PASS (classified as tool/format ERROR)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 2)"
        echo "$out"
        exit 1
    fi
}

echo "================================================================"
echo "=== P3-M06 Adversarial Mutation Suite (REVIEWER-ONLY)         ==="
echo "================================================================"

# --- 1. architecture / ABI ---------------------------------------------------
mutate "$WORK/wrong-abi.conf" 'BR2_ARM_EABIHF=y=>BR2_ARM_EABI=y'
assert_reject "soft-float ABI selected instead of EABIhf" "$WORK/wrong-abi.conf" "$TAUGHT_PROFILE"

mutate "$WORK/wrong-arch.conf" 'BR2_arm=y=>BR2_aarch64=y'
assert_reject "wrong target architecture (aarch64)" "$WORK/wrong-arch.conf" "$TAUGHT_PROFILE"

mutate "$WORK/wrong-cpu.conf" 'BR2_cortex_a7=y=>BR2_cortex_a15=y'
assert_reject "CPU variant not in the canonical contract" "$WORK/wrong-cpu.conf" "$TAUGHT_PROFILE"

# --- 2. a symbol that merely *looks* right ----------------------------------
# The correct symbol name appears only in a comment, so the declaration is
# absent.  A substring-matching validator would be fooled; this one is not.
mutate "$WORK/commented-out.conf" 'BR2_cortex_a7=y=># BR2_cortex_a7=y'
assert_reject "required symbol commented out (declaration absent)" "$WORK/commented-out.conf" "$TAUGHT_PROFILE"

# --- 3. symbols that do not exist in the real release -----------------------
cp "$CANONICAL" "$WORK/bogus-symbol.conf"
printf 'BR2_TARGET_ROOTFS_SQUASHFS_GZIP=y\n' >> "$WORK/bogus-symbol.conf"
assert_reject "symbol that does not exist in the real 2026.05.2 tree" \
    "$WORK/bogus-symbol.conf" "$COMPLETE_PROFILE"

# --- 4. duplicate / conflicting definitions ---------------------------------
cp "$CANONICAL" "$WORK/duplicate.conf"
printf 'BR2_TARGET_ROOTFS_CPIO_GZIP=n\n' >> "$WORK/duplicate.conf"
assert_reject "conflicting duplicate definition of the same symbol" \
    "$WORK/duplicate.conf" "$COMPLETE_PROFILE"

# --- 5. non-declarative content smuggled into the fragment ------------------
cp "$CANONICAL" "$WORK/shell-content.conf"
printf 'make -C buildroot all\n' >> "$WORK/shell-content.conf"
assert_reject "shell command smuggled into the configuration fragment" \
    "$WORK/shell-content.conf" "$COMPLETE_PROFILE"

cp "$CANONICAL" "$WORK/substitution.conf"
printf 'BR2_TARGET_GENERIC_HOSTNAME="$(hostname)"\n' >> "$WORK/substitution.conf"
assert_reject "command substitution inside a configuration value" \
    "$WORK/substitution.conf" "$COMPLETE_PROFILE"

cp "$CANONICAL" "$WORK/metachars.conf"
printf 'BR2_ROOTFS_POST_BUILD_SCRIPT="/tmp/x.sh; evil"\n' >> "$WORK/metachars.conf"
assert_reject "shell metacharacters inside a configuration value" \
    "$WORK/metachars.conf" "$COMPLETE_PROFILE"

# --- 6. kernel / image contract defects -------------------------------------
mutate "$WORK/kernel-drift.conf" \
    'BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="6.18.50"=>BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="6.6.30"'
assert_reject "kernel version drift away from the pinned release" \
    "$WORK/kernel-drift.conf" "$COMPLETE_PROFILE"

mutate "$WORK/no-cpio-gzip.conf" 'BR2_TARGET_ROOTFS_CPIO_GZIP=y=># BR2_TARGET_ROOTFS_CPIO_GZIP is not set'
assert_reject "initramfs compression selection removed" \
    "$WORK/no-cpio-gzip.conf" "$COMPLETE_PROFILE"

mutate "$WORK/kernel-no-defconfig.conf" \
    'BR2_LINUX_KERNEL_DEFCONFIG="multi_v7"=>BR2_LINUX_KERNEL_DEFCONFIG=""'
assert_reject "kernel defconfig selection empty" \
    "$WORK/kernel-no-defconfig.conf" "$COMPLETE_PROFILE"

mutate "$WORK/kernel-no-zimage.conf" \
    'BR2_LINUX_KERNEL_ZIMAGE=y=># BR2_LINUX_KERNEL_ZIMAGE is not set'
assert_reject "kernel zImage target selection omitted" \
    "$WORK/kernel-no-zimage.conf" "$COMPLETE_PROFILE"

# --- 7. overlay provenance --------------------------------------------------
mutate "$WORK/overlay-wrong-path.conf" \
    'BR2_ROOTFS_OVERLAY="$(BR2_EXTERNAL_QEMU_VIRT_A7_PATH)/board/qemu-virt-a7/rootfs-overlay"=>BR2_ROOTFS_OVERLAY="$(BR2_EXTERNAL_QEMU_VIRT_A7_PATH)/board/qemu-virt-a7/rootfs-overlay-legacy"'
assert_reject "overlay path that does not exist in the external tree" \
    "$WORK/overlay-wrong-path.conf" "$COMPLETE_PROFILE"

mutate "$WORK/overlay-empty.conf" \
    'BR2_ROOTFS_OVERLAY="$(BR2_EXTERNAL_QEMU_VIRT_A7_PATH)/board/qemu-virt-a7/rootfs-overlay"=>BR2_ROOTFS_OVERLAY=""'
assert_reject "overlay selection present but empty" \
    "$WORK/overlay-empty.conf" "$TAUGHT_PROFILE"

# --- 8. output-tree / overlay propagation defects ---------------------------
"$PY" scripts/make_sample_output_tree.py --out "$WORK/tree-healthy" --mode healthy >/dev/null
"$PY" scripts/make_sample_output_tree.py --out "$WORK/tree-stale" --mode stale >/dev/null
assert_audit_reject "stale image: overlay in output/target but not in the packaged image" \
    "$WORK/tree-stale"

# A tree whose image is fine but whose staging view lost the overlay.
"$PY" scripts/make_sample_output_tree.py --out "$WORK/tree-target-missing" --mode healthy >/dev/null
"$PY" - "$WORK/tree-target-missing" <<'PYEOF'
import os, sys
root = sys.argv[1]
victim = os.path.join(root, "target", "etc", "appliance-release")
if os.path.isfile(victim):
    os.remove(victim)
PYEOF
assert_audit_reject "overlay missing from output/target" "$WORK/tree-target-missing"

# A tree with no images directory at all is an ERROR, not a semantic rejection.
mkdir -p "$WORK/tree-no-images"
assert_audit_error "output tree with no images directory" "$WORK/tree-no-images"

# --- 9. runtime-binding defects ---------------------------------------------
"$PY" scripts/make_sample_output_tree.py --out "$WORK/tree-bind" --mode healthy >/dev/null
IMAGE="$WORK/tree-bind/images/rootfs.cpio.gz"
IMAGE_SHA=$(sha256sum "$IMAGE" | awk '{print $1}')

cat > "$WORK/prov-ok.conf" <<EOF
machine: virt,highmem=off,gic-version=2
cpu: cortex-a7
memory: 512M
smp: 1
bootargs: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init
initrd_sha256: $IMAGE_SHA
EOF
cat > "$WORK/boot-ok.log" <<'EOF'
[    0.000000] Kernel command line: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init
APPLIANCE-OVERLAY-BOOT-MARKER
APPLIANCE-DIAG-BEGIN
APPLIANCE-RELEASE=EMBED-SYSTEM P3-M06 appliance release 1.0
DT-MODEL=linux,dummy-virt
APPLIANCE-DIAG-END
EOF

TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] runtime binding PASS expected: consistent capture ... "
set +e
"$PY" scripts/verify_appliance_runtime.py "$IMAGE" "$WORK/prov-ok.conf" "$WORK/boot-ok.log" \
    --overlay "$OVERLAY" >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 0 ]; then echo "PASS"; PASSED=$((PASSED + 1)); else echo "FAIL (rc=$RC)"; exit 1; fi

# Wrong image identity.
sed 's/^initrd_sha256: .*/initrd_sha256: 0000000000000000000000000000000000000000000000000000000000000000/' \
    "$WORK/prov-ok.conf" > "$WORK/prov-wrong-image.conf"
TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] runtime binding REJECT expected: image identity mismatch ... "
set +e
"$PY" scripts/verify_appliance_runtime.py "$IMAGE" "$WORK/prov-wrong-image.conf" \
    "$WORK/boot-ok.log" --overlay "$OVERLAY" >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 1 ]; then echo "PASS"; PASSED=$((PASSED + 1)); else echo "FAIL (rc=$RC, expected 1)"; exit 1; fi

# A log with no overlay marker: the file may be packaged, but nothing ran it.
grep -v 'APPLIANCE-OVERLAY-BOOT-MARKER' "$WORK/boot-ok.log" > "$WORK/boot-no-marker.log"
TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] runtime binding REJECT expected: overlay never executed ... "
set +e
"$PY" scripts/verify_appliance_runtime.py "$IMAGE" "$WORK/prov-ok.conf" \
    "$WORK/boot-no-marker.log" --overlay "$OVERLAY" >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 1 ]; then echo "PASS"; PASSED=$((PASSED + 1)); else echo "FAIL (rc=$RC, expected 1)"; exit 1; fi

# A log that reports the wrong release marker.
sed 's/release 1.0/release 0.9/' "$WORK/boot-ok.log" > "$WORK/boot-wrong-release.log"
TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] runtime binding REJECT expected: guest release mismatches overlay ... "
set +e
"$PY" scripts/verify_appliance_runtime.py "$IMAGE" "$WORK/prov-ok.conf" \
    "$WORK/boot-wrong-release.log" --overlay "$OVERLAY" >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 1 ]; then echo "PASS"; PASSED=$((PASSED + 1)); else echo "FAIL (rc=$RC, expected 1)"; exit 1; fi

# --- 9b. S2-R2-3: F12 rebuild mechanics & observable SOURCE-REV fidelity ---
# Unit model of appliance-diag local-package cache drift and recovery
F12_WORK="$WORK/f12-fidelity"
rm -rf "$F12_WORK" 2>/dev/null || true
mkdir -p "$F12_WORK/src" "$F12_WORK/build" "$F12_WORK/target/usr/bin" "$F12_WORK/images"
cp fixtures/br2-external/package/appliance-diag/src/* "$F12_WORK/src/"

# Step 1: Initial build with SOURCE-REV=1.0 into build directory
cp "$F12_WORK/src/"* "$F12_WORK/build/"
cc -O2 -Wall "$F12_WORK/build/appliance-diag.c" -o "$F12_WORK/build/appliance-diag"
touch "$F12_WORK/build/.stamp_extracted" "$F12_WORK/build/.stamp_built" "$F12_WORK/build/.stamp_target_installed"
cp "$F12_WORK/build/appliance-diag" "$F12_WORK/target/usr/bin/appliance-diag"
INITIAL_OUT=$("$F12_WORK/target/usr/bin/appliance-diag")
grep -q "SOURCE-REV=1.0" <<<"$INITIAL_OUT"

# Step 2: Edit external source tree to SOURCE-REV=2.0
sed -i 's/APPLIANCE_DIAG_SOURCE_REV "1.0"/APPLIANCE_DIAG_SOURCE_REV "2.0"/' "$F12_WORK/src/appliance-diag.c" 2>/dev/null || true

# Step 3: Plain make skips because .stamp_target_installed exists
# target/usr/bin/appliance-diag remains at 1.0
PLAIN_OUT=$("$F12_WORK/target/usr/bin/appliance-diag")
TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] F12 plain make remains stale: stamp-gated skip ... "
if grep -q "SOURCE-REV=1.0" <<<"$PLAIN_OUT"; then
    echo "PASS (stale binary preserved)"
    PASSED=$((PASSED + 1))
else
    echo "FAIL"
    exit 1
fi

# Step 4: Rebuild without dirclean (rebuilding existing build dir without re-extraction leaves 1.0)
rm -f "$F12_WORK/build/.stamp_built" "$F12_WORK/build/.stamp_target_installed"
cc -O2 -Wall "$F12_WORK/build/appliance-diag.c" -o "$F12_WORK/build/appliance-diag"
cp "$F12_WORK/build/appliance-diag" "$F12_WORK/target/usr/bin/appliance-diag"
STALE_REBUILD_OUT=$("$F12_WORK/target/usr/bin/appliance-diag")
TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] F12 rebuild without re-extraction remains stale ... "
if grep -q "SOURCE-REV=1.0" <<<"$STALE_REBUILD_OUT"; then
    echo "PASS (stale source in build dir preserved)"
    PASSED=$((PASSED + 1))
else
    echo "FAIL"
    exit 1
fi

# Step 5: Clean targeted recovery (dirclean forces re-extraction from external source)
rm -rf "$F12_WORK/build"
mkdir -p "$F12_WORK/build"
cp "$F12_WORK/src/"* "$F12_WORK/build/"
cc -O2 -Wall "$F12_WORK/build/appliance-diag.c" -o "$F12_WORK/build/appliance-diag"
touch "$F12_WORK/build/.stamp_extracted" "$F12_WORK/build/.stamp_built" "$F12_WORK/build/.stamp_target_installed"
cp "$F12_WORK/build/appliance-diag" "$F12_WORK/target/usr/bin/appliance-diag"
RECOVERED_OUT=$("$F12_WORK/target/usr/bin/appliance-diag")
TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] F12 dirclean targeted recovery refreshes source rev ... "
if grep -q "SOURCE-REV=2.0" <<<"$RECOVERED_OUT"; then
    echo "PASS (updated SOURCE-REV=2.0 observed)"
    PASSED=$((PASSED + 1))
else
    echo "FAIL"
    exit 1
fi

# Step 6: Verify runtime binder accepts updated SOURCE-REV=2.0
"$PY" scripts/make_sample_output_tree.py --out "$F12_WORK/tree" --mode healthy >/dev/null
F12_IMG="$F12_WORK/tree/images/rootfs.cpio.gz"
F12_IMG_SHA=$(sha256sum "$F12_IMG" | awk '{print $1}')
cat > "$F12_WORK/prov.conf" <<EOF
machine: virt,highmem=off,gic-version=2
cpu: cortex-a7
memory: 512M
smp: 1
bootargs: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init
initrd_sha256: $F12_IMG_SHA
EOF
cat > "$F12_WORK/boot.log" <<EOF
[    0.000000] Kernel command line: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init
APPLIANCE-OVERLAY-BOOT-MARKER
APPLIANCE-DIAG-BEGIN
SOURCE-REV=2.0
BUILD-ID=2.0
APPLIANCE-RELEASE=EMBED-SYSTEM P3-M06 appliance release 1.0
DT-MODEL=linux,dummy-virt
APPLIANCE-DIAG-END
EOF

TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] runtime binder accepts updated SOURCE-REV=2.0 ... "
set +e
"$PY" scripts/verify_appliance_runtime.py "$F12_IMG" "$F12_WORK/prov.conf" "$F12_WORK/boot.log" \
    --overlay "$OVERLAY" --expect-source-rev "2.0" >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 0 ]; then echo "PASS"; PASSED=$((PASSED + 1)); else echo "FAIL (rc=$RC)"; exit 1; fi

TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] runtime binder rejects stale SOURCE-REV=1.0 when 2.0 expected ... "
set +e
"$PY" scripts/verify_appliance_runtime.py "$F12_IMG" "$F12_WORK/prov.conf" "$F12_WORK/boot.log" \
    --overlay "$OVERLAY" --expect-source-rev "1.0" >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 1 ]; then echo "PASS"; PASSED=$((PASSED + 1)); else echo "FAIL (rc=$RC, expected 1)"; exit 1; fi

# --- 9c. S2-R2-2: effective configuration validation controls -----------------
# Generate simulated effective .config (superset of defconfig with Buildroot internal symbols)
cat "$CANONICAL" > "$WORK/effective-healthy.conf"
cat >> "$WORK/effective-healthy.conf" <<EOF
BR2_HAVE_DOT_CONFIG=y
BR2_VERSION="2026.05.2"
BR2_HOST_GCC_AT_LEAST_4_9=y
BR2_TOOLCHAIN_USES_GLIBC=y
EOF

TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] PASS expected: effective resolved .config passes with --effective ... "
set +e
"$PY" scripts/verify_br_config.py "$WORK/effective-healthy.conf" --profile "$COMPLETE_PROFILE" \
    --symbol-table "$SYMBOLS" --effective >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 0 ]; then echo "PASS"; PASSED=$((PASSED + 1)); else echo "FAIL (rc=$RC, expected 0)"; exit 1; fi

# Effective config with missing required kernel setting must REJECT
sed 's/BR2_LINUX_KERNEL_ZIMAGE=y/BR2_LINUX_KERNEL_ZIMAGE=n/' \
    "$WORK/effective-healthy.conf" > "$WORK/effective-wrong-zimage.conf"
TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] semantic REJECT expected: effective config missing required zImage ... "
set +e
out=$("$PY" scripts/verify_br_config.py "$WORK/effective-wrong-zimage.conf" --profile "$COMPLETE_PROFILE" \
    --symbol-table "$SYMBOLS" --effective 2>&1)
RC=$?
set -e
if [ "$RC" -eq 1 ] && grep -q "REJECT" <<<"$out"; then
    echo "PASS (intended semantic REJECT)"
    PASSED=$((PASSED + 1))
else
    echo "FAIL (rc=$RC, expected 1)"
    exit 1
fi

# --- 10. positive reference controls ----------------------------------------
assert_pass "canonical defconfig against the taught contract" "$CANONICAL" "$TAUGHT_PROFILE"
assert_pass "canonical defconfig against the complete contract" "$CANONICAL" "$COMPLETE_PROFILE"

TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] positive control: repaired Gate fragment passes ... "
cp "$CANONICAL" "$WORK/gate-repaired.conf"
set +e
"$PY" scripts/verify_br_config.py "$WORK/gate-repaired.conf" --profile "$COMPLETE_PROFILE" \
    --symbol-table "$SYMBOLS" --quiet >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 0 ]; then echo "PASS"; PASSED=$((PASSED + 1)); else echo "FAIL (rc=$RC)"; exit 1; fi

echo "================================================================"
echo "=== ALL $PASSED / $TOTAL P3-M06 MUTATION & REFERENCE CHECKS PASSED ==="
echo "================================================================"
