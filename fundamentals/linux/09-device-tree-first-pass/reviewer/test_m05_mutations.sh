#!/usr/bin/env bash
# Adversarial mutation suite for the P3-M05 validators (REVIEWER-ONLY).
#
# Every mutation must produce the *intended* outcome class:
#
#   PREP/BUILD PASS  /  VALIDATOR EXECUTION PASS  /  INTENDED SEMANTIC REJECT PASS
#
# A crash, a parser error or an unrelated environment failure does NOT count as
# an intended semantic rejection.  Mutations that make the artifact unreadable
# must be classified as ERROR (exit 2), and that is asserted separately.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M05_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M05_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

COMPLETE_PROFILE="reviewer/reference/qemu-virt-a7-complete.json"
TAUGHT_PROFILE="fixtures/profiles/qemu-virt-a7-canonical.json"
CANONICAL="fixtures/qemu-virt.dtb"

echo "================================================================"
echo "=== P3-M05 Adversarial Mutation Suite (REVIEWER-ONLY)         ==="
echo "================================================================"

WORK="build/reviewer-m05-mutations"
rm -rf "$WORK" 2>/dev/null || true
mkdir -p "$WORK"

MUTATIONS=0
PASSED=0

patch() { "$PY" scripts/fdt_patch.py "$@" >/dev/null; }

# --- assertion helpers -------------------------------------------------------

assert_semantic_reject() {
    local name="$1" dtb="$2" profile="${3:-$COMPLETE_PROFILE}"
    MUTATIONS=$((MUTATIONS + 1))
    echo -n "[TEST $MUTATIONS] semantic REJECT expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/validate_dt_semantics.py "$dtb" --profile "$profile" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 1 ] && grep -q "REJECT" <<<"$out"; then
        echo "PASS (intended semantic REJECT)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 1)"
        echo "$out"
        exit 1
    fi
}

assert_pass() {
    local name="$1" dtb="$2" profile="${3:-$COMPLETE_PROFILE}"
    MUTATIONS=$((MUTATIONS + 1))
    echo -n "[TEST $MUTATIONS] PASS expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/validate_dt_semantics.py "$dtb" --profile "$profile" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then
        echo "PASS"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 0)"
        echo "$out"
        exit 1
    fi
}

assert_error() {
    local name="$1" dtb="$2" tool="$3"
    MUTATIONS=$((MUTATIONS + 1))
    echo -n "[TEST $MUTATIONS] ERROR (not REJECT) expected: $name ... "
    set +e
    local out rc
    out=$("$PY" "$tool" "$dtb" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 2 ] && grep -qE "ERROR" <<<"$out"; then
        echo "PASS (classified as tool/format ERROR)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 2)"
        echo "$out"
        exit 1
    fi
}

assert_structural_reject() {
    local name="$1" dtb="$2"
    MUTATIONS=$((MUTATIONS + 1))
    echo -n "[TEST $MUTATIONS] structural REJECT expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/dt_structural_check.py "$dtb" --quiet 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 1 ]; then
        echo "PASS (intended structural REJECT)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 1)"
        echo "$out"
        exit 1
    fi
}

assert_binding_reject() {
    local name="$1" dtb="$2" prov="$3" log="$4"
    MUTATIONS=$((MUTATIONS + 1))
    echo -n "[TEST $MUTATIONS] runtime-binding REJECT expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/verify_runtime_binding.py "$dtb" "$prov" "$log" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 1 ] && grep -q "REJECT" <<<"$out"; then
        echo "PASS (intended binding REJECT)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 1)"
        echo "$out"
        exit 1
    fi
}

# --- 1. decoy: the expected string exists, but only on the wrong node --------
# "arm,pl011" is removed from the console node and planted on an unrelated node.
patch --in "$CANONICAL" --out "$WORK/decoy.dtb" \
      --set-string "/pl011@9000000" compatible "arm,uart-x" \
      --set-string "/pmu" compatible "arm,pl011"
