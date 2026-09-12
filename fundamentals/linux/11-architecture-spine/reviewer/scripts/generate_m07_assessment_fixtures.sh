#!/usr/bin/env bash
# P3-M07 REVIEWER-ONLY assessment fixture generator.
#
# Materialises the opaque fixtures for the Challenge and the Module Gate from
# deterministic words/VAs, plus the hidden seed mapping the oracle grades
# against. Byte-stable (sorted JSON keys, fixed formatting); writes ONLY the
# four paths below and asserts no git churn elsewhere (checked by the caller).
#
# Seed design:
#   Challenge -- single TEX/C/B-field defect INSIDE the taught profile
#                (L1 n=110 reserved at an unfamiliar DRAM-adjacent base).
#                Same family as the F14 device-attribute tutorial, different
#                instance/values (not the taught goldens, not F13 0xC0008000).
#                The taught decoder REJECTs it, so learner tooling confirms.
#   Gate      -- combined unfamiliar variant OUTSIDE the taught profile:
#                descriptor type mismatch + AP-reserved page + maps
#                misclassification + svc decoy + comment-not-config binding,
#                all at VAs/encodings unfamiliar from F13/goldens.
#                The taught profile passes this by design; only the complete
#                contract exposes it.
#
# Usage: generate_m07_assessment_fixtures.sh [challenge-dir] [gate-dir]
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M07_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
cd "$M07_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

CHALLENGE_DIR="${1:-challenge/fixtures}"
GATE_DIR="${2:-gate/fixtures}"
mkdir -p "$CHALLENGE_DIR" "$GATE_DIR" reviewer/reference

echo "=== Materialising P3-M07 assessment fixtures (REVIEWER-ONLY) ==="

"$PY" - <<'PYEOF'
import json

stamp = "TRE=1 PRRR=0xff0a81a8 NMRR=0x40e040e0 AFE=0 DACR=Client"

# --- LEARNER-FACING STARTERS -------------------------------------------------
#
# ANSWER-LEAKAGE CONTRACT (enforced by reviewer/audit_learner_isolation.sh
# Rule 6): a learner-facing starter may carry ONLY the artifact under test and
# neutral structural metadata.  It must not name the defect family, the
# corrupted field, the aspect class, the correct value, the tutorial family, or
# the taught goldens -- not even in a `_comment` or a `note`.  Everything
# answer-bearing lives in reviewer/reference/*_seed.json instead.
challenge = {
    "assumption_stamp": stamp,
    "_comment": "P3-M07 Challenge starter. Well-formed short-descriptor fixture. "
                "Decode it using the ARMv7-A short-descriptor rules and the material "
                "from Labs 7.1-7.4, repair it, then run: make check.",
    "entries": [
        {
            "id": "challenge-L1-section",
            "level": 1,
            "word": "0x4011140A",
        }
    ],
}

with open("challenge/fixtures/starter_descriptor.json", "w", encoding="utf-8") as handle:
    json.dump(challenge, handle, indent=2, sort_keys=True)
    handle.write("\n")

gate = {
    "assumption_stamp": stamp,
    "_comment": "P3-M07 Module Gate starter. Well-formed combined fixture: short "
                "descriptors, a process-map listing, an SVC disassembly listing and an "
                "effective-configuration binding. Author the canonical candidate, then "
                "run: make check.",
    "descriptors": [
        {
            "id": "gate-L1-dram",
            "level": 1,
            "word": "0x40211402",
            "claimed": "Normal",
        },
        {
            "id": "gate-L2-mmio",
            "level": 2,
            "word": "0x0A000643",
            "claimed": "Device",
        },
    ],
    "maps": {
        "maps_lines": [
            "00400000-0040b000 r-xp 00000000 b3:02 12345      /home/root/addrspace.elf",
            "0041b000-0041c000 r--p 0000a000 b3:02 12345      /home/root/addrspace.elf",
            "0041c000-0041d000 rw-p 0000b000 b3:02 12345      /home/root/addrspace.elf",
            "0041d000-0043e000 rw-p 00000000 00:00 0          [heap]",
            "b6ec7000-b6fcf000 r-xp 00000000 b3:02 23456      /lib/libc.so.6",
            "befdf000-bf000000 rw-p 00000000 00:00 0          [stack]",
        ],
        "candidate_vas": [
            {"addr": "0x00400100", "claimed": "user"},
            {"addr": "0xC0100000", "claimed": "user"},
        ],
    },
    "svc": {
        "elf_machine": "ARM",
        "disasm_text": "Disassembly of section .text:\n"
                       "\n"
                       "00000000 <getpid_wrapper>:\n"
                       "   0:\te3a07014 \tmov\tr7, #20\n"
                       "   4:\te12fff1e \tbx\tlr\n",
    },
    "arch_binding": {
        "effective_config_text": "# appliance bring-up notes\n"
                                 "# split: 3G user / 1G kernel, page offset 0xC0000000\n"
                                 "# LPAE not used on this target\n",
        "vas": [
            {"addr": "0x00400100", "class": "user"},
            {"addr": "0xC0100000", "class": "user"},
        ],
    },
}

