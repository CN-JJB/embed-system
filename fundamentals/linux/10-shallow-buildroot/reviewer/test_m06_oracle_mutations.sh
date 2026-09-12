#!/usr/bin/env bash
# Oracle regression suite for P3-M06 (REVIEWER-ONLY).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M06_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M06_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

CANONICAL="fixtures/br2-external/configs/qemu_virt_a7_defconfig"
WORK="build/reviewer-m06-oracle"
rm -rf "$WORK" 2>/dev/null || true
mkdir -p "$WORK"

TOTAL=0
PASSED=0

run_oracle() {
    local expected="$1" name="$2" candidate="$3" assessment="${4:-gate}"
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] $name (expect rc=$expected) ... "
    set +e
    local out rc
    out=$(bash reviewer/oracle_m06.sh "$candidate" "$assessment" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq "$expected" ]; then
        echo "PASS"; PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc)"; echo "$out"; exit 1
    fi
}

echo "================================================================"
echo "=== P3-M06 Oracle Regression Suite (REVIEWER-ONLY)            ==="
echo "================================================================"

run_oracle 0 "canonical defconfig accepted as a repaired Gate candidate" "$CANONICAL" gate
run_oracle 1 "opaque Gate seed rejected" "gate/fixtures/starter.conf" gate
run_oracle 1 "opaque Challenge seed rejected (challenge)" "challenge/fixtures/starter.conf" challenge
run_oracle 1 "opaque Challenge seed rejected (gate)" "challenge/fixtures/starter.conf" gate

# Half repair: only one of the three Gate defects is fixed.
"$PY" - "$CANONICAL" "gate/fixtures/starter.conf" "$WORK/half.conf" <<'PYEOF'
import sys
canon = dict(l.strip().split("=", 1) for l in open(sys.argv[1], encoding="utf-8")
             if "=" in l and not l.strip().startswith("#"))
out = []
for line in open(sys.argv[2], encoding="utf-8"):
    s = line.strip()
    if s == 'BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="6.6.30"':
        out.append(canon["BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE"] + "\n")
    else:
        out.append(line)
open(sys.argv[3], "w", encoding="utf-8").writelines(out)
PYEOF
run_oracle 1 "half-repaired Gate candidate rejected" "$WORK/half.conf" gate

# Structurally invalid fragment: not a configuration declaration at all.
printf 'BR2_arm=y\nrun this instead\n' > "$WORK/malformed.conf"
run_oracle 1 "malformed fragment rejected (not a declaration)" "$WORK/malformed.conf" gate

run_oracle 1 "absent candidate rejected" "$WORK/does-not-exist.conf" gate
run_oracle 0 "canonical defconfig accepted (challenge)" "$CANONICAL" challenge

echo "================================================================"
echo "=== ALL $PASSED / $TOTAL P3-M06 ORACLE REGRESSION CHECKS PASSED ==="
echo "================================================================"
