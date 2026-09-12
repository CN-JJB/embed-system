#!/usr/bin/env bash
# P3-M06 REVIEWER-ONLY assessment fixture generator.
#
# Materialises the opaque configuration fragments for the Challenge and the
# Module Gate from the canonical defconfig, plus the hidden seed mapping.
#
# Seed design:
#
#   Challenge -- a wrong ABI selection.  Same family as the architecture/ABI
#                contract taught in Lab 6.1, detected by the *taught* profile,
#                so the learner-facing tooling can confirm the repair.
#
#   Gate      -- a combined, unfamiliar variant, deliberately OUTSIDE the taught
#                profile: kernel version drift, a missing initramfs compression
#                selection (which breaks the documented launch contract while
#                every "image exists" check still passes), and an overlay path
#                that does not point at this repository's external tree.
#                The taught profile passes this fragment by design.
#
# Usage: generate_m06_assessment_fixtures.sh [challenge-dir] [gate-dir]
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M06_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
cd "$M06_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

CHALLENGE_DIR="${1:-challenge/fixtures}"
GATE_DIR="${2:-gate/fixtures}"
mkdir -p "$CHALLENGE_DIR" "$GATE_DIR" reviewer/reference

CANONICAL="fixtures/br2-external/configs/qemu_virt_a7_defconfig"
[ -f "$CANONICAL" ] || { echo "FATAL: canonical defconfig missing: $CANONICAL" >&2; exit 1; }

echo "=== Materialising P3-M06 assessment fixtures (REVIEWER-ONLY) ==="

# --- Challenge seed: wrong ABI (soft-float EABI instead of EABIhf) ----------
"$PY" - "$CANONICAL" "$CHALLENGE_DIR/starter.conf" <<'PYEOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
out = []
for line in open(src, "r", encoding="utf-8"):
    if line.strip() == "BR2_ARM_EABIHF=y":
        out.append("BR2_ARM_EABI=y\n")
    else:
        out.append(line)
open(dst, "w", encoding="utf-8").writelines(out)
PYEOF

cat > reviewer/reference/challenge_seed.json <<'JSON'
{
  "assessment": "challenge",
  "fault_family": "target ABI selection",
  "variant": "soft-float EABI selected instead of EABIhf",
  "seeded_edits": [
    {"op": "replace", "symbol": "BR2_ARM_EABIHF", "value": "y",
     "with": "BR2_ARM_EABI=y",
     "note": "the canonical Phase 3 userspace contract is hard-float; a soft-float EABI rootfs cannot run the hard-float userspace"}
  ],
  "expected_repair": "select the hard-float ABI the canonical target uses",
  "taught_profile_detects": true,
  "oracle_invariants": ["required.BR2_ARM_EABIHF", "forbidden.BR2_ARM_EABI"],
  "note": "Architecture/ABI family taught in Lab 6.1; the seeded instance is the opposite ABI, not a replay."
}
JSON

# --- Gate seed: combined unfamiliar variant ---------------------------------
"$PY" - "$CANONICAL" "$GATE_DIR/starter.conf" <<'PYEOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
out = []
for line in open(src, "r", encoding="utf-8"):
    stripped = line.strip()
    if stripped == 'BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="6.18.50"':
        out.append('BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="6.6.30"\n')
    elif stripped == "BR2_TARGET_ROOTFS_CPIO_GZIP=y":
        out.append("# BR2_TARGET_ROOTFS_CPIO_GZIP is not set\n")
    elif stripped.startswith('BR2_ROOTFS_OVERLAY='):
        out.append('BR2_ROOTFS_OVERLAY="$(BR2_EXTERNAL_QEMU_VIRT_A7_PATH)/board/'
                   'qemu-virt-a7/rootfs-overlay-legacy"\n')
    else:
        out.append(line)
open(dst, "w", encoding="utf-8").writelines(out)
PYEOF

cat > reviewer/reference/gate_seed.json <<'JSON'
{
  "assessment": "gate",
  "fault_family": "kernel version drift + initramfs image contract + overlay provenance",
  "variant": "combined unfamiliar variant, all three defects outside the taught profile",
  "seeded_edits": [
    {"op": "replace", "symbol": "BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE",
     "value": "\"6.18.50\"", "with": "\"6.6.30\"",
     "note": "the appliance would be built against a different kernel release than the pinned Phase 3 baseline"},
    {"op": "unset", "symbol": "BR2_TARGET_ROOTFS_CPIO_GZIP",
     "note": "the initramfs image would be produced uncompressed; every 'the image exists' check still passes, but the documented launch contract expects rootfs.cpio.gz"},
    {"op": "replace", "symbol": "BR2_ROOTFS_OVERLAY",
     "with": "\"$(BR2_EXTERNAL_QEMU_VIRT_A7_PATH)/board/qemu-virt-a7/rootfs-overlay-legacy\"",
     "note": "the overlay path names a directory that does not exist in this repository's external tree"}
  ],
  "expected_repair": "restore the pinned kernel version, the compressed initramfs selection and the real overlay path",
  "taught_profile_detects": false,
  "oracle_invariants": [
    "required.BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE",
    "required.BR2_TARGET_ROOTFS_CPIO_GZIP",
    "exact.BR2_ROOTFS_OVERLAY"
  ],
  "note": "The taught profile passes this fragment by design. Only the complete contract exposes it."
}
JSON

echo "[OK] challenge fragment : $CHALLENGE_DIR/starter.conf"
echo "[OK] gate fragment      : $GATE_DIR/starter.conf"
echo "[OK] hidden seed maps   : reviewer/reference/{challenge_seed,gate_seed}.json"
echo "=== Assessment fixtures materialised ==="