with open("gate/fixtures/starter_combined.json", "w", encoding="utf-8") as handle:
    json.dump(gate, handle, indent=2, sort_keys=True)
    handle.write("\n")

challenge_seed = {
    "assessment": "challenge",
    "fault_family": "F14-family memory-attribute single-field defect (TEX/C/B)",
    "variant": "L1 DRAM-adjacent section at an unfamiliar base with one B-field defect (n=110 IMPLEMENTATION-DEFINED); same family as the device-attribute tutorial, different instance and values (not the taught DRAM golden 0x4001140E, not the PL011 window 0x09000453, not F13 0xC0008000)",
    "seeded_edits": [
        {"op": "clear-bit", "field": "B", "from": 1, "to": 0,
         "base": "0x40100000 vs taught 0x40000000",
         "word": "0x4011140A",
         "note": "single-field B defect turns taught-like n=111 Normal into n=110 reserved; well-formed section, semantically REJECT"}
    ],
    "expected_repair": "restore the B field so the section decodes to Normal with valid permissions",
    "taught_profile_detects": True,
    "oracle_invariants": ["desc.ap.valid", "desc.memtype.normal"],
    "note": "Inside the taught profile by design: the taught decoder REJECTs n=110. The learner-facing tooling can confirm the repair without revealing it.",
}
with open("reviewer/reference/challenge_seed.json", "w", encoding="utf-8") as handle:
    json.dump(challenge_seed, handle, indent=2, sort_keys=True)
    handle.write("\n")

gate_seed = {
    "assessment": "gate",
    "fault_family": "combined unfamiliar variant: descriptor memory-type + descriptor permission + maps classification + svc executed-path + split binding",
    "variant": "all defects outside the taught goldens with unfamiliar VAs/encodings (L1 0x40200000 Device-claimed-Normal, L2 0x0A000000 AP-reserved, maps kernel VA 0xC0100000 misclassified as user, svc decoy in comment only, split comment-only vs effective mismatch); none replays F13 0xC0008000, taught 0x4001140E or PL011 0x09000453",
    "seeded_edits": [
        {"op": "misclassify", "id": "gate-L1-dram", "word": "0x40211402",
         "note": "DRAM-adjacent section encodes n=100 Device but claims Normal; valid encoding, wrong type"},
        {"op": "reserved-ap", "id": "gate-L2-mmio", "word": "0x0A000643",
         "note": "MMIO-adjacent small page uses AP=100 Reserved; well-formed, semantically REJECT"},
        {"op": "misclassify-va", "addr": "0xC0100000", "claimed": "user",
         "note": "kernel-range VA unfamiliar from F13, placed outside every user maps region and mislabelled"},
        {"op": "decoy-svc", "note": "svc #0 appears only in comment/prose, no objdump svc mnemonic line in .text"},
        {"op": "comment-not-config",
         "note": "split claim lives only in comments; effective config carries no frozen assignments"},
    ],
    "expected_repair": "restore Normal/Device types with valid AP, user-only maps classification, an executed svc mnemonic in .text, and frozen effective assignments with correct user/kernel labels",
    "taught_profile_detects": False,
    "oracle_invariants": ["desc.memtype.normal", "desc.ap.valid", "maps.region.match", "svc.executed.text", "bind.split.effective", "bind.va.kernel"],
    "note": "The taught profile passes the combined aspect by design (each defect is valid-looking outside taught coverage). Only the complete contract exposes it.",
}
with open("reviewer/reference/gate_seed.json", "w", encoding="utf-8") as handle:
    json.dump(gate_seed, handle, indent=2, sort_keys=True)
    handle.write("\n")
PYEOF

# The complete contract is author-owned and stable; do not rewrite it here.
[ -f "reviewer/reference/qemu-virt-a7-arch-complete.json" ] \
    || { echo "FATAL: complete contract missing" >&2; exit 1; }

echo "[OK] challenge fixture : $CHALLENGE_DIR/starter_descriptor.json"
echo "[OK] gate fixture      : $GATE_DIR/starter_combined.json"
echo "[OK] hidden seed maps  : reviewer/reference/{challenge_seed,gate_seed}.json"
echo "=== Assessment fixtures materialised ==="