assert_semantic_reject "expected string present only as a decoy on another node" "$WORK/decoy.dtb"

# --- 2. a property carries the expected value but on the wrong node ----------
patch --in "$CANONICAL" --out "$WORK/wrong-node.dtb" \
      --set-string "/pl031@9010000" status disabled
assert_semantic_reject "wrong node modified (availability on a non-contracted node)" "$WORK/wrong-node.dtb"

# --- 3. wrong reg cell count under the parent's addressing rules -------------
patch --in "$CANONICAL" --out "$WORK/bad-cells.dtb" \
      --set-cells "/pl031@9010000" reg 0x00 0x09010000 0x00
assert_semantic_reject "reg cell count contradicts parent #address-cells/#size-cells" "$WORK/bad-cells.dtb"
assert_structural_reject "same defect is also a structural violation" "$WORK/bad-cells.dtb"

# --- 3b. S2-1: non-inheritance of #address-cells/#size-cells from grandparent ---
# Grandparent (root) defines #address-cells = <1>, #size-cells = <1>.
# Intermediate parent /testbus omits #address-cells and #size-cells.
# Per Devicetree Spec v0.4 Section 2.3.5, /testbus defaults to 2/1 (stride 3).
# Child /testbus/dev has reg with 2 cells (which would match inherited 1/1, but violates default 2/1).
"$PY" - "$WORK/non-inherit-reject.dtb" << 'PYEOF'
import sys, os, struct
sys.path.insert(0, "scripts")
from fdtlib_min import Fdt, Node, write_file
fdt = Fdt()
root = Node("")
root.props["#address-cells"] = struct.pack(">I", 1)
root.props["#size-cells"] = struct.pack(">I", 1)
bus = Node("testbus", parent=root)
dev = Node("device@1000", parent=bus)
dev.props["reg"] = struct.pack(">2I", 0x1000, 0x100)
root.children = [bus]
bus.children = [dev]
fdt.root = root
write_file(fdt, sys.argv[1])
PYEOF
assert_structural_reject "reg cell count violates direct parent default 2/1 despite grandparent 1/1" "$WORK/non-inherit-reject.dtb"

# --- 3c. S2-1: positive control proving 3 cells decode under direct parent default 2/1 ---
"$PY" - "$WORK/non-inherit-pass.dtb" << 'PYEOF'
import sys, os, struct
sys.path.insert(0, "scripts")
from fdtlib_min import Fdt, Node, write_file, decode_reg
fdt = Fdt()
root = Node("")
root.props["#address-cells"] = struct.pack(">I", 1)
root.props["#size-cells"] = struct.pack(">I", 1)
bus = Node("testbus", parent=root)
dev = Node("device@1000", parent=bus)
dev.props["reg"] = struct.pack(">3I", 0x00, 0x1000, 0x100)
root.children = [bus]
bus.children = [dev]
fdt.root = root
write_file(fdt, sys.argv[1])
decoded = decode_reg(dev)
assert decoded == [(0x1000, 0x100)], f"unexpected decode: {decoded}"
PYEOF
MUTATIONS=$((MUTATIONS + 1))
echo -n "[TEST $MUTATIONS] PASS expected: decode_reg proves 3 cells decode under parent default 2/1 ... "
set +e
"$PY" scripts/dt_structural_check.py "$WORK/non-inherit-pass.dtb" >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 0 ]; then
    echo "PASS"
    PASSED=$((PASSED + 1))
else
    echo "FAIL (rc=$RC)"
    exit 1
fi

# --- 4. right cell count, wrong interpreted address --------------------------
patch --in "$CANONICAL" --out "$WORK/wrong-addr.dtb" \
      --set-cells "/pl031@9010000" reg 0x00 0x09020000 0x00 0x1000
assert_semantic_reject "well-formed reg decoding to the wrong resource" "$WORK/wrong-addr.dtb"

