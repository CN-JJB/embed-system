#!/usr/bin/env bash
# Oracle regression suite for P3-M07 (REVIEWER-ONLY).
#
# Verifies that the assessment oracle itself behaves correctly: it accepts a
# genuinely repaired artifact, rejects each seeded defect family, rejects a
# plausible-but-wrong repair, and classifies an unparseable artifact as an
# ERROR rather than a semantic rejection.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M07_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M07_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

WORK="build/reviewer-m07-oracle"
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
    out=$(bash reviewer/oracle_m07.sh "$candidate" "$assessment" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq "$expected" ]; then
        echo "PASS"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc)"; echo "$out"; exit 1
    fi
}

echo "================================================================"
echo "=== P3-M07 Oracle Regression Suite (REVIEWER-ONLY)            ==="
echo "================================================================"

# --- 1. canonical repairs are accepted ----------------------------------------
# Challenge canonical: the taught Normal section word at the challenge base
# (B restored), same assumption stamp, unfamiliar base preserved.
"$PY" - "$WORK/challenge-repaired.json" <<'PYEOF'
import json, sys
obj = json.load(open("challenge/fixtures/starter_descriptor.json", encoding="utf-8"))
obj["entries"][0]["word"] = "0x4011140E"
json.dump(obj, open(sys.argv[1], "w", encoding="utf-8"), indent=2, sort_keys=True)
PYEOF
run_oracle 0 "repaired Challenge candidate accepted" "$WORK/challenge-repaired.json" challenge

# Gate canonical: every aspect repaired, VAs/encodings kept unfamiliar.
"$PY" - <<'PYEOF'
import json
gate = json.load(open("gate/fixtures/starter_combined.json", encoding="utf-8"))
# 1. DRAM section: B restored -> n=111 Normal (keep unfamiliar base 0x402).
gate["descriptors"][0]["word"] = "0x4021140E"
gate["descriptors"][0]["claimed"] = "Normal"
# 2. MMIO page: AP restored 100->001 (keep unfamiliar base 0x0A000).
gate["descriptors"][1]["word"] = "0x0A000453"
gate["descriptors"][1]["claimed"] = "Device"
# 3. Maps: user-only VAs, both inside user regions.
gate["maps"]["candidate_vas"] = [
    {"addr": "0x00400100", "claimed": "user"},
    {"addr": "0xbefdf100", "claimed": "user"},
]
# 4. SVC: executed svc in .text with EABI r7 setup.
gate["svc"]["elf_machine"] = "ARM"
gate["svc"]["disasm_text"] = (
    "Disassembly of section .text:\n"
    "\n00000000 <svc_getpid_raw>:\n"
    "   0:\te3a07014 \tmov\tr7, #20\n"
    "   4:\tef000000 \tsvc\t0x00000000\n"
    "   8:\te12fff1e \tbx\tlr\n"
)
# 5. Binding: frozen effective assignments + correct labels.
gate["arch_binding"]["effective_config_text"] = (
    "CONFIG_ARM_LPAE=n\n"
    "CONFIG_VMSPLIT_3G=y\n"
    "CONFIG_PAGE_OFFSET=0xC0000000\n"
    "CONFIG_TASK_SIZE=0xBF000000\n"
)
gate["arch_binding"]["vas"] = [
    {"addr": "0x00400100", "class": "user"},
    {"addr": "0xC0100000", "class": "kernel"},
]
json.dump(gate, open("build/reviewer-m07-oracle/gate-repaired.json", "w", encoding="utf-8"),
          indent=2, sort_keys=True)
PYEOF
run_oracle 0 "fully repaired Gate candidate accepted" "$WORK/gate-repaired.json" gate

# --- 2. opaque seeds are rejected ----------------------------------------------
run_oracle 1 "opaque Gate seed rejected" "gate/fixtures/starter_combined.json" gate
run_oracle 1 "opaque Challenge seed rejected (challenge)" "challenge/fixtures/starter_descriptor.json" challenge
run_oracle 1 "opaque Challenge seed rejected (gate)" "challenge/fixtures/starter_descriptor.json" gate

# --- 3. half-repairs are rejected -----------------------------------------------
# F13/F14 half-repair: descriptors fixed, but maps/svc/binding left defective.
"$PY" - <<'PYEOF'
import json
gate = json.load(open("build/reviewer-m07-oracle/gate-repaired.json", encoding="utf-8"))
seed = json.load(open("gate/fixtures/starter_combined.json", encoding="utf-8"))
# Revert maps/svc/binding to the seeded defective aspects; keep descriptors fixed.
gate["maps"] = seed["maps"]
gate["svc"] = seed["svc"]
gate["arch_binding"] = seed["arch_binding"]
json.dump(gate, open("build/reviewer-m07-oracle/half-maps-svc-bind.json", "w", encoding="utf-8"),
          indent=2, sort_keys=True)
PYEOF
run_oracle 1 "half-repaired Gate (descriptors only) rejected" "$WORK/half-maps-svc-bind.json" gate

# F14 half-repair: one descriptor fixed, the other left defective.
"$PY" - <<'PYEOF'
import json
gate = json.load(open("build/reviewer-m07-oracle/gate-repaired.json", encoding="utf-8"))
gate["descriptors"][1]["word"] = "0x0A000643"
json.dump(gate, open("build/reviewer-m07-oracle/half-one-desc.json", "w", encoding="utf-8"),
          indent=2, sort_keys=True)
PYEOF
run_oracle 1 "half-repaired Gate (one descriptor) rejected" "$WORK/half-one-desc.json" gate

# Wrong-node repair: fix the wrong field (change base, keep n=110).
"$PY" - <<'PYEOF'
import json
obj = json.load(open("challenge/fixtures/starter_descriptor.json", encoding="utf-8"))
obj["entries"][0]["word"] = "0x4021140A"
json.dump(obj, open("build/reviewer-m07-oracle/wrong-node.json", "w", encoding="utf-8"),
          indent=2, sort_keys=True)
PYEOF
run_oracle 1 "Challenge candidate repaired on the wrong field rejected" "$WORK/wrong-node.json" challenge

# Staged-only fix: a correct word staged elsewhere does not fix the candidate.
cp "$WORK/gate-repaired.json" "$WORK/staged-correct.json"
run_oracle 1 "staged-only fix does not rescue the defective candidate" \
    "gate/fixtures/starter_combined.json" gate

# --- 4. ERROR taxonomy ------------------------------------------------------------
printf '{"descriptors": [{"level": 1, "word": "0x402114' > "$WORK/truncated.json"
run_oracle 2 "truncated candidate classified as ERROR" "$WORK/truncated.json" gate

printf 'not json\n' > "$WORK/badmagic.json"
run_oracle 2 "bad-magic candidate classified as ERROR" "$WORK/badmagic.json" gate

run_oracle 1 "absent candidate rejected" "$WORK/does-not-exist.json" gate

echo "================================================================"
echo "=== ALL $PASSED / $TOTAL P3-M07 ORACLE REGRESSION CHECKS PASSED ==="
echo "================================================================"
