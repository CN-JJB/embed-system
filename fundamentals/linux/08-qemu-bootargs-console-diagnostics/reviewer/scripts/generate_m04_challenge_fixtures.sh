#!/bin/bash
set -euo pipefail

# Reviewer-isolated fixture generator for P3-M04 Challenge (REVIEWER-ONLY).
# Materializes an opaque broken data-only launch manifest for the silent-boot
# isolation task plus the reviewer-only fixed reference. Learner workflows
# must never execute this script; the defect values below are hidden.

OUT_DIR="${1:-challenge/fixtures}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
REF_DIR="$M04_ROOT/reviewer/reference"

mkdir -p "$OUT_DIR" "$REF_DIR"

# --- hidden defective variant (rotated Round 2): total-silence family ---
cat > "$OUT_DIR/broken_manifest.conf" << 'EOF'
# Opaque P3-M04 Challenge starter manifest (reviewer-authored).
# This starter is NOT canonical: diagnose it against the module contract,
# repair it, and prove the repair with a fresh runtime capture.
# Data-only format: KEY=value, one definition per key, no shell content.
MACHINE=virt,highmem=off,gic-version=2
CPU=cortex-a7
MEM=512M
SMP=1
NOGRAPHIC=true
BOOTARGS=console=ttyS0,115200 rdinit=/init
EOF
# --- end hidden variant ---

# Reviewer-only fixed reference (canonical silent-boot repair), data-only.
cat > "$REF_DIR/challenge_manifest.conf" << 'EOF'
# REVIEWER-ONLY reference (never learner-facing).
MACHINE=virt,highmem=off,gic-version=2
CPU=cortex-a7
MEM=512M
SMP=1
NOGRAPHIC=true
BOOTARGS=earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init
EOF

echo "[GEN] M04 challenge fixtures materialized in: $OUT_DIR/broken_manifest.conf"
echo "[GEN] Reviewer reference written to: $REF_DIR/challenge_manifest.conf"
