#!/bin/bash
set -euo pipefail

# P3-M03 Assignment-Layer Safety + Equivalence Regression (REVIEWER-ONLY).
#
# Covers the opaque candidate.layer assessment packaging:
#   A. generic applicator fail-closed suite (exit 0 applied / 2 semantic
#      REJECT / 1 infrastructure-materialization failure);
#   B. adversarial plain-text mutation recipe is flagged by the recipe
#      scanner while the clean fixture inputs pass;
#   C. learner materialization == reviewer materialization (semantic tree
#      equivalence: paths, file contents, symlink targets, relevant modes,
#      BusyBox payload identity) for both rotated variants, and both fresh
#      defectives are REJECTed by the static oracle.
#
# Every test is graded as PREP PASS / EXECUTION PASS / INTENDED RESULT.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M03_ROOT"

APPLY="python3 scripts/apply_candidate_layer.py"
BUILD="python3 reviewer/scripts/make_candidate_layer.py"
SCANNER="bash reviewer/scripts/scan_recipe_text.sh"
ORACLE="bash reviewer/oracle_m03.sh"

TOTAL_TESTS=0
PASSED_TESTS=0

pass_test() {  # pass_test <id> <desc>
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo "[TEST $1 PASS] $2"
}

fail_test() {  # fail_test <id> <desc> [detail]
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo "[TEST $1 FAIL] $2" >&2
    [ -n "${3:-}" ] && echo "$3" >&2 || true
    exit 1
}

echo "=================================================================="
echo "=== P3-M03 Assignment-Layer Safety + Equivalence (REVIEWER-ONLY) =="
echo "=================================================================="

MUTWORK=$(mktemp -d /tmp/m03_layersafety_XXXXXX)
trap 'rm -rf "$MUTWORK"' EXIT

# ---- PREP: one verified base tree, copied per case ----------------------
BASE="$MUTWORK/base"
BUSYBOX_STAGING="${BUSYBOX_STAGING:-/tmp/rootfs-busybox-staging}"
[ -f "$BUSYBOX_STAGING/bin/busybox" ] \
    || { echo "[PREP FAIL] verified staging missing: $BUSYBOX_STAGING" >&2; exit 1; }
bash scripts/provision_real_busybox_tree.sh "$BASE" >/dev/null
echo "[PREP] Verified base tree staged."

# expect_rc <id> <desc> <want-rc> <layer>  (fresh scratch copy per case)
expect_rc() {
    local id="$1" desc="$2" want="$3" layer="$4"
    local dest="$MUTWORK/case_$id"
    rm -rf "$dest"
    cp -a "$BASE" "$dest"
    local out rc
    set +e
    out=$($APPLY "$layer" "$dest" 2>&1)
    rc=$?
    set -e
    if [ "$rc" -ne "$want" ]; then
        fail_test "$id" "$desc (wanted exit $want, got $rc)" "$out"
    fi
    pass_test "$id" "$desc (exit $rc as intended)"
}

# ---- A1: well-formed neutral layer applies silently ---------------------
NEUTRAL_B64=$(printf 'test-marker\n' | base64 -w 0)
$BUILD --out "$MUTWORK/neutral.layer" \
    --file "etc/motd:644:$NEUTRAL_B64" >/dev/null
DEST="$MUTWORK/case_A1"
rm -rf "$DEST"
cp -a "$BASE" "$DEST"
set +e
OUT=$($APPLY "$MUTWORK/neutral.layer" "$DEST" 2>&1)
RC=$?
set -e
[ "$RC" -eq 0 ] || fail_test "A1" "neutral layer applies" "$OUT"
[ -z "$OUT" ] || fail_test "A1" "applicator stays silent on success" "$OUT"
[ "$(cat "$DEST/etc/motd")" = "test-marker" ] \
    || fail_test "A1" "neutral file content applied" ""
