#!/usr/bin/env bash
# Oracle regression suite for P3-M05 (REVIEWER-ONLY).
#
# Verifies that the assessment oracle itself behaves correctly: it accepts a
# genuinely repaired artifact, rejects each seeded defect family, rejects a
# plausible-but-wrong repair, and classifies an unparseable artifact as an ERROR
# rather than a semantic rejection.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M05_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M05_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

CANONICAL="fixtures/qemu-virt.dtb"
WORK="build/reviewer-m05-oracle"
rm -rf "$WORK" 2>/dev/null || true
mkdir -p "$WORK"

TOTAL=0
PASSED=0

run_oracle() {
    # run_oracle <expected-rc> <name> <candidate> [assessment]
    local expected="$1" name="$2" candidate="$3" assessment="${4:-gate}"
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] $name (expect rc=$expected) ... "
    set +e
    local out rc
    out=$(bash reviewer/oracle_m05.sh "$candidate" "$assessment" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq "$expected" ]; then
        echo "PASS"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc)"
        echo "$out"
        exit 1
    fi
}

echo "================================================================"
echo "=== P3-M05 Oracle Regression Suite (REVIEWER-ONLY)            ==="
echo "================================================================"

# 1. A genuinely correct artifact is accepted (positive reference).
run_oracle 0 "canonical tree accepted as a repaired Gate candidate" "$CANONICAL" gate

# 2. The opaque Gate seed is rejected.
run_oracle 1 "opaque Gate seed rejected" "gate/fixtures/starter_virt.dtb" gate

# 3. The opaque Challenge seed is rejected under both assessments.
run_oracle 1 "opaque Challenge seed rejected (challenge)" "challenge/fixtures/starter_virt.dtb" challenge
run_oracle 1 "opaque Challenge seed rejected (gate)" "challenge/fixtures/starter_virt.dtb" gate

# 4. A plausible but wrong repair is rejected: the availability defect is
#    repaired but the resource-window defect is left in place.
"$PY" scripts/fdt_patch.py --in gate/fixtures/starter_virt.dtb \
    --out "$WORK/half_repaired.dtb" \
    --set-string "/pl061@9030000" status okay >/dev/null
run_oracle 1 "half-repaired Gate candidate rejected" "$WORK/half_repaired.dtb" gate

# 5. Repairing the wrong node is rejected.
"$PY" scripts/fdt_patch.py --in gate/fixtures/starter_virt.dtb \
    --out "$WORK/wrong_node.dtb" \
    --set-string "/pl031@9010000" status okay >/dev/null
run_oracle 1 "Gate candidate repaired on the wrong node rejected" "$WORK/wrong_node.dtb" gate

# 6. A structurally invalid artifact is an ERROR, not a rejection.
head -c 300 "$CANONICAL" > "$WORK/truncated.dtb"
run_oracle 2 "truncated candidate classified as ERROR" "$WORK/truncated.dtb" gate

# 7. A missing candidate is a rejection (the oracle cannot grade nothing).
run_oracle 1 "absent candidate rejected" "$WORK/does-not-exist.dtb" gate

# 8. Fully repaired Gate candidate is accepted.
"$PY" scripts/fdt_patch.py --in "$CANONICAL" --out "$WORK/fully_repaired.dtb" \
    --set-string "/pl061@9030000" status okay >/dev/null
run_oracle 0 "fully repaired Gate candidate accepted" "$WORK/fully_repaired.dtb" gate

echo "================================================================"
echo "=== ALL $PASSED / $TOTAL P3-M05 ORACLE REGRESSION CHECKS PASSED ==="
echo "================================================================"
