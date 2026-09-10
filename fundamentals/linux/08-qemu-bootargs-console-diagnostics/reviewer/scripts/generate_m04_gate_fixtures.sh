#!/bin/bash
set -euo pipefail

# Reviewer-isolated fixture generator for P3-M04 Gate (REVIEWER-ONLY).
# Materializes an opaque non-canonical starter launch MANIFEST for the
# canonical-boot transfer task plus the reviewer-only fixed reference.
# Learner workflows must never execute this script; the values below are
# hidden. The starter is deliberately NOT the canonical answer and NOT a
# trivial typo of it: the learner must independently derive the canonical
# contract and prove it with fresh, candidate-bound runtime evidence.

OUT_DIR="${1:-gate/fixtures}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
REF_DIR="$M04_ROOT/reviewer/reference"

mkdir -p "$OUT_DIR" "$REF_DIR"

# --- hidden starter variant (rotated Round 2) ---
cat > "$OUT_DIR/starter_manifest.conf" << 'EOF'
# Opaque P3-M04 Gate starter manifest (reviewer-authored).
# This starter is deliberately NOT the canonical answer and NOT a trivial
# typo of it: derive the canonical contract independently, then prove it
# with a fresh runtime capture from this same manifest.
# Data-only format: KEY=value, one definition per key, no shell content.
MACHINE=virt,gic-version=2
CPU=cortex-a15
MEM=256M
SMP=2
NOGRAPHIC=true
BOOTARGS=earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/sbin/init
EOF
# --- end hidden variant ---

# Reviewer-only canonical reference (data-only, same schema as the candidate).
cat > "$REF_DIR/gate_manifest.conf" << 'EOF'
# REVIEWER-ONLY reference (never learner-facing).
MACHINE=virt,highmem=off,gic-version=2
CPU=cortex-a7
MEM=512M
SMP=1
NOGRAPHIC=true
BOOTARGS=earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init
EOF

echo "[GEN] M04 gate fixtures materialized in: $OUT_DIR/starter_manifest.conf"
echo "[GEN] Reviewer reference written to: $REF_DIR/gate_manifest.conf"
