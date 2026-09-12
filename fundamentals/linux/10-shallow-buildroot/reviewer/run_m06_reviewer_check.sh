#!/usr/bin/env bash
# P3-M06 Reviewer-Only Full Authoring Regression.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M06_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M06_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

echo "##################################################################"
echo "# P3-M06 REVIEWER-CHECK - AUTHORING REGRESSION (REVIEWER-ONLY)  #"
echo "##################################################################"

echo ""
echo "===== [1/6] Learner/Reviewer Isolation Audit ====="
bash reviewer/audit_learner_isolation.sh

echo ""
echo "===== [2/6] Materialise Assessment Fixtures (opaque) ====="
bash reviewer/scripts/generate_m06_assessment_fixtures.sh
echo "[PASS] assessment fragments + hidden seed mappings materialised."

echo ""
echo "===== [3/6] Learner-Safe Module Check (no reviewer tooling) ====="
make check

echo ""
echo "===== [4/6] Adversarial Mutation Suite ====="
bash reviewer/test_m06_mutations.sh

echo ""
echo "===== [5/6] Oracle Regression Suite ====="
bash reviewer/test_m06_oracle_mutations.sh

echo ""
echo "===== [6/6] Real-source cross-validation ====="
BR_SRC="${BUILDROOT_SRC:-}"
if [ -n "$BR_SRC" ] && [ -f "$BR_SRC/Makefile" ]; then
    # Resolve to a form the native interpreter can open.  On MSYS/Git Bash
    # `pwd -W` yields the Windows path; elsewhere it is unavailable and the
    # plain POSIX path is already correct.
    BR_SRC_ABS=$(cd "$BR_SRC" && { pwd -W 2>/dev/null || pwd; })
    VER=$(sed -n 's/^export BR2_VERSION := //p' "$BR_SRC/Makefile" | head -n 1)
    echo "[INFO] Buildroot source: $BR_SRC_ABS (version ${VER:-unknown})"
    "$PY" - "$BR_SRC_ABS" <<'PYEOF'
import json, os, subprocess, sys
src = sys.argv[1]
table = json.load(open("fixtures/buildroot-symbols.json", encoding="utf-8"))
missing = []
for symbol, meta in table.get("symbols", {}).items():
    path = os.path.join(src, meta["file"])
    found = False
    if os.path.isfile(path):
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            for index, line in enumerate(handle, start=1):
                if line.strip() == f"config {symbol}":
                    found = True
                    if index != meta["line"]:
                        print(f"[NOTE] {symbol}: recorded line {meta['line']}, found {index} "
                              "(source moved; the symbol still exists)")
                    break
    if not found:
        missing.append(symbol)
if missing:
    print(f"[FAIL] symbols not found in the real source tree: {missing}", file=sys.stderr)
    sys.exit(1)
print(f"[PASS] all {len(table.get('symbols', {}))} recorded symbols verified against the real tree")
PYEOF

    # Stage 6b: Real Buildroot Kconfig defconfig smoke check (fail-closed)
    SMOKE_DIR="build/kconfig-smoke"
    rm -rf "$SMOKE_DIR" 2>/dev/null || true
    mkdir -p "$SMOKE_DIR"
    echo "[INFO] Running real Buildroot defconfig smoke test (fail-closed)..."
    if ! make -C "$BR_SRC" O="$PWD/$SMOKE_DIR" BR2_EXTERNAL="$PWD/fixtures/br2-external" qemu_virt_a7_defconfig; then
        echo "[FAIL] real Buildroot defconfig resolution failed" >&2
        exit 1
    fi
    echo "[PASS] Buildroot defconfig resolved cleanly."

    # Validate complete effective .config using verify_br_config.py
    echo "[INFO] Validating complete effective resolved .config against complete contract profile..."
    if ! "$PY" scripts/verify_br_config.py "$SMOKE_DIR/.config" \
        --profile reviewer/reference/buildroot-2026.05.2-complete.json \
        --symbol-table fixtures/buildroot-symbols.json \
        --effective; then
        echo "[FAIL] Effective resolved .config failed complete contract validation!" >&2
        exit 1
    fi
    echo "[PASS] Effective resolved .config satisfies complete contract profile."

    # Check referenced kernel fragment exists and is source-controlled
    FRAG_PATH="fixtures/br2-external/board/qemu-virt-a7/linux.fragment"
    if [ ! -f "$FRAG_PATH" ]; then
        echo "[FAIL] referenced kernel fragment missing: $FRAG_PATH" >&2
        exit 1
    fi
    if ! git ls-files --error-unmatch "$FRAG_PATH" >/dev/null 2>&1; then
        echo "[FAIL] referenced kernel fragment is not source-controlled in git: $FRAG_PATH" >&2
        exit 1
    fi
    echo "[PASS] Referenced kernel fragment exists and is source-controlled in git ($FRAG_PATH)."

    # Stage 6c: Real Buildroot F12 fidelity regression
    echo "[INFO] Running real Buildroot F12 fidelity regression..."
    BUILDROOT_SRC="$BR_SRC" bash reviewer/test_f12_real_buildroot.sh

    echo "[NOTE] Real kernel-config merge and full Buildroot build status: UNVERIFIED (heavy build not executed on this host)."
else
    echo "[NOTE] no Buildroot source tree supplied (set BUILDROOT_SRC=...): real-source"
    echo "       symbol cross-validation, Kconfig smoke test & F12 fidelity SKIPPED (UNVERIFIED on this host)."
    echo "       Canonical baseline: 2026.05.2 (tag 2026.05.2, peeled commit 72d9d4fa636a371ef9eb99c92a735ce9f6d829d5)."
fi

echo ""
echo "=== P3-M06 REVIEWER-CHECK COMPLETE: ALL STAGES PASSED ==="
