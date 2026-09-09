#!/bin/bash
set -euo pipefail

# Reviewer-isolated fixture generator for P3-M04 Challenge (REVIEWER-ONLY).
# Materializes an opaque broken launch configuration for the silent-boot
# isolation task plus the reviewer-only fixed reference. Learner workflows
# must never execute this script; the defect values below are hidden.

OUT_DIR="${1:-challenge/fixtures}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
REF_DIR="$M04_ROOT/reviewer/reference"

mkdir -p "$OUT_DIR" "$REF_DIR"

# --- hidden defective variant (rotated Round 1): total-silence family ---
cat > "$OUT_DIR/broken_launch.sh" << 'EOF'
#!/bin/bash
# Opaque Challenge launch configuration (reviewer-authored).
# Symptom: terminal stays completely silent after the decompressor line.
MACHINE="-machine virt,highmem=off,gic-version=2"
CPU="-cpu cortex-a7"
MEM="-m 512M"
SMP="-smp 1"
DISPLAY_OPT="-nographic"
BOOTARGS="console=ttyS0,115200 rdinit=/init"
qemu-system-arm $MACHINE $CPU $MEM $SMP $DISPLAY_OPT -kernel "$KERNEL" -initrd "$INITRD" -append "$BOOTARGS"
EOF
chmod 755 "$OUT_DIR/broken_launch.sh"
# --- end hidden variant ---

# Reviewer-only fixed reference (canonical silent-boot repair).
cat > "$REF_DIR/challenge_launch.sh" << 'EOF'
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
chmod 755 "$REF_DIR/challenge_launch.sh"

echo "[GEN] M04 challenge fixtures materialized in: $OUT_DIR/broken_launch.sh"
