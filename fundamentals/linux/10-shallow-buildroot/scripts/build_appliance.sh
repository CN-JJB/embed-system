#!/usr/bin/env bash
# Reproducible Buildroot appliance build wrapper (P3-M06, Lab 6.3).
#
# The build itself is ordinary Buildroot usage; what this wrapper adds is the
# provenance record: the exact Buildroot release identity, the defconfig used,
# the external tree, and the hashes of every artifact the build produced.
#
# Heavy work is opt-in.  Nothing here runs as part of a default Phase 1/2 test
# path.
#
# Usage:
#   scripts/build_appliance.sh [BUILDROOT_SRC] [OUTPUT_DIR]
#
# Environment:
#   BR2_EXTERNAL   path to this repository's external tree
#                  (default: fixtures/br2-external)
#   BR2_DEFCONFIG  defconfig name (default: qemu_virt_a7_defconfig)
#   JOBS           parallel make jobs (default: nproc)
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M06_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M06_ROOT"

BR_SRC="${1:-${BUILDROOT_SRC:-}}"
OUTPUT_DIR="${2:-${OUTPUT_DIR:-build/br-output}}"

BR2_EXTERNAL="${BR2_EXTERNAL:-$M06_ROOT/fixtures/br2-external}"
BR2_DEFCONFIG="${BR2_DEFCONFIG:-qemu_virt_a7_defconfig}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"

CANONICAL_RELEASE="2026.05.2"
CANONICAL_COMMIT="72d9d4fa636a371ef9eb99c92a735ce9f6d829d5"

if [ -z "$BR_SRC" ] || [ ! -f "$BR_SRC/Makefile" ]; then
    echo "ERROR: Buildroot source tree not provided or incomplete." >&2
    echo "       usage: scripts/build_appliance.sh /path/to/buildroot-${CANONICAL_RELEASE}" >&2
    echo "       canonical baseline: Buildroot ${CANONICAL_RELEASE}" >&2
    echo "       tag 2026.05.2, peeled commit ${CANONICAL_COMMIT}" >&2
    exit 2
fi

# --- Verify the Buildroot release identity before building anything ---------
BR_VERSION=$(sed -n 's/^export BR2_VERSION := //p' "$BR_SRC/Makefile" | head -n 1)
echo "=== Buildroot source identity ==="
echo "    tree    : $BR_SRC"
echo "    version : ${BR_VERSION:-<unknown>}  (canonical: ${CANONICAL_RELEASE})"
if [ "$BR_VERSION" != "$CANONICAL_RELEASE" ]; then
    echo "[WARN] the source tree is not the canonical release; record this as an actual-host" >&2
    echo "       alternate rather than canonical build evidence." >&2
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR_ABS=$(cd "$OUTPUT_DIR" && pwd)

echo "=== Configuring (BR2_EXTERNAL=$BR2_EXTERNAL, defconfig=$BR2_DEFCONFIG) ==="
make -C "$BR_SRC" O="$OUTPUT_DIR_ABS" BR2_EXTERNAL="$BR2_EXTERNAL" "$BR2_DEFCONFIG"

echo "=== Building (-j$JOBS) ==="
make -C "$BR_SRC" O="$OUTPUT_DIR_ABS" BR2_EXTERNAL="$BR2_EXTERNAL" -j"$JOBS"

echo "=== Recording provenance ==="
PROV="$OUTPUT_DIR_ABS/BUILD_PROVENANCE.txt"
{
    echo "# P3-M06 Buildroot appliance build provenance"
    echo "buildroot_source: $BR_SRC"
    echo "buildroot_version: ${BR_VERSION:-<unknown>}"
    echo "buildroot_canonical_release: $CANONICAL_RELEASE"
    echo "buildroot_canonical_commit: $CANONICAL_COMMIT"
    echo "br2_external: $BR2_EXTERNAL"
    echo "defconfig: $BR2_DEFCONFIG"
    echo "output_dir: $OUTPUT_DIR_ABS"
    echo "built_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "host: $(uname -a)"
    echo "--- .config hash ---"
    [ -f "$OUTPUT_DIR_ABS/.config" ] && sha256sum "$OUTPUT_DIR_ABS/.config"
    echo "--- output/images ---"
    if [ -d "$OUTPUT_DIR_ABS/images" ]; then
        (cd "$OUTPUT_DIR_ABS/images" && sha256sum * 2>/dev/null || true)
    fi
} > "$PROV"

echo "[OK] provenance written to $PROV"
echo "[NOTE] A successful compile is NOT proof that the generated appliance boots."
echo "       Boot it with scripts/run_buildroot_appliance.sh and bind the capture."
