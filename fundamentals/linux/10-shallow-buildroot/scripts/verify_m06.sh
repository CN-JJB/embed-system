#!/usr/bin/env bash
# Learner-safe master verification for P3-M06.
#
# Checks documentation completeness, the integrity of the committed fixtures,
# the self-consistency of the taught contract profile against the canonical
# defconfig, that every declared symbol really exists in the recorded
# Buildroot 2026.05.2 symbol table, and that the synthetic output-tree sample
# exercises the audit tooling.  It never reports which invariant a provisioned
# assessment fragment violates -- that is reviewer-only grading.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M06_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M06_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

echo "================================================================"
echo "=== Running P3-M06 Learner-Safe Verification                  ==="
echo "================================================================"

REQUIRED_FILES=(
    "README.md"
    "SOURCE_LEDGER.md"
    "Makefile"
    "labs/01-configure-cortex-a7/README.md"
    "labs/02-rootfs-overlay/README.md"
    "labs/03-kernel-rootfs-image-integration/README.md"
    "labs/04-output-tree-provenance-audit/README.md"
    "labs/05-incremental-rebuild-drift/README.md"
    "faults/F12-buildroot-stamp-fault/README.md"
    "challenge/README.md"
    "gate/README.md"
    "challenge/fixtures/starter.conf"
    "gate/fixtures/starter.conf"
    "fixtures/buildroot-symbols.json"
    "fixtures/profiles/buildroot-2026.05.2-taught.json"
    "fixtures/br2-external/external.desc"
    "fixtures/br2-external/external.mk"
    "fixtures/br2-external/Config.in"
    "fixtures/br2-external/configs/qemu_virt_a7_defconfig"
    "fixtures/br2-external/package/appliance-diag/Config.in"
    "fixtures/br2-external/package/appliance-diag/appliance-diag.mk"
    "fixtures/br2-external/package/appliance-diag/src/appliance-diag.c"
    "fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay/etc/appliance-release"
    "fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay/etc/init.d/S99appliance-diag"
    "fixtures/output-tree-sample/SYNTHETIC"
    "fixtures/output-tree-sample/images/rootfs.cpio.gz"
    "scripts/verify_br_config.py"
    "scripts/audit_output_tree.py"
    "scripts/make_sample_output_tree.py"
    "scripts/build_appliance.sh"
    "scripts/run_buildroot_appliance.sh"
    "scripts/verify_appliance_runtime.py"
)

echo "=== Step 1: Auditing module documentation and tooling ==="
for file in "${REQUIRED_FILES[@]}"; do
    [ -f "$file" ] || { echo "REJECT: missing required file: $file" >&2; exit 1; }
    echo "[PASS] found: $file"
done

echo "=== Step 2: Canonical defconfig satisfies the taught contract ==="
"$PY" scripts/verify_br_config.py fixtures/br2-external/configs/qemu_virt_a7_defconfig --quiet

echo "=== Step 3: Every declared symbol exists in the recorded 2026.05.2 symbol table ==="
"$PY" scripts/verify_br_config.py fixtures/br2-external/configs/qemu_virt_a7_defconfig \
    --symbol-table fixtures/buildroot-symbols.json --quiet

echo "=== Step 4: Symbol table provenance is complete ==="
"$PY" - <<'PYEOF'
import json, sys
table = json.load(open("fixtures/buildroot-symbols.json", encoding="utf-8"))
missing = []
for group in ("symbols", "external_symbols"):
    for symbol, meta in table.get(group, {}).items():
        for field in ("file", "line", "kind"):
            if field not in meta:
                missing.append(f"{symbol}.{field}")
if missing:
    print(f"REJECT: symbol table entries missing provenance: {missing[:6]}", file=sys.stderr)
    sys.exit(1)
total = len(table.get("symbols", {})) + len(table.get("external_symbols", {}))
print(f"[PASS] {total} symbol(s) recorded with file/line/kind provenance")
PYEOF

echo "=== Step 5: Synthetic output-tree sample is self-consistent ==="
"$PY" scripts/audit_output_tree.py \
    --output fixtures/output-tree-sample \
    --overlay fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay --quiet

echo "=== Step 6: The audit detects a stale image (sample, stale mode) ==="
"$PY" scripts/make_sample_output_tree.py --out build/verify-stale --mode stale >/dev/null
set +e
"$PY" scripts/audit_output_tree.py --output build/verify-stale \
    --overlay fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay --quiet >/dev/null 2>&1
STALE_RC=$?
set -e
if [ "$STALE_RC" -eq 1 ]; then
    echo "[PASS] the audit rejects a stale image (output/target updated, image not re-packaged)"
else
    echo "REJECT: the audit did not detect the stale image (rc=$STALE_RC)" >&2
    exit 1
fi

echo "=== Step 7: Assessment workspaces are provisioned and well formed ==="
for dir in challenge gate; do
    [ -f "$dir/fixtures/starter.conf" ] || { echo "REJECT: $dir fixture missing" >&2; exit 1; }
    "$PY" scripts/verify_br_config.py "$dir/fixtures/starter.conf" --quiet >/dev/null 2>&1 \
        && echo "[PASS] $dir starter fragment is well formed (it may or may not satisfy the contract)" \
        || echo "[PASS] $dir starter fragment is a well-formed fragment that violates the taught contract"
done
echo "[NOTE] Which invariant each provisioned fragment violates is reviewer-only information."

echo "================================================================"
echo "=== ALL P3-M06 LEARNER-SAFE CHECKS PASSED                     ==="
echo "================================================================"
