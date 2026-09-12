#!/usr/bin/env bash
# P3-M07 Assessment Reference Oracle (REVIEWER-ONLY)
#
# Grades a learner's repaired arch fixture against the COMPLETE canonical
# contract, plus the hidden seed mapping. The oracle is the only component
# that knows which invariant the seeded artifact violated; the learner-facing
# taught profile is a deliberately smaller subset. Never reference or copy
# this file into learner-facing material.
#
# Usage:
#   oracle_m07.sh [CANDIDATE.json] [ASSESSMENT]
#     ASSESSMENT: gate | challenge   (default: gate)
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M07_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M07_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

COMPLETE_PROFILE="reviewer/reference/qemu-virt-a7-arch-complete.json"

ASSESSMENT="gate"
CANDIDATE=""
for arg in "$@"; do
    case "$arg" in
        gate|challenge) ASSESSMENT="$arg" ;;
        *) if [ -z "$CANDIDATE" ]; then CANDIDATE="$arg"; fi ;;
    esac
done

[ -n "$CANDIDATE" ] || CANDIDATE="${ASSESSMENT}/build/candidate.json"
# Allow the challenge/gate fixture shape as an implicit candidate when no
# build output exists (oracle regression uses fixtures directly).
if [ ! -f "$CANDIDATE" ]; then
    if [ "$ASSESSMENT" = "challenge" ] && [ -f "challenge/fixtures/starter_descriptor.json" ]; then
        : # keep missing path so the absent-candidate test below fires correctly
    fi
fi
SEED_FILE="reviewer/reference/${ASSESSMENT}_seed.json"

FAILURES=0
fail() { echo "[FAIL] ASSESSMENT MISMATCH: $1" >&2; FAILURES=$((FAILURES + 1)); }

echo "=================================================================="
echo "=== P3-M07 Assessment Reference Oracle                         ==="
echo "=== Assessment: $ASSESSMENT"
echo "=== Candidate : $CANDIDATE"
echo "=================================================================="

[ -f "$CANDIDATE" ] || { fail "candidate artifact missing: $CANDIDATE"; echo "=== ASSESSMENT REFERENCE REJECT ===" >&2; exit 1; }
[ -f "$COMPLETE_PROFILE" ] || { echo "FATAL: complete profile missing" >&2; exit 2; }
[ -f "$SEED_FILE" ] || { echo "FATAL: seed mapping missing: $SEED_FILE" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- 0. Candidate must be parseable JSON; truncation is ERROR ---------------
if ! "$PY" - "$CANDIDATE" <<'PYEOF' >/dev/null 2>&1
import json, sys
json.load(open(sys.argv[1], "r", encoding="utf-8"))
PYEOF
then
    # Distinguish truncation/malformed (ERROR) from valid-JSON semantic issues.
    if ! "$PY" - "$CANDIDATE" <<'PYEOF' >/dev/null 2>&1
import json, sys
text = open(sys.argv[1], "r", encoding="utf-8").read()
json.loads(text)
PYEOF
    then
        echo "ERROR: candidate is not parseable JSON (truncated/malformed)" >&2
        echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
        exit 2
    fi
    echo "ERROR: candidate could not be evaluated" >&2
    echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
    exit 2
fi

# --- 1. Descriptor checks (all assessments) ----------------------------------
set +e
DESC_OUTPUT=$("$PY" scripts/decode_short_desc.py "$CANDIDATE" 2>&1)
DESC_RC=$?
set -e
if [ "$DESC_RC" -eq 2 ]; then
    echo "ERROR: descriptor(s) could not be evaluated" >&2
    echo "$DESC_OUTPUT" >&2
    echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
    exit 2
fi
if [ "$DESC_RC" -ne 0 ]; then
    fail "candidate descriptor(s) violate the complete arch contract"
    echo "$DESC_OUTPUT" | grep -E '^\[FAIL\]' | head -n 8 >&2 || true
else
    echo "[PASS] descriptor(s) satisfy the complete contract"
fi

# Seeded descriptor invariants specifically must hold.
SEED_INVARIANTS=$("$PY" - "$SEED_FILE" <<'PYEOF'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    for ident in json.load(handle).get("oracle_invariants", []):
        print(ident)
PYEOF
)
while IFS= read -r ident; do
    [ -n "$ident" ] || continue
    case "$ident" in
        desc.*)
            if [ "$DESC_RC" -ne 0 ]; then
                fail "seeded invariant still violated: $ident"
            else
                echo "[PASS] seeded invariant satisfied: $ident"
            fi
            ;;
    esac
done <<< "$SEED_INVARIANTS"