[ "$(stat -c '%a' "$DEST/etc/motd")" = "644" ] \
    || fail_test "A1" "neutral file mode applied" ""
pass_test "A1" "well-formed neutral layer applies silently with effects"

# ---- A: hostile layers (built with the generic builder; values stay in
# /tmp and are never tracked) ----------------------------------------------
$BUILD --out "$MUTWORK/absolute.layer" \
    --file "/etc/evil:644:$NEUTRAL_B64" >/dev/null
expect_rc "A2" "absolute path rejected" 2 "$MUTWORK/absolute.layer"

$BUILD --out "$MUTWORK/traversal.layer" \
    --file "a/../../evil:644:$NEUTRAL_B64" >/dev/null
expect_rc "A3" "dotdot traversal rejected" 2 "$MUTWORK/traversal.layer"

$BUILD --out "$MUTWORK/dot.layer" \
    --file "a/./b:644:$NEUTRAL_B64" >/dev/null
expect_rc "A4" "dot component rejected" 2 "$MUTWORK/dot.layer"

# Duplicate/conflicting records for one path (hand-framed: the generic
# builder refuses dupes, so frame the bytes directly).
python3 - "$MUTWORK/dupe.layer" <<'PY'
import gzip, struct, sys
out = sys.argv[1]
body = b"M03L" + b"\x01" + struct.pack(">H", 2)
for _ in range(2):
    pb = b"etc/motd"
    cb = b"x\n"
    body += bytes((0x46,)) + struct.pack(">H", len(pb)) + pb
    body += struct.pack(">H", 0o644) + struct.pack(">L", len(cb)) + cb
open(out, "wb").write(gzip.compress(body, compresslevel=9, mtime=0))
PY
expect_rc "A5" "duplicate conflicting records rejected" 2 "$MUTWORK/dupe.layer"

# Unsupported entry type (hand-framed).
python3 - "$MUTWORK/badtype.layer" <<'PY'
import gzip, struct, sys
out = sys.argv[1]
pb = b"etc/motd"
body = b"M03L" + b"\x01" + struct.pack(">H", 1)
body += bytes((0x99,)) + struct.pack(">H", len(pb)) + pb
open(out, "wb").write(gzip.compress(body, compresslevel=9, mtime=0))
PY
expect_rc "A6" "unsupported entry type rejected" 2 "$MUTWORK/badtype.layer"

$BUILD --out "$MUTWORK/badmode.layer" \
    --file "etc/motd:600:$NEUTRAL_B64" >/dev/null
expect_rc "A7" "disallowed mode rejected" 2 "$MUTWORK/badmode.layer"

BB_B64=$(printf 'x\n' | base64 -w 0)
$BUILD --out "$MUTWORK/protected.layer" \
    --file "bin/busybox:755:$BB_B64" >/dev/null
expect_rc "A8" "protected BusyBox payload write rejected" 2 "$MUTWORK/protected.layer"

$BUILD --out "$MUTWORK/protwhite.layer" \
    --whiteout "bin/busybox" >/dev/null
expect_rc "A9" "protected BusyBox payload deletion rejected" 2 "$MUTWORK/protwhite.layer"

$BUILD --out "$MUTWORK/widewhite.layer" \
    --whiteout "etc/inittab" >/dev/null
expect_rc "A10" "deletion outside applet directories rejected" 2 "$MUTWORK/widewhite.layer"

$BUILD --out "$MUTWORK/absentwhite.layer" \
    --whiteout "bin/no_such_entry" >/dev/null
expect_rc "A11" "deletion of absent target is a materialization failure" 1 "$MUTWORK/absentwhite.layer"

$BUILD --out "$MUTWORK/abstarget.layer" \
    --symlink="bin/echo:/bin/busybox" >/dev/null
expect_rc "A12" "absolute symlink target rejected" 2 "$MUTWORK/abstarget.layer"

