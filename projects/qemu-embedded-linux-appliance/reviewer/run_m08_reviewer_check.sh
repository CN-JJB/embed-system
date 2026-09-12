#!/usr/bin/env bash
# P3-M08 Reviewer-Only Full Authoring Regression.
#
# Runs the complete authoring surface for the QEMU appliance module:
#   1. learner/reviewer isolation audit;
#   2. deterministic materialisation of assessment fixtures (byte-stable);
#   3. the learner-safe project check (make check);
#   4. the adversarial transfer-mutation suite;
#   5. the semantic-oracle regression suite;
#   6. the provenance/negative-control + validator fail-closed suite.
#
# Then prints explicit UNVERIFIED notices for every evidence dimension that
# cannot run on the current host (real Buildroot build, real appliance boot,
# canonical QEMU 11.1.1), naming the exact command and inputs that close the
# gap. This runner NEVER claims guest boot or canonical-QEMU evidence.
#
# Never called from a learner workflow. Never merges anything.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJ_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$PROJ_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python
if ! command -v "$PY" >/dev/null 2>&1; then
    echo "FATAL: no python interpreter found (missing tool: tried python3/python)" >&2
    exit 2
fi

echo "##################################################################"
echo "# P3-M08 REVIEWER-CHECK - AUTHORING REGRESSION (REVIEWER-ONLY)   #"
echo "##################################################################"

echo ""
echo "===== [1/6] Learner/Reviewer Isolation Audit ====="
bash reviewer/audit_learner_isolation.sh

echo ""
echo "===== [2/6] Materialise Assessment Fixtures (deterministic) ====="
FIXTURE_TREE="build/reviewer-m08-oracle"
SEED_F="reviewer/reference/m08_seed.json"
bash reviewer/scripts/generate_m08_assessment_fixtures.sh

hash_tree() {
    { find "$FIXTURE_TREE" -type f -exec sha256sum {} + 2>/dev/null | sort; \
      sha256sum "$SEED_F"; } | sha256sum
}
H1=$(hash_tree)
rm -rf "$FIXTURE_TREE"
bash reviewer/scripts/generate_m08_assessment_fixtures.sh >/dev/null
H2=$(hash_tree)
if [ "$H1" = "$H2" ]; then
    echo "[PASS] deterministic materialisation: byte-identical across re-run (tree hash $H1)"
else
    echo "[FAIL] assessment fixture materialisation is non-deterministic" >&2
    echo "  first  tree hash: $H1" >&2
    echo "  second tree hash: $H2" >&2
    exit 1
fi

echo ""
echo "===== [3/6] Learner-Safe Project Check (no grading logic) ====="
make check

echo ""
echo "===== [4/6] Adversarial Transfer-Mutation Suite ====="
bash reviewer/test_m08_transfer_mutations.sh

echo ""
echo "===== [5/6] Semantic Oracle Regression Suite ====="
bash reviewer/test_m08_oracle_mutations.sh

echo ""
echo "===== [6/6] Provenance / Negative-Control + Validator Fail-Closed Suite ====="
bash reviewer/test_m08_provenance_negatives.sh

echo ""
echo "=================================================================="
echo "=== EVIDENCE BOUNDARY: dimensions that cannot run on this host  ==="
echo "=================================================================="
echo "[UNVERIFIED] Real Buildroot image build (needs POSIX BUILDROOT_SRC)."
echo "    Command that closes it:"
echo "      make -C <buildroot-2026.05.2> O=\$PWD/build/br-output \\"
echo "        BR2_EXTERNAL=\$PWD/../fundamentals/linux/10-shallow-buildroot/fixtures/br2-external \\"
echo "        qemu_virt_a7_defconfig && make -C <buildroot-2026.05.2> O=\$PWD/build/br-output \\"
echo "        BR2_EXTERNAL=\$PWD/../fundamentals/linux/10-shallow-buildroot/fixtures/br2-external -j\$(nproc)"
echo "[UNVERIFIED] Real appliance QEMU boot + runtime binding (needs real zImage + rootfs.cpio.gz)."
echo "    Command that closes it:"
echo "      bash scripts/run_appliance.sh --manifest build/appliance.manifest.json \\"
echo "        --log build/appliance.log --run build/appliance.run.json"
echo "      python3 scripts/verify_m08_runtime.py --manifest build/appliance.manifest.json \\"
echo "        --run build/appliance.run.json --log build/appliance.log --overlay overlay"
echo "[UNVERIFIED] Canonical QEMU 11.1.1 evidence. This host carries qemu-system-arm 8.2.2"
echo "    (actual-host), NOT canonical 11.1.1. The two evidence dimensions are never conflated;"
echo "    any run record that sets canonical_claim against a non-11.1.1 version_actual is REJECTED."
echo "    Command that closes it: run the launch above against a QEMU built from tag v11.1.1"
echo "    (peeled commit c3d48b7d1e89604920e5b81b91140c2ad39a1943)."

echo ""
echo "=== P3-M08 REVIEWER-CHECK COMPLETE: ALL STAGES PASSED ==="
