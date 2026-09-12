#!/usr/bin/env bash
# Adversarial mutation suite for the P3-M07 validators (REVIEWER-ONLY).
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
M07_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M07_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

COMPLETE_PROFILE="reviewer/reference/qemu-virt-a7-arch-complete.json"
TAUGHT_FIXTURE="fixtures/descriptor_taught.json"
MAPS_SAMPLE="fixtures/maps_sample.txt"

WORK="build/reviewer-m07-mutations"
rm -rf "$WORK" 2>/dev/null || true
mkdir -p "$WORK"

TOTAL=0
PASSED=0

assert_decode_pass() {
    local name="$1"; shift
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] PASS expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/decode_short_desc.py "$@" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then
        echo "PASS (PREP PASS / EXEC PASS / intended PASS)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 0)"; echo "$out"; exit 1
    fi
}

assert_decode_reject() {
    local name="$1"; shift
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] semantic REJECT expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/decode_short_desc.py "$@" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 1 ] && grep -q "assumption_stamp" <<<"$out"; then
        echo "PASS (PREP PASS / EXEC PASS / intended REJECT PASS)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 1)"; echo "$out"; exit 1
    fi
}

assert_decode_error() {
    local name="$1"; shift
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] ERROR expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/decode_short_desc.py "$@" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 2 ] && grep -qE "ERROR" <<<"$out"; then
        echo "PASS (PREP PASS / EXEC PASS / intended ERROR PASS)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 2)"; echo "$out"; exit 1
    fi
}

assert_svc_pass() {
    local name="$1"; shift
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] svc PASS expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/check_svc_artifact.py "$@" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then
        echo "PASS (PREP PASS / EXEC PASS / intended PASS)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 0)"; echo "$out"; exit 1
    fi
}

assert_svc_reject() {
    local name="$1"; shift
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] svc REJECT expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/check_svc_artifact.py "$@" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 1 ] && grep -q "REJECT" <<<"$out"; then
        echo "PASS (PREP PASS / EXEC PASS / intended REJECT PASS)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 1)"; echo "$out"; exit 1
    fi
}

assert_svc_error() {
    local name="$1"; shift
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] svc ERROR expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/check_svc_artifact.py "$@" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 2 ] && grep -qE "ERROR" <<<"$out"; then
        echo "PASS (PREP PASS / EXEC PASS / intended ERROR PASS)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 2)"; echo "$out"; exit 1
    fi
}

assert_maps_pass() {
    local name="$1"; shift
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] maps PASS expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/parse_proc_maps.py "$@" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then
        echo "PASS (PREP PASS / EXEC PASS / intended PASS)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 0)"; echo "$out"; exit 1
    fi
}

assert_maps_reject() {
    local name="$1"; shift
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] maps REJECT expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/parse_proc_maps.py "$@" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 1 ]; then
        echo "PASS (PREP PASS / EXEC PASS / intended REJECT PASS)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 1)"; echo "$out"; exit 1
    fi
}

assert_maps_error() {
    local name="$1"; shift
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] maps ERROR expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/parse_proc_maps.py "$@" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 2 ] && grep -qE "ERROR" <<<"$out"; then
        echo "PASS (PREP PASS / EXEC PASS / intended ERROR PASS)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 2)"; echo "$out"; exit 1
    fi
}

assert_bind_pass() {
    local name="$1"; shift
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] binding PASS expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/verify_arch_binding.py "$@" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then
        echo "PASS (PREP PASS / EXEC PASS / intended PASS)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 0)"; echo "$out"; exit 1
    fi
}

assert_bind_reject() {
    local name="$1"; shift
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] binding REJECT expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/verify_arch_binding.py "$@" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 1 ]; then
        echo "PASS (PREP PASS / EXEC PASS / intended REJECT PASS)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 1)"; echo "$out"; exit 1
    fi
}

assert_bind_error() {
    local name="$1"; shift
    TOTAL=$((TOTAL + 1))
    echo -n "[TEST $TOTAL] binding ERROR expected: $name ... "
    set +e
    local out rc
    out=$("$PY" scripts/verify_arch_binding.py "$@" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -eq 2 ] && grep -qE "ERROR" <<<"$out"; then
        echo "PASS (PREP PASS / EXEC PASS / intended ERROR PASS)"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL (rc=$rc, expected 2)"; echo "$out"; exit 1
    fi
}

echo "================================================================"
echo "=== P3-M07 Adversarial Mutation Suite (REVIEWER-ONLY)         ==="
echo "================================================================"

# --- 1. positive controls ----------------------------------------------------
assert_decode_pass "golden L1 0x4001140E decodes Normal" \
    --level 1 --word 0x4001140E --expect Normal
