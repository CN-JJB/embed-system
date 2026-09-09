#!/bin/bash
set -euo pipefail

# Reviewer Grading Oracle for P3-M03 Gate (REVIEWER-ONLY entry point).
# Grades the learner's repaired candidate submission:
#   gate/build/candidate_rootfs (+ gate/build/candidate.cpio.gz if present).
# Delegates all semantics to reviewer/oracle_m03.sh so the scored contract
# lives in exactly one place.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

CANDIDATE="${1:-$M03_ROOT/gate/build/candidate_rootfs}"
ARCHIVE="${2:-}"
if [ -z "$ARCHIVE" ] && [ -f "$M03_ROOT/gate/build/candidate.cpio.gz" ]; then
    ARCHIVE="$M03_ROOT/gate/build/candidate.cpio.gz"
fi

if [ ! -d "$CANDIDATE" ]; then
    echo "REJECT: Gate candidate '$CANDIDATE' does not exist." >&2
    echo "        Provision and repair first: make -C gate provision" >&2
    exit 2
fi

bash "$M03_ROOT/reviewer/oracle_m03.sh" "$CANDIDATE" ${ARCHIVE:+"$ARCHIVE"}
echo "[PASS] P3-M03 Gate Submission: VERIFIED (100/100)"
