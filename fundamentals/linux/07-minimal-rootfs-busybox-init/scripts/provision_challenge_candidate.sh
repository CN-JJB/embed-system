#!/bin/bash
set -euo pipefail

# Learner-safe provisioner for the P3-M03 Challenge candidate (LEARNER-SAFE).
#
# Materializes a defective REAL BusyBox candidate tree from:
#   1. verified local BUSYBOX_STAGING (real BusyBox 1.36.1 install tree from
#      scripts/build_real_busybox.sh), via scripts/provision_real_busybox_tree.sh;
#   2. the small opaque assignment input challenge/fixtures/candidate.layer,
#      applied by the generic scripts/apply_candidate_layer.py.
#
# The full BusyBox binary + applet forest are NEVER tracked in Git; they are
# injected reproducibly from the learner/author's verified local staging.
# This script never calls the grading subtree and never reveals hidden
# reference logic: it only instantiates the assigned candidate tree the
# learner must diagnose. Provisioning prints no assignment details.
#
# Usage: provision_challenge_candidate.sh <out-rootfs-dir>
# Environment:
#   BUSYBOX_STAGING : verified staging (default /tmp/rootfs-busybox-staging)

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
LAYER="$M03_ROOT/challenge/fixtures/candidate.layer"

OUT="${1:-}"
if [ -z "$OUT" ]; then
    echo "ERROR: destination rootfs directory required." >&2
    exit 1
fi
case "$OUT" in
    /|.|..)
        echo "ERROR: refusing a dangerous destination: '$OUT'" >&2
        exit 1
        ;;
esac

if [ ! -f "$LAYER" ]; then
    echo "ERROR: assignment layer missing: $LAYER" >&2
    exit 1
fi

# 1. Provision the verified real BusyBox base tree (validates staging identity).
# Fail closed here too: an infrastructure error during base materialization
# must not leave a partial directory that a later learner `make provision`
# could mistake for an existing candidate.
if bash "$M03_ROOT/scripts/provision_real_busybox_tree.sh" "$OUT" >/dev/null; then
    :
else
    rc=$?
    rm -rf "$OUT"
    echo "ERROR: base BusyBox candidate materialization failed." >&2
    exit "$rc"
fi

# 2. Apply the opaque assignment input (generic applicator, fail closed).
# On failure the partial tree is removed so a retry starts clean. The
# applicator status is captured without negation so the original exit class
# (0 applied / 2 semantic REJECT / 1 materialization failure) propagates.
if python3 "$M03_ROOT/scripts/apply_candidate_layer.py" "$LAYER" "$OUT"; then
    :
else
    rc=$?
    rm -rf "$OUT"
    if [ "$rc" -eq 2 ]; then
        echo "REJECT: assignment input failed validation." >&2
    else
        echo "ERROR: candidate materialization failed." >&2
    fi
    exit "$rc"
fi

echo "[PASS] Challenge candidate provisioned at: $OUT (verified staging + opaque assignment layer)"
