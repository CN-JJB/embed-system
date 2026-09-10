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
    "challenge/fixtures/broken_manifest.conf"
    "gate/fixtures/starter_manifest.conf"
    "fixtures/reference_boot.log"
    "scripts/audit_boot_milestones.sh"
    "scripts/verify_boot_contract.sh"
    "scripts/verify_runtime_boot.sh"
    "scripts/run_qemu_diagnostic.sh"
    "scripts/run_candidate_manifest.sh"
    "scripts/parse_candidate_manifest.py"
    "scripts/verify_candidate_runtime.sh"
    "scripts/verify_m04_candidate.sh"
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

# 3. Audit Assessment Workspace Provisioning (presence + data-only schema,
#    never validity: the provisioned starters are deliberately non-canonical).
echo "=== Step 3: Auditing Assessment Workspace Provisioning ==="
make -C "$M04_ROOT/gate" provision >/dev/null
make -C "$M04_ROOT/challenge" provision >/dev/null
for candidate in "$M04_ROOT/gate/build/candidate_boot_manifest.conf" \
                 "$M04_ROOT/challenge/build/candidate_launch_manifest.conf"; do
    [ -f "$candidate" ] || { echo "REJECT: Provisioned candidate missing: $candidate" >&2; exit 1; }
    for key in MACHINE CPU MEM SMP NOGRAPHIC BOOTARGS; do
        grep -Eq "^$key=" "$candidate" \
            || { echo "REJECT: Provisioned candidate lacks '$key': $candidate" >&2; exit 1; }
    done
    echo "[PASS] Provisioned data-only manifest: $candidate"
done
echo "[NOTE] Provisioned starters are deliberately non-canonical; validity is reviewer-graded."

# 4. Audit the manifest interpreter wiring (single source of truth).
echo "=== Step 4: Auditing Candidate Manifest Parser Availability ==="
PARSER_SELFTEST=$(mktemp /tmp/m04_parser_selftest_XXXXXX.conf)
printf '%s\n' \
    'MACHINE=virt,highmem=off,gic-version=2' \
    'CPU=cortex-a7' \
    'MEM=512M' \
    'SMP=1' \
    'NOGRAPHIC=true' \
    'BOOTARGS=earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init' \
    > "$PARSER_SELFTEST"
if ! python3 "$M04_ROOT/scripts/parse_candidate_manifest.py" \
        --manifest "$PARSER_SELFTEST" >/dev/null; then
    rm -f "$PARSER_SELFTEST"
    echo "REJECT: parser does not accept a canonical launch manifest." >&2
    exit 1
fi
rm -f "$PARSER_SELFTEST"
echo "[PASS] Parser accepts a canonical launch manifest."

grep -Eq 'run_candidate_manifest\.sh' "$M04_ROOT/gate/Makefile" \
    || { echo "REJECT: Gate capture does not run candidates through the trusted manifest runner." >&2; exit 1; }
echo "[PASS] Gate capture executes the learner manifest through the trusted runner."

echo "================================================================"
echo "=== ALL P3-M04 LEARNER-SAFE CHECKS PASSED                    ==="
echo "================================================================"
