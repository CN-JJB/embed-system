#!/bin/bash
set -euo pipefail

# P3-M03 repository-hygiene regression (REVIEWER-ONLY).
#
# Rejects re-vendoring of the generated real BusyBox staging tree into Git:
# the scored real-BusyBox runtime is provisioned on demand from the verified
# local BUSYBOX_STAGING, and the repository tracks only small assessment
# deltas (defects.manifest + defective_overlay/). A future generator run must
# not accidentally re-add the full binary + applet forest.
#
# Checks (all on TRACKED files via `git ls-files`, never the working tree):
#   1. no tracked bin/busybox under assessment/reference trees;
#   2. no tracked full applet forest (bin/ sbin/ usr/bin/ usr/sbin/) under
#      those trees;
#   3. no tracked real-BusyBox reference archive;
#   4. bounded tracked file counts for scored fixture directories;
#   5. materialization + cleanup produces zero unintended git churn
#      (covered by the caller re-running `git status --porcelain`).
#
# Usage: check_repo_hygiene.sh
# Must be run from within the module or repo; uses `git ls-files`.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
REPO_ROOT=$(git -C "$M03_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "")
cd "$M03_ROOT"

FAILURES=0
fail() { echo "[HYGIENE FAIL] $1" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "[HYGIENE PASS] $1"; }

# All checks operate on the Git index (tracked files), so ignored
# materialized outputs (defective_rootfs/, reference trees) do not count.
# --full-name keeps repo-relative paths regardless of cwd.
tracked() { git -C "$M03_ROOT" ls-files --full-name; }

echo "=== P3-M03 repository-hygiene regression (tracked files only) ==="

# 1. No tracked generated BusyBox executable in assessment/reference trees.
sec_start=$FAILURES
for pat in \
    "challenge/fixtures/defective_rootfs/bin/busybox" \
    "gate/fixtures/defective_rootfs/bin/busybox" \
    "reviewer/reference/challenge_rootfs/bin/busybox" \
    "reviewer/reference/gate_rootfs/bin/busybox" \
    "reviewer/reference/gate_rootfs.cpio.gz" \
    ; do
    if tracked | grep -qxF "fundamentals/linux/07-minimal-rootfs-busybox-init/$pat"; then
        fail "tracked generated payload present: $pat"
    fi
done
# Generic: any tracked bin/busybox under the scored trees.
if tracked | grep -E "07-minimal-rootfs-busybox-init/(challenge/fixtures/defective_rootfs|gate/fixtures/defective_rootfs|reviewer/reference)/.*busybox" | grep -qv "defects.manifest"; then
    # Filter to actual binary paths (exclude the manifest/overlay docs).
    hits=$(tracked | grep -E "07-minimal-rootfs-busybox-init/(challenge/fixtures/defective_rootfs|gate/fixtures/defective_rootfs|reviewer/reference)/.*busybox" | grep -v "defects.manifest" || true)
    # Overlay/manifest must never carry a busybox binary; any hit is a violation
    # unless it is the small manifest text itself (already excluded).
    if echo "$hits" | grep -Eq "/bin/busybox|\\.cpio"; then
        fail "tracked BusyBox binary/archive under assessment/reference trees:"
        echo "$hits" | sed 's/^/    /' >&2
    fi
fi
if [ "$FAILURES" -eq "$sec_start" ]; then
    pass "no tracked generated BusyBox executable/archive in assessment/reference trees"
fi

# 2. No tracked full applet forest under the scored trees.
sec_start=$FAILURES
for prefix in \
    "fundamentals/linux/07-minimal-rootfs-busybox-init/challenge/fixtures/defective_rootfs/bin/" \
    "fundamentals/linux/07-minimal-rootfs-busybox-init/challenge/fixtures/defective_rootfs/sbin/" \
    "fundamentals/linux/07-minimal-rootfs-busybox-init/challenge/fixtures/defective_rootfs/usr/bin/" \
    "fundamentals/linux/07-minimal-rootfs-busybox-init/challenge/fixtures/defective_rootfs/usr/sbin/" \
    "fundamentals/linux/07-minimal-rootfs-busybox-init/gate/fixtures/defective_rootfs/bin/" \
    "fundamentals/linux/07-minimal-rootfs-busybox-init/gate/fixtures/defective_rootfs/sbin/" \
    "fundamentals/linux/07-minimal-rootfs-busybox-init/gate/fixtures/defective_rootfs/usr/bin/" \
    "fundamentals/linux/07-minimal-rootfs-busybox-init/gate/fixtures/defective_rootfs/usr/sbin/" \
    "fundamentals/linux/07-minimal-rootfs-busybox-init/reviewer/reference/challenge_rootfs/bin/" \
    "fundamentals/linux/07-minimal-rootfs-busybox-init/reviewer/reference/gate_rootfs/bin/" \
    ; do
    n=$(tracked | grep -c -F "$prefix" || true)
    if [ "$n" -ne 0 ]; then
        fail "tracked applet forest under $prefix ($n entries; expected 0)"
    fi
done
if [ "$FAILURES" -eq "$sec_start" ]; then
    pass "no tracked applet forest under scored fixture/reference trees"
fi

# 3. No tracked generated reference trees/archives at all.
n_chal_def=$(tracked | grep -c -F "07-minimal-rootfs-busybox-init/challenge/fixtures/defective_rootfs/" || true)
n_gate_def=$(tracked | grep -c -F "07-minimal-rootfs-busybox-init/gate/fixtures/defective_rootfs/" || true)
n_ref=$(tracked | grep -c -F "07-minimal-rootfs-busybox-init/reviewer/reference/" || true)
if [ "$n_chal_def" -ne 0 ]; then
    fail "tracked files under challenge/fixtures/defective_rootfs/ ($n_chal_def; expected 0: materialized on demand, gitignored)"
fi
if [ "$n_gate_def" -ne 0 ]; then
    fail "tracked files under gate/fixtures/defective_rootfs/ ($n_gate_def; expected 0: materialized on demand, gitignored)"
fi
if [ "$n_ref" -ne 0 ]; then
    fail "tracked files under reviewer/reference/ ($n_ref; expected 0: materialized on demand, gitignored)"
fi
if [ "$n_chal_def" -eq 0 ] && [ "$n_gate_def" -eq 0 ] && [ "$n_ref" -eq 0 ]; then
    pass "no tracked generated assessment/reference trees (all materialized on demand)"
fi

# 4. Bounded small assessment deltas remain tracked.
n_chal_fixtures=$(tracked | grep -c -F "07-minimal-rootfs-busybox-init/challenge/fixtures/" || true)
n_gate_fixtures=$(tracked | grep -c -F "07-minimal-rootfs-busybox-init/gate/fixtures/" || true)
sec_start=$FAILURES
if [ "$n_chal_fixtures" -gt 15 ]; then
    fail "challenge/fixtures/ tracks $n_chal_fixtures files (expected <=15 small delta files)"
else
    pass "challenge/fixtures/ tracks $n_chal_fixtures small delta files (bounded)"
fi
if [ "$n_gate_fixtures" -gt 15 ]; then
    fail "gate/fixtures/ tracks $n_gate_fixtures files (expected <=15 small delta files)"
else
    pass "gate/fixtures/ tracks $n_gate_fixtures small delta files (bounded)"
fi

# 5. Required small deltas are present and tiny (no binary payload smuggled).
sec_start=$FAILURES
for f in \
    "challenge/fixtures/defects.manifest" \
    "challenge/fixtures/defective_overlay/etc/inittab" \
    "challenge/fixtures/defective_overlay/etc/init.d/rcS" \
    "gate/fixtures/defects.manifest" \
    "gate/fixtures/defective_overlay/etc/inittab" \
    "gate/fixtures/defective_overlay/etc/init.d/rcS" \
    ; do
    rel="fundamentals/linux/07-minimal-rootfs-busybox-init/$f"
    if ! tracked | grep -qxF "$rel"; then
        fail "required small assessment delta not tracked: $f"
        continue
    fi
    # Size bound: each delta file must be < 8 KiB (text overlay, not a binary).
    sz=$(git cat-file -s "HEAD:$rel" 2>/dev/null || wc -c < "$M03_ROOT/$f" 2>/dev/null || echo 999999)
    if [ "$sz" -gt 8192 ]; then
        fail "assessment delta too large ($sz bytes): $f (expected <8 KiB text)"
    fi
done
if [ "$FAILURES" -eq "$sec_start" ]; then
    pass "required small assessment deltas present and bounded (<8 KiB each)"
fi

echo "------------------------------------------------------------------"
if [ "$FAILURES" -eq 0 ]; then
    echo "[HYGIENE PASS] P3-M03 repository hygiene VERIFIED (no vendored BusyBox staging)"
    exit 0
fi
echo "[HYGIENE FAIL] $FAILURES hygiene violation(s)" >&2
exit 1