$BUILD --out "$MUTWORK/dottarget.layer" \
    --symlink="bin/echo:.." >/dev/null
expect_rc "A13" "dotdot symlink target rejected" 2 "$MUTWORK/dottarget.layer"

BIG_B64=$(head -c 5000 /dev/zero | base64 -w 0)
$BUILD --out "$MUTWORK/oversize.layer" \
    --file "etc/motd:644:$BIG_B64" >/dev/null
expect_rc "A14" "oversize file content rejected" 2 "$MUTWORK/oversize.layer"

NUL_B64=$(printf 'a\x00b' | base64 -w 0)
$BUILD --out "$MUTWORK/nul.layer" \
    --file "etc/motd:644:$NUL_B64" >/dev/null
expect_rc "A15" "NUL file content rejected" 2 "$MUTWORK/nul.layer"

head -c 40 "$MUTWORK/neutral.layer" > "$MUTWORK/truncated.layer"
expect_rc "A16" "truncated layer is a materialization failure" 1 "$MUTWORK/truncated.layer"

head -c 32 /dev/urandom > "$MUTWORK/garbage.layer"
expect_rc "A17" "non-layer bytes are a materialization failure" 1 "$MUTWORK/garbage.layer"

python3 - "$MUTWORK/trailing.layer" "$MUTWORK/neutral.layer" <<'PY'
import gzip, sys
out, src = sys.argv[1], sys.argv[2]
raw = gzip.decompress(open(src, "rb").read()) + b"TRAILING"
open(out, "wb").write(gzip.compress(raw, compresslevel=9, mtime=0))
PY
expect_rc "A18" "trailing garbage is a materialization failure" 1 "$MUTWORK/trailing.layer"

python3 - "$MUTWORK/empty.layer" <<'PY'
import gzip, struct, sys
body = b"M03L" + b"\x01" + struct.pack(">H", 0)
open(sys.argv[1], "wb").write(gzip.compress(body, compresslevel=9, mtime=0))
PY
expect_rc "A19" "empty layer is a materialization failure" 1 "$MUTWORK/empty.layer"

python3 - "$MUTWORK/badmagic.layer" <<'PY'
import gzip, sys
open(sys.argv[1], "wb").write(gzip.compress(b"XXXX" + b"\x01" + b"\x00\x01", compresslevel=9, mtime=0))
PY
expect_rc "A20" "bad magic is a materialization failure" 1 "$MUTWORK/badmagic.layer"

DEST="$MUTWORK/case_A21"
rm -rf "$DEST"
cp -a "$BASE" "$DEST"
set +e
OUT=$($APPLY "$MUTWORK/does-not-exist.layer" "$DEST" 2>&1)
RC=$?
set -e
[ "$RC" -eq 1 ] || fail_test "A21" "missing layer is a materialization failure (got $RC)" "$OUT"
pass_test "A21" "missing layer is a materialization failure"

# ---- B: adversarial plain-text recipe is flagged; clean inputs pass -----
RECIPE_DIR="$MUTWORK/recipe_trap"
mkdir -p "$RECIPE_DIR"
printf 'overlay etc/inittab\noverlay etc/init.d/rcS\nchmod 644 etc/init.d/rcS\nsymlink bin/ls stale_target\n' \
    > "$RECIPE_DIR/defects.manifest"
set +e
OUT=$($SCANNER "$RECIPE_DIR" 2>&1)
RC=$?
set -e
[ "$RC" -ne 0 ] && echo "$OUT" | grep -q "REJECT" \
    || fail_test "B1" "planted plain-text mutation recipe is rejected" "$OUT"
pass_test "B1" "planted plain-text mutation recipe is rejected"

set +e
OUT=$($SCANNER challenge/fixtures gate/fixtures 2>&1)
RC=$?
set -e
[ "$RC" -eq 0 ] || fail_test "B2" "clean opaque fixture inputs pass the scanner" "$OUT"
pass_test "B2" "clean opaque fixture inputs pass the scanner"

