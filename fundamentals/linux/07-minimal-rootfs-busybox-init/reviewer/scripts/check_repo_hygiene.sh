#!/bin/bash
set -euo pipefail

# P3-M03 repository-hygiene regression (REVIEWER-ONLY).
#
# Rejects re-vendoring of the generated real BusyBox staging tree into Git:
# the scored real-BusyBox runtime is provisioned on demand from the verified
# local BUSYBOX_STAGING, and the repository tracks only small opaque
# assignment inputs (fixtures/candidate.layer). A future generator run must
# not accidentally re-add the full binary + applet forest, and no
# human-readable mutation recipe may return to the fixture inputs.
#
# Checks (all on TRACKED files via `git ls-files`, never the working tree):
#   1. no tracked bin/busybox under assessment/reference trees;
#   2. no tracked full applet forest (bin/ sbin/ usr/bin/ usr/sbin/) under
#      those trees;
#   3. no tracked real-BusyBox reference archive;
#   4. bounded tracked file counts for scored fixture directories;
#   5. opaque assignment inputs present, bounded, and recipe-free; the
#      retired plaintext recipe names are gone; learner provisioning source
#      carries no assessment-specific defect list.
#   6. materialization + cleanup produces zero unintended git churn
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
# Generic: any tracked busybox-named payload under the scored trees.
if tracked | grep -Eq "07-minimal-rootfs-busybox-init/(challenge/fixtures/defective_rootfs|gate/fixtures/defective_rootfs|reviewer/reference)/.*busybox"; then
    hits=$(tracked | grep -E "07-minimal-rootfs-busybox-init/(challenge/fixtures/defective_rootfs|gate/fixtures/defective_rootfs|reviewer/reference)/.*busybox" || true)
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

# 4. Bounded small assignment inputs remain tracked.
n_chal_fixtures=$(tracked | grep -c -F "07-minimal-rootfs-busybox-init/challenge/fixtures/" || true)
n_gate_fixtures=$(tracked | grep -c -F "07-minimal-rootfs-busybox-init/gate/fixtures/" || true)
sec_start=$FAILURES
if [ "$n_chal_fixtures" -gt 15 ]; then
    fail "challenge/fixtures/ tracks $n_chal_fixtures files (expected <=15 small input files)"
else
    pass "challenge/fixtures/ tracks $n_chal_fixtures small input files (bounded)"
fi
if [ "$n_gate_fixtures" -gt 15 ]; then
    fail "gate/fixtures/ tracks $n_gate_fixtures files (expected <=15 small input files)"
else
    pass "gate/fixtures/ tracks $n_gate_fixtures small input files (bounded)"
fi

# Blob access prefers the Git index (so staged updates verify before
# commit), then HEAD, then the working tree as a last resort.
blob_of() {  # blob_of <repo-rel-path> <work-path>
    git cat-file -p ":$1" 2>/dev/null || git cat-file -p "HEAD:$1" 2>/dev/null \
        || cat "$2" 2>/dev/null || true
}
blob_size() {  # blob_size <repo-rel-path> <work-path>
    git cat-file -s ":$1" 2>/dev/null || git cat-file -s "HEAD:$1" 2>/dev/null \
        || wc -c < "$2" 2>/dev/null || echo 999999
}
# 5. Opaque assignment inputs present, bounded, and recipe-free.
sec_start=$FAILURES
for f in \
    "challenge/fixtures/candidate.layer" \
    "gate/fixtures/candidate.layer" \
    "scripts/apply_candidate_layer.py" \
    ; do
    rel="fundamentals/linux/07-minimal-rootfs-busybox-init/$f"
    if ! tracked | grep -qxF "$rel"; then
        fail "required opaque assignment input not tracked: $f"
        continue
    fi
    # Size bound: each layer must stay small (binary assignment input,
    # never a BusyBox payload or an applet forest).
    sz=$(blob_size "$rel" "$M03_ROOT/$f")
    if [ "$sz" -gt 32768 ]; then
        fail "assignment input too large ($sz bytes): $f (expected <=32 KiB)"
    fi
done
# The retired plaintext recipe must be gone from Git.
for f in \
    "challenge/fixtures/defects.manifest" \
    "gate/fixtures/defects.manifest" \
    ; do
    rel="fundamentals/linux/07-minimal-rootfs-busybox-init/$f"
    if tracked | grep -qxF "$rel"; then
        fail "retired human-readable mutation recipe still tracked: $f"
    fi
done
if tracked | grep -E -q "07-minimal-rootfs-busybox-init/(challenge|gate)/fixtures/defective_overlay/"; then
    fail "retired plaintext assessment overlay still tracked under fixtures/"
fi
# No recipe cleartext in tracked fixture inputs (text scan skips the
# binary layers themselves).
for dir in challenge/fixtures gate/fixtures; do
    while IFS= read -r file; do
        case "$file" in
            *.layer) continue ;;
        esac
        if blob_of "fundamentals/linux/07-minimal-rootfs-busybox-init/$file" "$M03_ROOT/$file" \
            | grep -I -E -q 'overlay|symlink|remove|chmod|stale_target|nonexistent_target|sysinit|askfirst'; then
            fail "recipe cleartext in tracked fixture input: $file"
        fi
    done < <(tracked | grep -F "07-minimal-rootfs-busybox-init/$dir/" \
        | sed 's|.*07-minimal-rootfs-busybox-init/||' || true)
done
# Learner provisioning source must stay generic: no assessment-specific
# defect list may live in the learner-visible provision path.
for f in \
    "scripts/apply_candidate_layer.py" \
    "scripts/provision_challenge_candidate.sh" \
    "scripts/provision_gate_candidate.sh" \
    ; do
    rel="fundamentals/linux/07-minimal-rootfs-busybox-init/$f"
    body=$(blob_of "$rel" "$M03_ROOT/$f")
    if echo "$body" | grep -E -q 'stale_target|nonexistent_target|defects.manifest|defective_overlay|sysinit|askfirst'; then
        fail "assessment-specific defect content in learner provisioning source: $f"
    fi
done
if [ "$FAILURES" -eq "$sec_start" ]; then
    pass "opaque assignment inputs present, bounded, and recipe-free"
fi

echo "------------------------------------------------------------------"
if [ "$FAILURES" -eq 0 ]; then
    echo "[HYGIENE PASS] P3-M03 repository hygiene VERIFIED (no vendored BusyBox staging)"
    exit 0
fi
echo "[HYGIENE FAIL] $FAILURES hygiene violation(s)" >&2
exit 1