assert_decode_pass "golden L2 0x09000453 decodes Device" \
    --level 2 --word 0x09000453 --expect Device
assert_decode_pass "UP variant S=0 TEX=000 still Normal" \
    --level 1 --word 0x4000040E --expect Normal

# Canonical svc: minimal ARM ELF + objdump text with executed svc in .text.
"$PY" - "$WORK/arm.elf" <<'PYEOF'
import struct, sys
# Minimal 32-bit LE ARM ELF header (52 bytes): magic + e_machine=EM_ARM(40).
e_ident = b"\x7fELF" + bytes([1, 1, 1, 0]) + bytes(8)
header = e_ident + struct.pack("<HHIIIIIHHHHHH", 2, 40, 1, 0, 0, 0, 0, 52, 0, 0, 0, 0, 0)
open(sys.argv[1], "wb").write(header)
PYEOF
cat > "$WORK/svc-canonical.disasm" <<'EOF'
Disassembly of section .text:

00000000 <svc_getpid_raw>:
   0:	e3a07014 	mov	r7, #20
   4:	ef000000 	svc	0x00000000
   8:	e12fff1e 	bx	lr
EOF
assert_svc_pass "canonical ARM svc in executed .text" \
    --elf "$WORK/arm.elf" --disasm "$WORK/svc-canonical.disasm" \
    --entry-symbol svc_getpid_raw

# Canonical maps: user addresses inside well-formed regions.
#
# The probe addresses are DERIVED from the committed sample rather than
# hard-coded, so recalibrating the fixture (e.g. replacing a synthetic sample
# with a real capture, which changes every absolute address) cannot silently
# turn this positive control into a false failure -- or, worse, into a
# meaningless one.  If derivation fails the suite fails closed.
MAPS_PROBES=$("$PY" - "$MAPS_SAMPLE" <<'PYEOF'
import re
import sys

LINE = re.compile(
    r"^([0-9a-f]{8})-([0-9a-f]{8})\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*(.*)$"
)
text_probe = None
stack_probe = None
for raw in open(sys.argv[1], encoding="utf-8"):
    match = LINE.match(raw.rstrip("\n"))
    if not match:
        continue
    start, end = int(match.group(1), 16), int(match.group(2), 16)
    perms, pathname = match.group(3), match.group(7).strip()
    probe = start + (end - start) // 2
    if text_probe is None and perms.startswith("r-x") and pathname.startswith("/"):
        text_probe = probe
    if stack_probe is None and pathname == "[stack]":
        stack_probe = probe

if text_probe is None or stack_probe is None:
    sys.exit(1)
print(f"0x{text_probe:x} 0x{stack_probe:x}")
PYEOF
) || { echo "FAIL (could not derive maps probes from $MAPS_SAMPLE)"; exit 1; }
# shellcheck disable=SC2086
assert_maps_pass "canonical user VAs classify inside committed sample ($MAPS_PROBES)" \
    "$MAPS_SAMPLE" --addrs $MAPS_PROBES

# Canonical binding: frozen effective config + correct user/kernel labels.
cat > "$WORK/effective-good.config" <<'EOF'
CONFIG_ARM_LPAE=n
CONFIG_VMSPLIT_3G=y
CONFIG_PAGE_OFFSET=0xC0000000
CONFIG_TASK_SIZE=0xBF000000
EOF
cat > "$WORK/binding-good.json" <<'EOF'
{"vas": [{"addr": "0x00400100", "class": "user"}, {"addr": "0xC0100000", "class": "kernel"}]}
EOF
assert_bind_pass "canonical split binding (user vs kernel)" \
    "$WORK/binding-good.json" --config "$WORK/effective-good.config"

# --- 2. decoder wrong class / length / type ----------------------------------
assert_decode_reject "L1 0b11 reserved never ACCEPTs as section" \
    --level 1 --word 0x4001140F
assert_decode_reject "L1 0b00 fault" --level 1 --word 0x4001140C
assert_decode_reject "L2 large page outside small-page scope" \
    --level 2 --word 0x09000441
assert_decode_reject "AP Reserved 1,00 (Table B3-8)" \
    --level 1 --word 0x4001900E
assert_decode_reject "n=110 IMPLEMENTATION-DEFINED" \
    --level 1 --word 0x4011140A
assert_decode_reject "challenge starter (single B-field defect)" \
    challenge/fixtures/starter_descriptor.json