# --- 5. both availability strings present, effective status wrong ------------
patch --in "$CANONICAL" --out "$WORK/status-decoy.dtb" \
      --set-string "/pl011@9000000" status disabled \
      --set-string "/pmu" status okay
assert_semantic_reject "decoy \"okay\" elsewhere does not make the console available" "$WORK/status-decoy.dtb"

# --- 6. explicit okay is genuinely enabled (negative control on the control) --
patch --in "$CANONICAL" --out "$WORK/status-okay.dtb" \
      --set-string "/pl011@9000000" status okay
assert_pass "explicit status = \"okay\" is enabled" "$WORK/status-okay.dtb"

# --- 7. interrupt specifier wrong under the GIC binding ----------------------
patch --in "$CANONICAL" --out "$WORK/bad-spi.dtb" \
      --set-cells "/pl011@9000000" interrupts 0x00 0x21 0x04
assert_semantic_reject "interrupt specifier names the wrong SPI" "$WORK/bad-spi.dtb"

# --- 8. window-size defect in the virtio-mmio bank ---------------------------
patch --in "$CANONICAL" --out "$WORK/window-size.dtb" \
      --set-cells "/virtio_mmio@a000200" reg 0x00 0x0a000200 0x00 0x400
assert_semantic_reject "virtio-mmio window size silently overlaps the next window" "$WORK/window-size.dtb"

# --- 9. duplicate sibling node name (semantic, detected at parse) ------------
"$PY" - "$CANONICAL" "$WORK/dup-node.dtb" <<'PYEOF'
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "scripts"))
sys.path.insert(0, "scripts")
from fdtlib_min import parse_file, write_file, Node
fdt = parse_file(sys.argv[1])
root = fdt.root
assert root is not None
victim = None
for node in root.walk():
    if node.path == "/pl011@9000000":
        victim = node
        break
assert victim is not None and victim.parent is not None
clone = Node(victim.name, victim.parent)
clone.props = dict(victim.props)
victim.parent.children.append(clone)
write_file(fdt, sys.argv[2])
PYEOF
assert_semantic_reject "duplicate sibling node name" "$WORK/dup-node.dtb"

# --- 10. invalid UTF-8 in a string property ---------------------------------
"$PY" - "$CANONICAL" "$WORK/bad-utf8.dtb" <<'PYEOF'
import sys
sys.path.insert(0, "scripts")
from fdtlib_min import parse_file, write_file
fdt = parse_file(sys.argv[1])
for node in fdt.root.walk():
    if node.path == "/pl011@9000000":
        node.props["compatible"] = b"\xff\xfe\xfd\x00"
write_file(fdt, sys.argv[2])
PYEOF
assert_semantic_reject "string property that is not valid UTF-8" "$WORK/bad-utf8.dtb"

# --- 11. malformed artifacts must be ERROR, never semantic REJECT ------------
head -c 200 "$CANONICAL" > "$WORK/truncated.dtb"
assert_error "truncated DTB (file shorter than header totalsize)" "$WORK/truncated.dtb" scripts/validate_dt_semantics.py
assert_error "truncated DTB under the structural checker" "$WORK/truncated.dtb" scripts/dt_structural_check.py

"$PY" - "$CANONICAL" "$WORK/bad-magic.dtb" <<'PYEOF'
import sys
data = bytearray(open(sys.argv[1], "rb").read())
data[0:4] = b"\xde\xad\xbe\xef"
open(sys.argv[2], "wb").write(bytes(data))
PYEOF
assert_error "bad FDT magic" "$WORK/bad-magic.dtb" scripts/validate_dt_semantics.py

printf 'not a device tree at all\n' > "$WORK/not-a-dtb.dtb"
assert_error "arbitrary text file" "$WORK/not-a-dtb.dtb" scripts/validate_dt_semantics.py

