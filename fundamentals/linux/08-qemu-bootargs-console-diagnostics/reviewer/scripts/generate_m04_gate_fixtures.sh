#!/bin/bash
set -euo pipefail

# Reviewer-isolated fixture generator for P3-M04 Gate (REVIEWER-ONLY).
# Materializes an opaque non-canonical starter launch configuration for the
# canonical-boot transfer task plus the reviewer-only fixed reference.
# Learner workflows must never execute this script; the values below are
# hidden. The starter is deliberately NOT the canonical answer and NOT a
# trivial typo of it: the learner must independently derive the canonical
# contract and prove it with fresh runtime evidence.

OUT_DIR="${1:-gate/fixtures}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
REF_DIR="$M04_ROOT/reviewer/reference"

mkdir -p "$OUT_DIR" "$REF_DIR"

# --- hidden starter variant (rotated Round 1): unfamiliar transfer ---
cat > "$OUT_DIR/starter_launch.sh" << 'EOF'
#!/bin/bash
# Opaque Gate starter configuration (reviewer-authored).
# This starter is NOT canonical: diagnose it against the module contract,
# author the canonical candidate independently, and prove it with a fresh
# QEMU capture. Copying these lines verbatim cannot pass.
MACHINE="-machine virt,highmem=off,gic-version=2"
CPU="-cpu cortex-a7"
MEM="-m 256M"
SMP="-smp 1"
DISPLAY_OPT="-nographic"
BOOTARGS="earlycon=pl011,0x09000000 console=ttyAMA0,115200 console=ttyAMA0 rdinit=/sbin/init"
qemu-system-arm $MACHINE $CPU $MEM $SMP $DISPLAY_OPT -kernel "$KERNEL" -initrd "$INITRD" -append "$BOOTARGS"
EOF
chmod 755 "$OUT_DIR/starter_launch.sh"
# --- end hidden variant ---

# Reviewer-only canonical reference.
cat > "$REF_DIR/gate_launch.sh" << 'EOF'
#!/bin/bash
# REVIEWER-ONLY reference (never learner-facing).
MACHINE="-machine virt,highmem=off,gic-version=2"
CPU="-cpu cortex-a7"
MEM="-m 512M"
SMP="-smp 1"
DISPLAY_OPT="-nographic"
BOOTARGS="earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init"
qemu-system-arm $MACHINE $CPU $MEM $SMP $DISPLAY_OPT -kernel "$KERNEL" -initrd "$INITRD" -append "$BOOTARGS"
EOF
chmod 755 "$REF_DIR/gate_launch.sh"

echo "[GEN] M04 gate fixtures materialized in: $OUT_DIR/starter_launch.sh"