# ---- C: learner == reviewer materialization (semantic equivalence) -------
compare_trees() {  # compare_trees <id> <desc> <tree-a> <tree-b>
    local id="$1" desc="$2" ta="$3" tb="$4"
    local la lb
    la=$(cd "$ta" && find . -mindepth 1 | LC_ALL=C sort)
    lb=$(cd "$tb" && find . -mindepth 1 | LC_ALL=C sort)
    [ "$la" = "$lb" ] || fail_test "$id" "$desc: path sets differ" "$(diff <(echo "$la") <(echo "$lb") | head -n 10)"
    while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        local a="$ta/$rel" b="$tb/$rel"
        if [ -L "$a" ] || [ -L "$b" ]; then
            [ -L "$a" ] && [ -L "$b" ] \
                || fail_test "$id" "$desc: entry kind differs at $rel" ""
            [ "$(readlink "$a")" = "$(readlink "$b")" ] \
                || fail_test "$id" "$desc: symlink target differs at $rel" ""
        elif [ -f "$a" ] && [ -f "$b" ]; then
            [ "$(sha256sum "$a" | awk '{print $1}')" = "$(sha256sum "$b" | awk '{print $1}')" ] \
                || fail_test "$id" "$desc: file contents differ at $rel" ""
        fi
        [ "$(stat -c '%a' "$a" 2>/dev/null || echo nolink)" = "$(stat -c '%a' "$b" 2>/dev/null || echo nolink)" ] \
            || fail_test "$id" "$desc: modes differ at $rel" ""
    done <<<"$la"
    local sha_a sha_b
    sha_a=$(sha256sum "$ta/bin/busybox" | awk '{print $1}')
    sha_b=$(sha256sum "$tb/bin/busybox" | awk '{print $1}')
    [ "$sha_a" = "$sha_b" ] \
        || fail_test "$id" "$desc: BusyBox payload identity differs" ""
    pass_test "$id" "$desc"
}

for variant in challenge gate; do
    LEARNER_T="$MUTWORK/learner_$variant"
    REVIEW_T="$MUTWORK/reviewer_$variant"
    rm -rf "$LEARNER_T" "$REVIEW_T"
    # Learner path: the learner-safe provisioner wrapper.
    bash "scripts/provision_${variant}_candidate.sh" "$LEARNER_T" >/dev/null
    # Reviewer path: base staging plus the generic applicator directly.
    bash scripts/provision_real_busybox_tree.sh "$REVIEW_T" >/dev/null
    $APPLY "$variant/fixtures/candidate.layer" "$REVIEW_T" >/dev/null
    if [ "$variant" = "challenge" ]; then
        compare_trees "C1" "Challenge learner/reviewer semantic equivalence" "$LEARNER_T" "$REVIEW_T"
        ORACLE_ID="C3"
    else
        compare_trees "C2" "Gate learner/reviewer semantic equivalence" "$LEARNER_T" "$REVIEW_T"
        ORACLE_ID="C4"
    fi
    # Both fresh defectives must be REJECTed by the static oracle.
    set +e
    OUT=$($ORACLE "$LEARNER_T" 2>&1)
    RC=$?
    set -e
    if [ "$RC" -eq 0 ]; then
        fail_test "$ORACLE_ID" "fresh $variant defective is rejected by the oracle" "$OUT"
    fi
    echo "$OUT" | grep -Eq "ASSESSMENT MISMATCH|REJECT" \
        || fail_test "$ORACLE_ID" "fresh $variant rejection carries a semantic pattern" "$OUT"
    pass_test "$ORACLE_ID" "fresh $variant defective is rejected by the oracle"
done

echo "=================================================================="
echo "=== ALL $PASSED_TESTS ASSIGNMENT-LAYER SAFETY CHECKS PASSED ($TOTAL_TESTS/$TOTAL_TESTS) ==="