# --- 12. runtime evidence captured from a DIFFERENT tree --------------------
# A structurally complete, plausible capture that is bound to another DTB.
cat > "$WORK/prov.conf" <<EOF
machine: virt,highmem=off,gic-version=2
cpu: cortex-a7
memory: 512M
smp: 1
bootargs: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init
dtb_sha256: 0000000000000000000000000000000000000000000000000000000000000000
EOF
cat > "$WORK/boot.log" <<'EOF'
[    0.000000] Booting Linux on physical CPU 0x0
[    0.000000] Kernel command line: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init
DT-PROBE model=linux,dummy-virt
DT-PROBE-NODE /pl011@9000000
clock-names clocks compatible interrupts reg
DT-PROBE-END
EOF
assert_binding_reject "runtime capture whose recorded DTB identity does not match the candidate" \
    "$CANONICAL" "$WORK/prov.conf" "$WORK/boot.log"

# --- 13. candidate manifest declares a different machine than was executed ---
cat > "$WORK/prov-wrong-machine.conf" <<EOF
machine: virt,gic-version=2
cpu: cortex-a7
memory: 512M
smp: 1
bootargs: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init
dtb_sha256: $(sha256sum "$CANONICAL" | awk '{print $1}')
EOF
assert_binding_reject "runtime capture executed with a non-canonical machine string" \
    "$CANONICAL" "$WORK/prov-wrong-machine.conf" "$WORK/boot.log"

# --- 13b. S2-2: runner fails closed on missing input (rc=2) -----------------
MUTATIONS=$((MUTATIONS + 1))
echo -n "[TEST $MUTATIONS] runner error expected: missing input file ... "
set +e
bash scripts/run_qemu_dtb_boot.sh "$CANONICAL" "/nonexistent/zImage" "/nonexistent/initrd" "$WORK/out.log" "$WORK/out.argv" >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 2 ]; then
    echo "PASS (exited 2 as expected)"
    PASSED=$((PASSED + 1))
else
    echo "FAIL (rc=$RC, expected 2)"
    exit 1
fi

# --- 13c. S2-2: runner fails closed on missing DT-PROBE-END (rc=1) ----------
MUTATIONS=$((MUTATIONS + 1))
echo -n "[TEST $MUTATIONS] runner reject expected: missing DT-PROBE-END marker ... "
# Provide a dummy non-bootable kernel & initrd to provoke fail-closed exit
echo "dummy" > "$WORK/dummy.bin"
set +e
TIMEOUT_SEC=2 bash scripts/run_qemu_dtb_boot.sh "$CANONICAL" "$WORK/dummy.bin" "$WORK/dummy.bin" "$WORK/fail.log" "$WORK/fail.argv" >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 1 ]; then
    echo "PASS (fail-closed exit 1)"
    PASSED=$((PASSED + 1))
else
    echo "FAIL (rc=$RC, expected 1)"
    exit 1
fi

# --- 14. positive reference controls ----------------------------------------
assert_pass "canonical fixture against the complete contract" "$CANONICAL"
assert_pass "canonical fixture against the taught contract" "$CANONICAL" "$TAUGHT_PROFILE"

echo -n "[TEST $((MUTATIONS + 1))] positive control: repair of the gate seed passes ... "
patch --in "$CANONICAL" --out "$WORK/gate-repaired.dtb" \
      --set-string "/pl061@9030000" status okay >/dev/null
MUTATIONS=$((MUTATIONS + 1))
set +e
"$PY" scripts/validate_dt_semantics.py "$WORK/gate-repaired.dtb" --profile "$COMPLETE_PROFILE" --quiet >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 0 ]; then
    echo "PASS"
    PASSED=$((PASSED + 1))
else
    echo "FAIL (rc=$RC)"
    exit 1
fi

echo "================================================================"
echo "=== ALL $PASSED / $MUTATIONS P3-M05 MUTATION & REFERENCE CHECKS PASSED ==="
echo "================================================================"
