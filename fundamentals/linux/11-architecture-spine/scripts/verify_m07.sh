#!/usr/bin/env bash
# Learner-safe master verification for P3-M07.
#
# Checks documentation completeness, the integrity of the committed taught
# fixtures, the self-consistency of the taught descriptor profile, and that
# the assessment workspaces are provisioned as *well-formed but deliberately
# non-canonical* artifacts.  It never reports which semantic invariant a
# provisioned assessment artifact violates -- that is reviewer-only grading.
#
# Isolation: this script reads ONLY fixtures/descriptor_taught.json (taught).
# It never reads any assessment-private reference mapping.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M07_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M07_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

echo "================================================================"
echo "=== Running P3-M07 Learner-Safe Verification                  ==="
echo "================================================================"

# --- Files owned by the content agent (taught) plus our appliance files ------
# 07.4 / faults are content-owned; when absent we NOTE (not fail) so this
# appliance agent never blocks content authoring.
REQUIRED_FILES=(
    "README.md"
    "challenge/README.md"
    "gate/README.md"
    "challenge/fixtures/starter_descriptor.json"
    "gate/fixtures/starter_combined.json"
    "fixtures/descriptor_taught.json"
    "fixtures/maps_sample.txt"
    "fixtures/svc_reference.disasm"
    "scripts/decode_short_desc.py"
    "scripts/check_svc_artifact.py"
    "scripts/parse_proc_maps.py"
    "scripts/verify_arch_binding.py"
    "scripts/verify_m07_candidate.sh"
)

echo "=== Step 1: Auditing module documentation and tooling ==="
for file in "${REQUIRED_FILES[@]}"; do
    [ -f "$file" ] || { echo "REJECT: missing required file: $file" >&2; exit 1; }
    echo "[PASS] found: $file"
done

# Content-owned teaching material: presence is expected, absence is a NOTE.
for file in "labs/07.1-proc-address-space/src/addrspace.c" \
             "labs/07.2-svc-syscall-trace/src/svc_getpid.S" \
             "labs/07.3-kernel-boundary-fault/src/kfault.c" \
             "labs/07.4-short-descriptor-decode/README.md" \
             "faults/F13-kernel-address-deref/README.md" \
             "faults/F14-device-memory-attribute/README.md"; do
    if [ -f "$file" ]; then
        echo "[PASS] found (content-owned): $file"
    else
        echo "[NOTE] content-owned teaching file not yet present: $file (owned by content agent)"
    fi
done

echo "=== Step 2: Taught goldens decode PASS via decode_short_desc.py ==="
"$PY" scripts/decode_short_desc.py --level 1 --word 0x4001140E --expect Normal --quiet
echo "[PASS] golden L1 0x4001140E decodes Normal"
"$PY" scripts/decode_short_desc.py --level 2 --word 0x09000453 --expect Device --quiet
echo "[PASS] golden L2 0x09000453 decodes Device"
# UP policy: S=0 TEX=000 is still Normal (never hard-require S=1).
"$PY" scripts/decode_short_desc.py --level 1 --word 0x4000040E --expect Normal --quiet
echo "[PASS] UP variant L1 0x4000040E (S=0 TEX=000) still Normal"

echo "=== Step 3: Taught profile self-consistency (fixtures only) ==="
"$PY" - <<'PYEOF'
import json, subprocess, sys
taught = json.load(open("fixtures/descriptor_taught.json", encoding="utf-8"))
stamps = taught.get("assumptions", {})
# The taught fixture must carry the frozen assumption set.
for key, want in (("TRE", 1), ("AFE", 0),
                  ("PRRR", "0xff0a81a8"), ("NMRR", "0x40e040e0")):
    got = stamps.get(key)
    if str(got).lower() != str(want).lower():
        print(f"REJECT: taught assumptions {key}={got!r} != {want!r}", file=sys.stderr)
        sys.exit(1)
print("[PASS] taught assumptions carry TRE=1 AFE=0 PRRR/NMRR frozen values")
entries = taught.get("entries", [])
accepts = [e for e in entries if str(e.get("expected_verdict", "")).upper() == "ACCEPT"]
if len(accepts) < 2:
    print("REJECT: taught fixture must contain at least two ACCEPT goldens", file=sys.stderr)
    sys.exit(1)
