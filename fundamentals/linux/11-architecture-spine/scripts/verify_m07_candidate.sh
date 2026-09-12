#!/usr/bin/env bash
# Learner-safe self-check for a P3-M07 candidate.
#
# Checks *packaging, format and evidence binding* only:
#   * the candidate exists and is well-formed JSON;
#   * every descriptor word is a parseable 32-bit short descriptor
#     (structural decode without ERROR);
#   * an identity hash is recorded next to the candidate;
#   * when maps/svc/binding sections or sidecar files are supplied, their
#     *format* is validated (not their semantic correctness).
#
# It deliberately does NOT grade the semantic contract (which AP/n/memtype is
# correct, which VA is user/kernel, whether the svc is the right one), because
# doing so would hand the learner the scored diagnosis. Semantic conformance
# is graded by the reviewer oracle.
#
# Usage:
#   scripts/verify_m07_candidate.sh CANDIDATE.json [MAPS_FILE] [DISASM_FILE] [CONFIG_FILE]
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M07_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M07_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

CANDIDATE="${1:?usage: verify_m07_candidate.sh CANDIDATE.json [MAPS_FILE] [DISASM_FILE] [CONFIG_FILE]}"
MAPS_FILE="${2:-}"
DISASM_FILE="${3:-}"
CONFIG_FILE="${4:-}"

[ -f "$CANDIDATE" ] || { echo "REJECT: candidate file not found: $CANDIDATE" >&2; exit 1; }

echo "================================================================"
echo "=== P3-M07 candidate self-check (learner-safe)                ==="
echo "=== candidate: $CANDIDATE"
echo "================================================================"

# --- 1. well-formed JSON ------------------------------------------------------
"$PY" - "$CANDIDATE" <<'PYEOF'
import json, sys
path = sys.argv[1]
try:
    obj = json.load(open(path, "r", encoding="utf-8"))
except ValueError as exc:
    print(f"REJECT: candidate is not well-formed JSON: {exc}", file=sys.stderr)
    sys.exit(1)
if not isinstance(obj, dict):
    print("REJECT: candidate top level must be a JSON object", file=sys.stderr)
    sys.exit(1)
# Accept any of: single descriptor, taught-style entries, assessment descriptors,
# or a combined gate object carrying maps/svc/binding sections.
ok = any(k in obj for k in ("word", "raw", "entries", "descriptors",
                            "maps", "svc", "arch_binding", "vas", "assumption_stamp"))
if not ok:
    print("REJECT: candidate carries no descriptor or combined sections", file=sys.stderr)
    sys.exit(1)
print("[PASS] candidate is well-formed JSON with descriptor/combined sections")
PYEOF

# --- 2. structural descriptor decode (format only, never the answer) -----------
"$PY" - "$CANDIDATE" <<'PYEOF'
import json, subprocess, sys
path = sys.argv[1]
obj = json.load(open(path, "r", encoding="utf-8"))
seq = []
if isinstance(obj.get("descriptors"), list):
    seq = obj["descriptors"]
elif isinstance(obj.get("entries"), list):
    seq = obj["entries"]
elif "word" in obj or "raw" in obj:
    seq = [obj]
for index, entry in enumerate(seq):
    if not isinstance(entry, dict):
        print(f"REJECT: descriptor entry {index} is not an object", file=sys.stderr)
        sys.exit(1)
    word = entry.get("word", entry.get("raw"))
    level = entry.get("level", entry.get("Level", 1))
    if word is None:
        print(f"REJECT: descriptor entry {index} has no word/raw", file=sys.stderr)
        sys.exit(1)
    try:
        level_n = 1 if str(level).strip().upper() in ("1", "L1") else 2 if str(level).strip().upper() in ("2", "L2") else None
    except Exception:
        level_n = None
    if level_n is None:
        print(f"REJECT: descriptor entry {index} has bad level {level!r}", file=sys.stderr)
        sys.exit(1)
    proc = subprocess.run(
        [sys.executable, "scripts/decode_short_desc.py",
         "--level", str(level_n), "--word", str(word), "--quiet"],
        capture_output=True, text=True)
    if proc.returncode == 2:
        print(f"REJECT: descriptor entry {index} is structurally malformed: {proc.stderr.strip()}",
              file=sys.stderr)
        sys.exit(1)
    # rc 0 (valid) and rc 1 (well-formed but semantically non-canonical) are
    # BOTH structurally fine here; the oracle grades the difference.
print(f"[PASS] {len(seq)} descriptor word(s) structurally parseable (format only)")
PYEOF

if command -v sha256sum >/dev/null 2>&1; then
    echo "[INFO] candidate sha256: $(sha256sum "$CANDIDATE" | awk '{print $1}')"
fi

echo "[NOTE] Format/structure verified.  Semantic conformance against the"
echo "       canonical arch contract is graded by the reviewer oracle."

# --- 3. optional sidecar format checks (binding, not grading) ------------------
if [ -n "$MAPS_FILE" ]; then
    [ -f "$MAPS_FILE" ] || { echo "REJECT: maps file not found: $MAPS_FILE" >&2; exit 1; }
    "$PY" scripts/parse_proc_maps.py "$MAPS_FILE" --addrs 0x00400000 --quiet \
        >/dev/null 2>&1 \
        || "$PY" scripts/parse_proc_maps.py "$MAPS_FILE" --addrs 0x00400000 >/dev/null
    echo "[PASS] maps sidecar is parseable"
fi

if [ -n "$DISASM_FILE" ]; then
    [ -f "$DISASM_FILE" ] || { echo "REJECT: disasm file not found: $DISASM_FILE" >&2; exit 1; }
    # Format probe only: require at least one objdump section/symbol shape, not a verdict.
    if grep -Eq 'Disassembly of section|<[^>]+>:' "$DISASM_FILE"; then
        echo "[PASS] disasm sidecar carries objdump structure"
    else
        echo "[NOTE] disasm sidecar has no objdump section headers (format only)"
    fi
fi

if [ -n "$CONFIG_FILE" ]; then
    [ -f "$CONFIG_FILE" ] || { echo "REJECT: config file not found: $CONFIG_FILE" >&2; exit 1; }
    if grep -Eq '^CONFIG_|is not set' "$CONFIG_FILE"; then
        echo "[PASS] config sidecar carries Kconfig assignments"
    else
        echo "REJECT: config sidecar has no Kconfig lines" >&2
        exit 1
    fi
fi

echo "=== P3-M07 CANDIDATE SELF-CHECK COMPLETE ==="