# --- 3. Normal-vs-Device misclassification ------------------------------------
TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] semantic REJECT expected: Device word claimed as Normal ... "
set +e
"$PY" scripts/decode_short_desc.py --level 2 --word 0x09000453 --expect Normal >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 1 ]; then echo "PASS (PREP PASS / EXEC PASS / intended REJECT PASS)"; PASSED=$((PASSED + 1));
else echo "FAIL (rc=$RC, expected 1)"; exit 1; fi

TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] semantic REJECT expected: Normal word claimed as Device ... "
set +e
"$PY" scripts/decode_short_desc.py --level 1 --word 0x4001140E --expect Device >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 1 ]; then echo "PASS (PREP PASS / EXEC PASS / intended REJECT PASS)"; PASSED=$((PASSED + 1));
else echo "FAIL (rc=$RC, expected 1)"; exit 1; fi

# --- 4. svc decoys -------------------------------------------------------------
cat > "$WORK/svc-decoy-comment.disasm" <<'EOF'
Disassembly of section .text:

00000000 <getpid_libc>:
   0:	e3a07014 	mov	r7, #20
   4:	e12fff1e 	bx	lr
   // svc #0 trap would be here in a raw wrapper (comment only, not executed)
EOF
assert_svc_reject "decoy svc #0 string in comment (no mnemonic line)" \
    --elf "$WORK/arm.elf" --disasm "$WORK/svc-decoy-comment.disasm"

cat > "$WORK/svc-x86.disasm" <<'EOF'
Disassembly of section .text:

00000000 <getpid>:
   0:	b8 27 00 00 00       	mov    $0x27,%eax
   5:	0f 05                	syscall
   7:	c3                   	ret
EOF
"$PY" - "$WORK/x86_64.elf" <<'PYEOF'
import struct, sys
e_ident = b"\x7fELF" + bytes([2, 1, 1, 0]) + bytes(8)
header = e_ident + struct.pack("<HHIQQQIHHHHHH", 2, 62, 1, 0, 0, 0, 0, 64, 0, 0, 0, 0, 0)
open(sys.argv[1], "wb").write(header)
PYEOF
assert_svc_reject "x86 syscall is not ARM svc" \
    --elf "$WORK/x86_64.elf" --disasm "$WORK/svc-x86.disasm"

cat > "$WORK/svc-debugonly.disasm" <<'EOF'
Disassembly of section .text:

00000000 <main>:
   0:	e12fff1e 	bx	lr

Disassembly of section .comment:

00000000 <.comment>:
   0:	ef000000 	svc	0x00000000
EOF
assert_svc_reject "svc only in non-executed section" \
    --elf "$WORK/arm.elf" --disasm "$WORK/svc-debugonly.disasm"

cat > "$WORK/svc-deadbranch.disasm" <<'EOF'
Disassembly of section .text:

00000000 <svc_getpid_raw>:
   0:	e3a07014 	mov	r7, #20
   4:	e12fff1e 	bx	lr

00000010 <never_called_debug>:
  10:	ef000000 	svc	0x00000000
  14:	e12fff1e 	bx	lr
EOF
assert_svc_reject "dead-branch svc outside --entry-symbol" \
    --elf "$WORK/arm.elf" --disasm "$WORK/svc-deadbranch.disasm" \
    --entry-symbol svc_getpid_raw

# --- 5. maps decoys / stale / cross-artifact -----------------------------------
printf '00400000-0040b000 r-xp 00000000 b3:02 12345 /home/root/addrspace.elf\n' > "$WORK/maps-tiny.txt"
printf 'the log mentions 0x00400100 in prose but carries no maps lines\n' > "$WORK/decoy-log.txt"
assert_maps_reject "decoy address in unrelated text (no range match)" \
    "$WORK/maps-tiny.txt" --addrs 0xC0100000
assert_maps_reject "stale/cross-artifact kernel VA not in user maps" \
    "$MAPS_SAMPLE" --addrs 0xC0100000
# The gate starter's own maps section must REJECT under the canonical sample:
TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] semantic REJECT expected: gate combined maps aspect ... "
set +e
"$PY" - "$WORK/gate-maps.txt" "$WORK/gate-addrs.txt" <<'PYEOF' >/dev/null 2>&1
import json, sys
obj = json.load(open("gate/fixtures/starter_combined.json", encoding="utf-8"))
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    for line in obj["maps"]["maps_lines"]:
        handle.write(line + "\n")
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    for entry in obj["maps"]["candidate_vas"]:
        handle.write(entry["addr"] + "\n")
PYEOF
PREP_RC=$?
set -e
if [ "$PREP_RC" -ne 0 ]; then echo "FAIL (prep rc=$PREP_RC)"; exit 1; fi
set +e
"$PY" scripts/parse_proc_maps.py "$WORK/gate-maps.txt" --addr-file "$WORK/gate-addrs.txt" >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 1 ]; then echo "PASS (PREP PASS / EXEC PASS / intended REJECT PASS)"; PASSED=$((PASSED + 1));
else echo "FAIL (rc=$RC, expected 1)"; exit 1; fi

