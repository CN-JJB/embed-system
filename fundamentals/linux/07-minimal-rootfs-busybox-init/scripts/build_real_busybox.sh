#!/bin/bash
set -euo pipefail

# Real BusyBox 1.36.1 Static ARM Build & Rootfs Staging (BUILD-ONLY TARGET)
# Pinned Commit: 1a64f6a20aaf6ea4dbba68bbfa8cc1ab7e5c57c4
#
# Builds real statically linked BusyBox and populates applet symlinks
# into an isolated staging rootfs.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

BUSYBOX_SRC="${1:-${BUSYBOX_SRC:-/tmp/busybox-1.36.1}}"
INSTALL_DIR="${2:-${INSTALL_DIR:-/tmp/rootfs-busybox-staging}}"
PINNED_COMMIT="1a64f6a20aaf6ea4dbba68bbfa8cc1ab7e5c57c4"

echo "=================================================================="
echo "=== Real BusyBox 1.36.1 Static ARM Build & Installation        ==="
echo "=================================================================="

# 1. Audit Upstream Source Identity
echo "=== Step 1: Auditing Upstream BusyBox Source Identity ==="
if [ ! -d "$BUSYBOX_SRC" ] || [ ! -d "$BUSYBOX_SRC/.git" ]; then
    echo "ERROR: BusyBox source tree not found at: $BUSYBOX_SRC" >&2
    echo "To clone the pinned BusyBox tree, run:" >&2
    echo "  git clone --depth 1 --branch 1_36_1 https://github.com/mirror/busybox.git $BUSYBOX_SRC" >&2
    exit 1
fi

ACTUAL_COMMIT=$(git -C "$BUSYBOX_SRC" rev-parse HEAD)
if [ "$ACTUAL_COMMIT" != "$PINNED_COMMIT" ]; then
    echo "ERROR: Target source commit ($ACTUAL_COMMIT) does not match canonical pin ($PINNED_COMMIT)!" >&2
    exit 1
fi
echo "[PASS] Verified pinned BusyBox source commit: $ACTUAL_COMMIT"

# 2. Check Toolchain
echo "=== Step 2: Checking Cross-Compilation Toolchain ==="
CROSS_COMPILE="${CROSS_COMPILE:-arm-none-linux-gnueabihf-}"
if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    echo "ERROR: Cross-compiler '${CROSS_COMPILE}gcc' not found in PATH." >&2
    echo "For Ubuntu/Debian distro toolchain, pass: CROSS_COMPILE=arm-linux-gnueabihf- $0" >&2
    exit 1
fi

CC="${CROSS_COMPILE}gcc"
echo "[PASS] Toolchain prefix: $CROSS_COMPILE"
echo "       Compiler: $(command -v "$CC")"
echo "       Version:  $("$CC" --version | head -n 1)"
echo "       Machine:  $("$CC" -dumpmachine)"

# 3. Configure BusyBox: defconfig + CONFIG_STATIC=y + CONFIG_TC=n
echo "=== Step 3: Configuring BusyBox (defconfig + CONFIG_STATIC=y) ==="
make -C "$BUSYBOX_SRC" defconfig >/dev/null

# Apply static linkage
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' "$BUSYBOX_SRC/.config"
if ! grep -q "^CONFIG_STATIC=y" "$BUSYBOX_SRC/.config"; then
    echo "CONFIG_STATIC=y" >> "$BUSYBOX_SRC/.config"
fi

# Disable CONFIG_TC (dropped CBQ headers in modern glibc headers)
sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' "$BUSYBOX_SRC/.config"

# Validate configuration
grep -q "^CONFIG_STATIC=y" "$BUSYBOX_SRC/.config" || { echo "ERROR: Failed to set CONFIG_STATIC=y"; exit 1; }
echo "[PASS] BusyBox configured for static linkage"

# 4. Compile BusyBox
echo "=== Step 4: Compiling Static ARM BusyBox Binary ==="
NPROCS=$(nproc 2>/dev/null || echo 4)
make -C "$BUSYBOX_SRC" -j"$NPROCS" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" busybox

REAL_BUSYBOX="$BUSYBOX_SRC/busybox"
[ -f "$REAL_BUSYBOX" ] || { echo "ERROR: BusyBox binary failed to build!"; exit 1; }

# 5. Audit Real ELF Artifact
echo "=== Step 5: Auditing Compiled BusyBox ELF Binary ==="
bash "$M03_ROOT/scripts/audit_busybox_elf.sh" "$REAL_BUSYBOX"
echo "[PASS] Real BusyBox ELF binary conforms strictly to static ARM contract"

# 6. Install Applets into Staging Rootfs
echo "=== Step 6: Installing BusyBox Applets to Staging Directory ==="
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
make -C "$BUSYBOX_SRC" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" install CONFIG_PREFIX="$INSTALL_DIR" >/dev/null

# Audit installed applets
[ -f "$INSTALL_DIR/bin/busybox" ] || { echo "ERROR: $INSTALL_DIR/bin/busybox missing!"; exit 1; }
[ -L "$INSTALL_DIR/bin/sh" ] || { echo "ERROR: $INSTALL_DIR/bin/sh missing or not symlink!"; exit 1; }
[ -L "$INSTALL_DIR/sbin/init" ] || { echo "ERROR: $INSTALL_DIR/sbin/init missing or not symlink!"; exit 1; }

APPLET_COUNT=$(find "$INSTALL_DIR" -type l | wc -l)
echo "[PASS] BusyBox installed successfully into: $INSTALL_DIR ($APPLET_COUNT applets created)"
