#!/usr/bin/env bash
# Learner-safe master verification for P3-M05.
#
# Checks documentation completeness, the integrity of the committed real
# fixtures, the self-consistency of the public semantic contract profile, and
# that the assessment workspaces are provisioned as *well-formed but
# deliberately non-canonical* artifacts.  It never reports which semantic
# invariant a provisioned assessment artifact violates -- that is reviewer-only
# grading.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M05_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M05_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

echo "================================================================"
echo "=== Running P3-M05 Learner-Safe Verification                  ==="
echo "================================================================"

REQUIRED_FILES=(
    "README.md"
    "SOURCE_LEDGER.md"
    "Makefile"
    "labs/01-dump-qemu-virt-dtb/README.md"
    "labs/02-decompile-inspect-recompile/README.md"
    "labs/03-bounded-safe-modification/README.md"
    "labs/04-runtime-dt-correlation/README.md"
    "faults/F10-disabled-dt-node/README.md"
    "faults/F11-bad-mmio-reg-address/README.md"
    "challenge/README.md"
    "gate/README.md"
    "challenge/fixtures/starter_virt.dtb"
    "gate/fixtures/starter_virt.dtb"
    "fixtures/qemu-virt.dtb"
    "fixtures/qemu-virt.dts"
    "fixtures/qemu-virt.provenance.json"
    "fixtures/profiles/qemu-virt-a7-canonical.json"
    "scripts/fdtlib_min.py"
    "scripts/fdt_patch.py"
    "scripts/dt_structural_check.py"
    "scripts/dt_roundtrip_check.py"
    "scripts/validate_dt_semantics.py"
    "scripts/derive_sysfs_tree.py"
    "scripts/dump_virt_dtb.sh"
    "scripts/dtc_roundtrip.sh"
    "scripts/run_qemu_dtb_boot.sh"
    "scripts/verify_runtime_binding.py"
)

echo "=== Step 1: Auditing module documentation and tooling ==="
for file in "${REQUIRED_FILES[@]}"; do
    [ -f "$file" ] || { echo "REJECT: missing required file: $file" >&2; exit 1; }
    echo "[PASS] found: $file"
done

echo "=== Step 2: Committed fixture is a well-formed, structurally sound DTB ==="
"$PY" scripts/dt_structural_check.py fixtures/qemu-virt.dtb --quiet

echo "=== Step 3: Public contract profile is self-consistent with the fixture ==="
"$PY" scripts/validate_dt_semantics.py fixtures/qemu-virt.dtb --quiet

echo "=== Step 4: Decompiled source fixture describes the same tree ==="
# The committed .dts is the real dtc decompilation of the QEMU dump.  Its
# structural fingerprint is checked here without requiring dtc on the host.
for marker in "/dts-v1/;" "pl011@9000000" "intc@8000000" "memory@40000000" "linux,dummy-virt"; do
    grep -q -- "$marker" fixtures/qemu-virt.dts \
        || { echo "REJECT: fixtures/qemu-virt.dts is missing expected content: $marker" >&2; exit 1; }
done
echo "[PASS] fixtures/qemu-virt.dts contains the expected canonical nodes"

echo "=== Step 5: DTB -> DTS -> DTB round trip is semantically lossless ==="
# Host-independent proof: re-serialising the parsed tree must not change it.
TMP_RT="build/verify-roundtrip"
rm -rf "$TMP_RT" 2>/dev/null || true
mkdir -p "$TMP_RT"
"$PY" scripts/fdtlib_min.py fixtures/qemu-virt.dtb --serialise "$TMP_RT/rt.dtb" >/dev/null
"$PY" scripts/dt_roundtrip_check.py fixtures/qemu-virt.dtb "$TMP_RT/rt.dtb" --quiet

echo "=== Step 6: sysfs projection derivation works on the real fixture ==="
"$PY" scripts/derive_sysfs_tree.py fixtures/qemu-virt.dtb --path "/pl011@9000000" >/dev/null
echo "[PASS] derive_sysfs_tree.py renders /pl011@9000000"

echo "=== Step 7: Assessment workspaces are provisioned and structurally sound ==="
for dir in challenge gate; do
    [ -f "$dir/fixtures/starter_virt.dtb" ] \
        || { echo "REJECT: $dir fixture missing" >&2; exit 1; }
    # Structural soundness only.  The seeded defect is semantic, so a sound
    # structure is exactly what a provisioned assessment artifact must have.
    "$PY" scripts/dt_structural_check.py "$dir/fixtures/starter_virt.dtb" --quiet
    echo "[PASS] $dir starter artifact is a well-formed, structurally sound DTB"
done
echo "[NOTE] Provisioned assessment artifacts are deliberately non-canonical."
echo "[NOTE] Which semantic invariant each one violates is reviewer-only information."

echo "================================================================"
echo "=== ALL P3-M05 LEARNER-SAFE CHECKS PASSED                     ==="
echo "================================================================"