# --- 2-4. Combined aspects (gate, or any candidate carrying them) ------------
NEEDS_MAPS=0; NEEDS_SVC=0; NEEDS_BIND=0
while IFS= read -r ident; do
    case "$ident" in
        maps.*) NEEDS_MAPS=1 ;;
        svc.*) NEEDS_SVC=1 ;;
        bind.*) NEEDS_BIND=1 ;;
    esac
done <<< "$SEED_INVARIANTS"

HAS_MAPS=$("$PY" - "$CANDIDATE" <<'PYEOF'
import json, sys
obj = json.load(open(sys.argv[1], encoding="utf-8"))
print(1 if isinstance(obj, dict) and isinstance(obj.get("maps"), dict) else 0)
PYEOF
)
HAS_SVC=$("$PY" - "$CANDIDATE" <<'PYEOF'
import json, sys
obj = json.load(open(sys.argv[1], encoding="utf-8"))
print(1 if isinstance(obj, dict) and isinstance(obj.get("svc"), dict) else 0)
PYEOF
)
HAS_BIND=$("$PY" - "$CANDIDATE" <<'PYEOF'
import json, sys
obj = json.load(open(sys.argv[1], encoding="utf-8"))
print(1 if isinstance(obj, dict) and isinstance(obj.get("arch_binding"), dict) else 0)
PYEOF
)

# Maps aspect.
if [ "$NEEDS_MAPS" -eq 1 ]; then
    if [ "$HAS_MAPS" -eq 0 ]; then
        fail "combined candidate carries no maps section"
    else
        "$PY" - "$CANDIDATE" "$WORK/maps.txt" "$WORK/addrs.txt" "$WORK/claims.json" <<'PYEOF'
import json, sys
obj = json.load(open(sys.argv[1], encoding="utf-8"))
maps = obj["maps"]
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    for line in maps.get("maps_lines", []):
        handle.write(line + "\n")
with open(sys.argv[3], "w", encoding="utf-8") as handle:
    for entry in maps.get("candidate_vas", []):
        handle.write(str(entry.get("addr", "")) + "\n")
claims = {}
for entry in maps.get("candidate_vas", []):
    addr = str(entry.get("addr", ""))
    claimed = str(entry.get("claimed", entry.get("class", ""))).lower()
    # Maps-level claim is about user-half membership: a kernel-range VA must
    # never be claimed as user here. Normalise to a region probe instead of a
    # pathname so the generic maps validator applies.
    claims[addr] = ""
with open(sys.argv[4], "w", encoding="utf-8") as handle:
    json.dump(claims, handle)
PYEOF
        set +e
        MAPS_OUTPUT=$("$PY" scripts/parse_proc_maps.py "$WORK/maps.txt" \
            --addr-file "$WORK/addrs.txt" 2>&1)
        MAPS_RC=$?
        set -e
        if [ "$MAPS_RC" -eq 2 ]; then
            echo "ERROR: maps evidence could not be evaluated" >&2
            echo "$MAPS_OUTPUT" >&2
            echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
            exit 2
        elif [ "$MAPS_RC" -ne 0 ]; then
            fail "maps classification violates the complete contract (decoy/out-of-region address)"
            echo "$MAPS_OUTPUT" | grep -E '^\[FAIL\]' | head -n 6 >&2 || true
        else
            # A kernel-range VA inside candidate_vas is itself a misclassification,
            # even when every address happens to sit in a user region (it cannot).
            # Enforce the split here so a stale/cross-artifact kernel VA cannot pass.
            if grep -Eq '0x[Cc][0-9a-fA-F]{7}' "$WORK/addrs.txt"; then
                fail "maps candidate carries a kernel-range VA (>=0xC0000000); maps shows the user half only"
            else
                echo "[PASS] maps classification bound to well-formed regions"
            fi
        fi
        # Report seeded maps invariants.
        while IFS= read -r ident; do
            case "$ident" in
                maps.*)
                    if [ "$MAPS_RC" -ne 0 ] || grep -Eq '0x[Cc][0-9a-fA-F]{7}' "$WORK/addrs.txt"; then
                        fail "seeded invariant still violated: $ident"
                    else
                        echo "[PASS] seeded invariant satisfied: $ident"
                    fi
                    ;;
            esac
        done <<< "$SEED_INVARIANTS"
    fi
fi

# SVC aspect.
if [ "$NEEDS_SVC" -eq 1 ]; then
    if [ "$HAS_SVC" -eq 0 ]; then
        fail "combined candidate carries no svc section"
    else
        "$PY" - "$CANDIDATE" "$WORK/svc.disasm" "$WORK/svc.meta" <<'PYEOF'
