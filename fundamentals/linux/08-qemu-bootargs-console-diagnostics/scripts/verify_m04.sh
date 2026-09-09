#!/bin/bash
set -euo pipefail

# Learner-Safe Master Verification Script for P3-M04
# Audits documentation completeness, boot milestone ordering against the
# STATIC teaching reference log, and assessment workspace provisioning.
# The starter/broken assessment configs are DELIBERATELY non-canonical, so
# this script asserts their opaque presence and parseability — never their
# validity. Validity is proven by the reviewer oracle against references.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

echo "================================================================"
echo "=== Running P3-M04 Learner-Safe Verification                 ==="
echo "================================================================"

# 1. Verify Module Structure
REQUIRED_FILES=(
    "SOURCE_LEDGER.md"
    "labs/01-earlycon-boot/README.md"
    "labs/02-console-handoff-mismatch/README.md"
    "labs/03-bootlog-milestones/README.md"
    "faults/F04-bad-bootargs-root/README.md"
    "faults/F05-console-mismatch/README.md"
    "faults/F06-insufficient-ram/README.md"
    "faults/integration-F07-F09/README.md"
    "challenge/README.md"
    "gate/README.md"
    "challenge/fixtures/broken_launch.sh"
    "gate/fixtures/starter_launch.sh"
    "fixtures/reference_boot.log"
    "scripts/audit_boot_milestones.sh"
    "scripts/verify_boot_contract.sh"
    "scripts/verify_runtime_boot.sh"
    "scripts/run_qemu_diagnostic.sh"
    "scripts/calibrate_f06_ram.sh"
)

echo "=== Step 1: Auditing Module Documentation & Scripts ==="
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$M04_ROOT/$file" ]; then
        echo "REJECT: Missing required file: $file" >&2
        exit 1
    fi
    echo "[PASS] Found: $file"
done

# 2. Audit Reference Boot Log Milestones (STATIC teaching fixture only).
echo "=== Step 2: Auditing Boot Milestones on Reference Boot Log (static) ==="
bash "$M04_ROOT/scripts/audit_boot_milestones.sh" "$M04_ROOT/fixtures/reference_boot.log"

# 3. Audit Assessment Workspace Provisioning (presence, not validity).
echo "=== Step 3: Auditing Assessment Workspace Provisioning ==="
make -C "$M04_ROOT/gate" provision >/dev/null
make -C "$M04_ROOT/challenge" provision >/dev/null
for candidate in "$M04_ROOT/gate/build/candidate_boot_config.sh" \
                 "$M04_ROOT/challenge/build/candidate_launch.sh"; do
    [ -f "$candidate" ] || { echo "REJECT: Provisioned candidate missing: $candidate" >&2; exit 1; }
    grep -Eq 'BOOTARGS=' "$candidate" || { echo "REJECT: Provisioned candidate has no BOOTARGS: $candidate" >&2; exit 1; }
    echo "[PASS] Provisioned: $candidate"
done
echo "[NOTE] Provisioned starters are deliberately non-canonical; validity is reviewer-graded."

echo "================================================================"
echo "=== ALL P3-M04 LEARNER-SAFE CHECKS PASSED                    ==="
echo "================================================================"