# --- 6. binding comment-not-config / split mismatch -----------------------------
cat > "$WORK/config-comment-only.config" <<'EOF'
# The split is 3G/1G with PAGE_OFFSET 0xC0000000 (comment-only claim)
# CONFIG_ARM_LPAE sounds disabled; CONFIG_VMSPLIT_3G sounds enabled
EOF
assert_bind_reject "comment-not-config (no effective assignments)" \
    "$WORK/binding-good.json" --config "$WORK/config-comment-only.config"

cat > "$WORK/config-mismatch.config" <<'EOF'
CONFIG_ARM_LPAE=y
CONFIG_VMSPLIT_3G=y
CONFIG_PAGE_OFFSET=0xC0000000
CONFIG_TASK_SIZE=0xBF000000
EOF
assert_bind_reject "split-comment-vs-effective mismatch (LPAE=y vs frozen n)" \
    "$WORK/binding-good.json" --config "$WORK/config-mismatch.config"

cat > "$WORK/binding-swapped.json" <<'EOF'
{"vas": [{"addr": "0x00400100", "class": "kernel"}, {"addr": "0xC0100000", "class": "user"}]}
EOF
assert_bind_reject "user/kernel labels swapped" \
    "$WORK/binding-swapped.json" --config "$WORK/effective-good.config"

# --- 7. staged-only fix still REJECTs -------------------------------------------
# A repair staged in a side file does not fix the submitted candidate: the
# validator must test the learner artifact, not the reference/staged copy.
cp challenge/fixtures/starter_descriptor.json "$WORK/staged-fixed.json"
"$PY" - "$WORK/staged-fixed.json" <<'PYEOF'
import json, sys
path = sys.argv[1]
obj = json.load(open(path, encoding="utf-8"))
obj["entries"][0]["word"] = "0x4011140E"
json.dump(obj, open(path, "w", encoding="utf-8"), indent=2, sort_keys=True)
PYEOF
TOTAL=$((TOTAL + 1))
echo -n "[TEST $TOTAL] semantic REJECT expected: staged-only fix (candidate still defective) ... "
set +e
"$PY" scripts/decode_short_desc.py challenge/fixtures/starter_descriptor.json >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 1 ]; then echo "PASS (PREP PASS / EXEC PASS / intended REJECT PASS)"; PASSED=$((PASSED + 1));
else echo "FAIL (rc=$RC, expected 1)"; exit 1; fi

# --- 8. ERROR taxonomy ------------------------------------------------------------
printf '{"entries": [{"level": 1, "word": "0x4011140' > "$WORK/truncated.json"
assert_decode_error "truncated descriptor JSON" "$WORK/truncated.json"
printf 'not json at all\n' > "$WORK/badmagic.json"
assert_decode_error "bad-magic (non-JSON descriptor file)" "$WORK/badmagic.json"
assert_decode_error "missing descriptor file" "$WORK/does-not-exist.json"

printf 'not an elf\n' > "$WORK/notelf.bin"
assert_svc_error "bad ELF magic" --elf "$WORK/notelf.bin" --disasm "$WORK/svc-canonical.disasm"
assert_svc_error "missing disasm input" --elf "$WORK/arm.elf" --disasm "$WORK/does-not-exist.disasm"

printf 'this is not a maps line\n' > "$WORK/badmaps.txt"
assert_maps_error "malformed maps file" "$WORK/badmaps.txt" --addrs 0x00400100
assert_maps_error "missing maps file" "$WORK/does-not-exist.txt" --addrs 0x00400100

assert_bind_error "missing effective config (ERROR, not REJECT)" \
    "$WORK/binding-good.json" --config "$WORK/does-not-exist.config"
printf '{"vas": "not-a-list"}' > "$WORK/badbinding.json"
assert_bind_error "malformed binding artifact" "$WORK/badbinding.json" --config "$WORK/effective-good.config"

# --- 9. positive reference controls ----------------------------------------------
# NOTE: the taught fixture file itself contains an EXPECTED-REJECT teaching
# entry, so whole-file PASS is not asserted; the two goldens are asserted
# individually above (section 1).
assert_decode_pass "taught golden L1 via file word" --level 1 --word 0x4001140E
assert_decode_pass "taught golden L2 via file word" --level 2 --word 0x09000453

echo "================================================================"
echo "=== ALL $PASSED / $TOTAL P3-M07 MUTATION & REFERENCE CHECKS PASSED ==="
echo "================================================================"