import json, sys
obj = json.load(open(sys.argv[1], encoding="utf-8"))
svc = obj["svc"]
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    handle.write(svc.get("disasm_text", ""))
with open(sys.argv[3], "w", encoding="utf-8") as handle:
    handle.write(str(svc.get("elf_machine", "")))
PYEOF
        ELF_MACHINE=$(cat "$WORK/svc.meta")
        if [ "$ELF_MACHINE" != "ARM" ]; then
            fail "svc artifact is not ARM (elf_machine=$ELF_MACHINE)"
        else
            set +e
            SVC_OUTPUT=$("$PY" scripts/check_svc_artifact.py --disasm "$WORK/svc.disasm" \
                --entry-symbol svc_getpid_raw 2>&1)
            SVC_RC=$?
            set -e
            # The gate's canonical repair uses its own symbol name; retry without
            # the entry-symbol pin so a correct svc in .text still passes while a
            # decoy or dead-branch svc still fails.
            if [ "$SVC_RC" -ne 0 ]; then
                set +e
                SVC_OUTPUT2=$("$PY" scripts/check_svc_artifact.py --disasm "$WORK/svc.disasm" 2>&1)
                SVC_RC2=$?
                set -e
                if [ "$SVC_RC2" -eq 0 ]; then
                    SVC_OUTPUT="$SVC_OUTPUT2"
                    SVC_RC=0
                fi
            fi
            if [ "$SVC_RC" -eq 2 ]; then
                echo "ERROR: svc evidence could not be evaluated" >&2
                echo "$SVC_OUTPUT" >&2
                echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
                exit 2
            elif [ "$SVC_RC" -ne 0 ]; then
                fail "svc artifact has no executed `svc #0` in .text (decoy/comment/dead-branch)"
                echo "$SVC_OUTPUT" | grep -E 'REJECT' | head -n 4 >&2 || true
            else
                # EABI binding: the executed path must set r7 (scno .req r7).
                if grep -Eiq '\br7\b' "$WORK/svc.disasm"; then
                    echo "[PASS] svc executed-path proof bound (svc in .text, r7 EABI)"
                else
                    fail "svc proof lacks the EABI r7 syscall-number setup"
                fi
            fi
            while IFS= read -r ident; do
                case "$ident" in
                    svc.*)
                        if [ "${SVC_RC:-1}" -ne 0 ]; then
                            fail "seeded invariant still violated: $ident"
                        else
                            echo "[PASS] seeded invariant satisfied: $ident"
                        fi
                        ;;
                esac
            done <<< "$SEED_INVARIANTS"
        fi
    fi
fi

# Binding aspect.
if [ "$NEEDS_BIND" -eq 1 ]; then
    if [ "$HAS_BIND" -eq 0 ]; then
        fail "combined candidate carries no arch_binding section"
    else
        "$PY" - "$CANDIDATE" "$WORK/effective.config" "$WORK/binding.json" <<'PYEOF'
import json, sys
obj = json.load(open(sys.argv[1], encoding="utf-8"))
binding = obj["arch_binding"]
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    handle.write(binding.get("effective_config_text", ""))
vas = binding.get("vas", [])
with open(sys.argv[3], "w", encoding="utf-8") as handle:
    json.dump({"vas": vas}, handle)
PYEOF
        set +e
        BIND_OUTPUT=$("$PY" scripts/verify_arch_binding.py "$WORK/binding.json" \
            --config "$WORK/effective.config" 2>&1)
        BIND_RC=$?
        set -e
        if [ "$BIND_RC" -eq 2 ]; then
            echo "ERROR: binding evidence could not be evaluated" >&2
            echo "$BIND_OUTPUT" >&2
            echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
            exit 2
        elif [ "$BIND_RC" -ne 0 ]; then
            fail "split/binding reasoning violates the frozen effective config"
            echo "$BIND_OUTPUT" | grep -E '^\[FAIL\]' | head -n 6 >&2 || true
        else
            echo "[PASS] split/binding reasoning bound to the effective config"
        fi
        while IFS= read -r ident; do
            case "$ident" in
                bind.*)
                    if [ "$BIND_RC" -ne 0 ]; then
                        fail "seeded invariant still violated: $ident"
                    else
                        echo "[PASS] seeded invariant satisfied: $ident"
                    fi
                    ;;
            esac
        done <<< "$SEED_INVARIANTS"
    fi
fi

echo "------------------------------------------------------------------"
if [ "$FAILURES" -eq 0 ]; then
    echo "=== ASSESSMENT REFERENCE PASS (M07 $ASSESSMENT candidate) ==="
    exit 0
fi
echo "=== ASSESSMENT REFERENCE REJECT: $FAILURES mismatch(es) ===" >&2
exit 1
