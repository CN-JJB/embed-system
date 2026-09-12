#!/usr/bin/env bash
# Obtain the REAL QEMU-generated device tree blob for the canonical Phase 3
# `virt` machine, normalise it, and record provenance.
#
# Why normalise: QEMU's `dumpdtb` writes the whole reserved blob region, so the
# raw file is padded to the machine's DTB reserve size (1 MiB on `virt`).  The
# header's `totalsize` therefore describes the reserve, not the tree.  The
# normalised artifact re-serialises the same tree in canonical layout so that
# it is small, comparable and hashable.  The tree itself is unchanged, and the
# round trip is checked against the raw dump before the artifact is accepted.
#
# Usage:
#   scripts/dump_virt_dtb.sh [OUT_DTB] [OUT_PROVENANCE_JSON]
#
# Environment:
#   QEMU_SYSTEM_ARM   path to qemu-system-arm (default: first on PATH)
#   QEMU_MACHINE      machine string (default: virt,highmem=off,gic-version=2)
#   QEMU_CPU          cpu model      (default: cortex-a7)
#   QEMU_MEM          RAM size       (default: 512M)
#   QEMU_SMP          SMP count      (default: 1)
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M05_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M05_ROOT"

OUT_DTB="${1:-build/virt.dtb}"
OUT_JSON="${2:-build/virt.provenance.json}"

QEMU_MACHINE="${QEMU_MACHINE:-virt,highmem=off,gic-version=2}"
QEMU_CPU="${QEMU_CPU:-cortex-a7}"
QEMU_MEM="${QEMU_MEM:-512M}"
QEMU_SMP="${QEMU_SMP:-1}"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

QEMU="${QEMU_SYSTEM_ARM:-}"
if [ -z "$QEMU" ]; then
    QEMU=$(command -v qemu-system-arm || true)
fi
if [ -z "$QEMU" ] || [ ! -x "$QEMU" ]; then
    echo "ERROR: qemu-system-arm not found." >&2
    echo "       Set QEMU_SYSTEM_ARM=/path/to/qemu-system-arm, or install QEMU." >&2
    echo "       Canonical curriculum baseline: QEMU 11.1.1 (tag v11.1.1," >&2
    echo "       peeled commit c3d48b7d1e89604920e5b81b91140c2ad39a1943)." >&2
    exit 2
fi

mkdir -p "$(dirname "$OUT_DTB")" "$(dirname "$OUT_JSON")"

RAW="$(dirname "$OUT_DTB")/.virt.raw.dtb"
rm -f "$RAW" 2>/dev/null || true

echo "=== [1/4] Dumping the real QEMU device tree ==="
echo "    qemu-system-arm -machine $QEMU_MACHINE,dumpdtb=$RAW -cpu $QEMU_CPU -m $QEMU_MEM -smp $QEMU_SMP"
"$QEMU" -machine "${QEMU_MACHINE},dumpdtb=${RAW}" -cpu "$QEMU_CPU" -m "$QEMU_MEM" -smp "$QEMU_SMP"

[ -s "$RAW" ] || { echo "ERROR: QEMU did not produce $RAW" >&2; exit 2; }

QEMU_VERSION=$("$QEMU" --version | head -n 1)

echo "=== [2/4] Normalising to canonical FDT layout ==="
"$PY" scripts/fdtlib_min.py "$RAW" --serialise "$OUT_DTB"

echo "=== [3/4] Verifying the normalised tree equals the raw tree ==="
"$PY" scripts/dt_roundtrip_check.py "$RAW" "$OUT_DTB" --quiet \
    || { echo "ERROR: normalisation changed the tree; refusing to emit an artifact" >&2; exit 2; }

RAW_SHA=$(sha256sum "$RAW" | awk '{print $1}')
NORM_SHA=$(sha256sum "$OUT_DTB" | awk '{print $1}')
RAW_SIZE=$(wc -c < "$RAW" | tr -d ' ')
NORM_SIZE=$(wc -c < "$OUT_DTB" | tr -d ' ')

echo "=== [4/4] Recording provenance ==="
cat > "$OUT_JSON" <<JSON
{
  "artifact": "$(basename "$OUT_DTB")",
  "generated_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "producer": "qemu-system-arm dumpdtb",
  "qemu_version_string": "${QEMU_VERSION}",
  "qemu_binary": "${QEMU}",
  "machine": "${QEMU_MACHINE}",
  "cpu": "${QEMU_CPU}",
  "memory": "${QEMU_MEM}",
  "smp": "${QEMU_SMP}",
  "raw_dump_bytes": ${RAW_SIZE},
  "raw_dump_sha256": "${RAW_SHA}",
  "normalised_bytes": ${NORM_SIZE},
  "normalised_sha256": "${NORM_SHA}",
  "normalisation": "re-serialised in canonical FDT layout; tree verified semantically identical to the raw dump by scripts/dt_roundtrip_check.py",
  "nondeterministic_properties": ["chosen/rng-seed", "chosen/kaslr-seed"],
  "canonical_baseline": {
    "qemu_tag": "v11.1.1",
    "qemu_peeled_commit": "c3d48b7d1e89604920e5b81b91140c2ad39a1943",
    "is_canonical_runtime": false,
    "note": "the runtime used here is whatever qemu-system-arm was found on the host; compare qemu_version_string against the canonical baseline before claiming canonical runtime evidence"
  }
}
JSON

rm -f "$RAW" 2>/dev/null || true

echo "[OK] DTB        : $OUT_DTB  (sha256 $NORM_SHA)"
echo "[OK] Provenance : $OUT_JSON"
echo "[NOTE] The DTB is NOT byte-reproducible across QEMU invocations: chosen/rng-seed"
echo "       and chosen/kaslr-seed are randomised per run.  Compare trees, not hashes."