print(f"[PASS] taught fixture holds {len(accepts)} ACCEPT goldens")
PYEOF
# The taught reserved entry must REJECT (never ACCEPT as section).
set +e
"$PY" scripts/decode_short_desc.py --level 1 --word 0x4001140F --quiet >/dev/null 2>&1
RESERVED_RC=$?
set -e
if [ "$RESERVED_RC" -eq 1 ]; then
    echo "[PASS] taught reserved L1 0b11 entry REJECTs (never a section)"
else
    echo "REJECT: taught reserved L1 0b11 entry did not REJECT (rc=$RESERVED_RC)" >&2
    exit 1
fi

echo "=== Step 4: Assessment workspaces are provisioned and well formed ==="
for dir in challenge gate; do
    if [ "$dir" = "challenge" ]; then fixture="$dir/fixtures/starter_descriptor.json";
    else fixture="$dir/fixtures/starter_combined.json"; fi
    [ -f "$fixture" ] || { echo "REJECT: $dir fixture missing: $fixture" >&2; exit 1; }
    # Well-formed JSON (ERROR-class problems would fail here).
    "$PY" - "$fixture" <<'PYEOF'
import json, sys
obj = json.load(open(sys.argv[1], encoding="utf-8"))
if not isinstance(obj, dict):
    print("REJECT: starter top level must be an object", file=sys.stderr)
    sys.exit(1)
print("[PASS] starter is well-formed JSON")
PYEOF
    echo "[PASS] $dir starter is well-formed"
done

echo "=== Step 5: Starters are non-canonical (taught-vs-starter difference) ==="
# Opaque difference check: the starter words must differ from every taught
# ACCEPT golden, proving non-canonicity without naming the defect.
"$PY" - <<'PYEOF'
import json, sys
taught = json.load(open("fixtures/descriptor_taught.json", encoding="utf-8"))
goldens = set()
for entry in taught.get("entries", []):
    if str(entry.get("expected_verdict", "")).upper() == "ACCEPT":
        raw = str(entry.get("raw", "")).lower()
        goldens.add(raw)

def words_of(path):
    obj = json.load(open(path, encoding="utf-8"))
    words = set()
    seq = []
    if isinstance(obj, dict):
        if isinstance(obj.get("descriptors"), list):
            seq = obj["descriptors"]
        elif isinstance(obj.get("entries"), list):
            seq = obj["entries"]
        elif "word" in obj or "raw" in obj:
            seq = [obj]
    for entry in seq:
        if isinstance(entry, dict):
            for key in ("word", "raw"):
                if entry.get(key) is not None:
                    words.add(str(entry[key]).lower())
    # Combined gate fixture also carries maps/svc/binding sections; the
    # descriptor words alone already prove non-canonicity.
    return words

for path in ("challenge/fixtures/starter_descriptor.json",
             "gate/fixtures/starter_combined.json"):
    words = words_of(path)
    if not words:
        print(f"REJECT: {path} carries no descriptor words", file=sys.stderr)
        sys.exit(1)
    if words & goldens:
        print(f"REJECT: {path} replays a taught golden word (must be an unfamiliar variant)",
              file=sys.stderr)
        sys.exit(1)
    print(f"[PASS] {path} is well-formed-but-noncanonical (unfamiliar variant)")
PYEOF
echo "[NOTE] Which invariant each provisioned artifact violates is reviewer-only information."

echo "=== Step 6: Learner-safe candidate self-check accepts well-formed input ==="
# The candidate self-check is format/structure/binding only: even the opaque
# (defective) starter must pass it as well-formed. Semantic grading belongs to
# the reviewer oracle.
bash scripts/verify_m07_candidate.sh challenge/fixtures/starter_descriptor.json >/dev/null
echo "[PASS] candidate self-check treats the opaque starter as well-formed"

echo "================================================================"
echo "=== ALL P3-M07 LEARNER-SAFE CHECKS PASSED                     ==="
echo "================================================================"
