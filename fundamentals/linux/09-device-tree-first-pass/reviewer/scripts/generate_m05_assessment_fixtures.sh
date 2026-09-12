#!/usr/bin/env bash
# P3-M05 REVIEWER-ONLY assessment fixture generator.
#
# Materialises the opaque assessment artifacts for the Challenge and the Module
# Gate, plus the hidden seed mapping the oracle grades against.
#
# Seed design (see also reviewer/reference/*_seed.json):
#
#   Challenge -- an interrupt-specifier defect on the console node.  Same fault
#                FAMILY as the worked F11 tutorial (a resource value that is
#                wrong while every number remains individually plausible), but a
#                different property and a different detection path.  It is
#                inside the *taught* contract profile, so the learner-facing
#                tooling can confirm the repair.
#
#   Gate      -- a combined, unfamiliar variant, deliberately OUTSIDE the taught
#                contract profile:
#                  * an availability defect on a non-console peripheral, and
#                  * a window-size defect on a virtio-mmio window that is not
#                    individually listed in the taught profile, which silently
#                    overlaps the next window in the bank.
#                Both are structurally valid.  Neither is caught by the taught
#                profile; they are caught only by the complete contract, i.e. by
#                reasoning from the machine description the learner captured in
#                Lab 5.1.
#
# Usage: generate_m05_assessment_fixtures.sh [challenge-dir] [gate-dir]
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M05_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
cd "$M05_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

CHALLENGE_DIR="${1:-challenge/fixtures}"
GATE_DIR="${2:-gate/fixtures}"

mkdir -p "$CHALLENGE_DIR" "$GATE_DIR" reviewer/reference

CANONICAL="fixtures/qemu-virt.dtb"
[ -f "$CANONICAL" ] || { echo "FATAL: canonical fixture missing: $CANONICAL" >&2; exit 1; }

echo "=== Materialising P3-M05 assessment fixtures (REVIEWER-ONLY) ==="

# --- Challenge seed: wrong interrupt specifier on the console node ----------
"$PY" scripts/fdt_patch.py \
    --in "$CANONICAL" \
    --out "$CHALLENGE_DIR/starter_virt.dtb" \
    --set-cells "/pl011@9000000" interrupts 0x00 0x21 0x04 >/dev/null

cat > reviewer/reference/challenge_seed.json <<'JSON'
{
  "assessment": "challenge",
  "fault_family": "F11-family resource value (interrupt specifier)",
  "variant": "console UART interrupt specifier names the wrong SPI",
  "seeded_edits": [
    {"op": "set-cells", "path": "/pl011@9000000", "prop": "interrupts",
     "value": [0, 33, 4],
     "note": "structurally valid 3-cell specifier; SPI 33 instead of SPI 1 under the GIC #interrupt-cells = 3 binding"}
  ],
  "expected_repair": "restore the console interrupt specifier to the SPI the GIC model routes for that UART",
  "taught_profile_detects": true,
  "oracle_invariants": ["uart.interrupts.specifiers"],
  "note": "Same family as faults/F11-bad-mmio-reg-address, different property and node than the worked tutorial."
}
JSON

# --- Gate seed: combined unfamiliar variant, outside the taught profile -----
"$PY" scripts/fdt_patch.py \
    --in "$CANONICAL" \
    --out "$GATE_DIR/starter_virt.dtb" \
    --set-string "/pl061@9030000" status disabled \
    --set-cells "/virtio_mmio@a000200" reg 0x00 0x0a000200 0x00 0x400 >/dev/null

cat > reviewer/reference/gate_seed.json <<'JSON'
{
  "assessment": "gate",
  "fault_family": "availability (F10 family) + resource-window (F11 family)",
  "variant": "combined unfamiliar variant, both defects outside the taught contract profile",
  "seeded_edits": [
    {"op": "set-string", "path": "/pl061@9030000", "prop": "status", "value": "disabled",
     "note": "the GPIO controller is described but no longer available"},
    {"op": "set-cells", "path": "/virtio_mmio@a000200", "prop": "reg",
     "value": [0, 167772672, 0, 1024],
     "note": "window size 0x400 instead of 0x200; silently overlaps /virtio_mmio@a000400"}
  ],
  "expected_repair": "restore the peripheral's availability and the virtio-mmio window's size to what the QEMU virt hardware model presents",
  "taught_profile_detects": false,
  "oracle_invariants": ["gpio.status.value", "virtio_windows.sizes", "mmio.no-overlap"],
  "note": "The taught profile passes this artifact by design. Only the complete contract -- i.e. reasoning from the machine description captured in Lab 5.1 -- exposes it."
}
JSON

echo "[OK] challenge fixture : $CHALLENGE_DIR/starter_virt.dtb"
echo "[OK] gate fixture      : $GATE_DIR/starter_virt.dtb"
echo "[OK] hidden seed maps  : reviewer/reference/{challenge_seed,gate_seed}.json"
echo "=== Assessment fixtures materialised ==="
