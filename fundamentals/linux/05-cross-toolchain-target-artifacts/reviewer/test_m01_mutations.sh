#!/bin/bash
set -euo pipefail

# Reviewer Negative Control Mutation Suite for P3-M01
# Enforces: PREP/BUILD PASS / VALIDATOR EXECUTION PASS / INTENDED REJECT PASS
# Invokes actual production validators, not disconnected ad-hoc assertions.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M01_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M01_ROOT"

CROSS_COMPILE=${CROSS_COMPILE:-arm-none-linux-gnueabihf-}
if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    echo "ERROR: Cross compiler '${CROSS_COMPILE}gcc' not found in PATH." >&2
    echo "For Ubuntu/Debian distro toolchain, pass explicitly: CROSS_COMPILE=arm-linux-gnueabihf- $0" >&2
    exit 1
fi

HOST_CC=${HOST_CC:-gcc}
MUT_DIR="reviewer/mutations"
mkdir -p "$MUT_DIR"

# Ensure reference audit tool is compiled
AUDIT_TOOL="reviewer/reference/audit_tool_reference"
"$HOST_CC" -Wall -Wextra -O2 "reviewer/reference/audit_tool_reference.c" -o "$AUDIT_TOOL"

echo "=================================================================="
echo "=== Running P3-M01 Production-Validator Negative Control Suite ==="
echo "=================================================================="

TOTAL_MUTATIONS=4
PASSED_MUTATIONS=0

run_mutation() {
    local mut_id="$1"
    local desc="$2"
    local prep_cmd="$3"
    local val_cmd="$4"
    local expect_reject_pattern="$5"
    local expect_exit_code="$6"

    echo "------------------------------------------------------------------"
    echo "Testing Mutation ${mut_id}: ${desc}"

    # 1. PREP / BUILD
    if ! eval "$prep_cmd" >/dev/null 2>&1; then
        echo "[MUTATION ${mut_id} FAIL] Build/Prep stage failed!"
        return 1
    fi
    local prep_status="PASS"

    # 2. VALIDATOR EXECUTION
    local val_output=""
    local val_exit=0
    set +e
    val_output=$(eval "$val_cmd" 2>&1)
    val_exit=$?
    set -e

    # Check that validator executed without crash (SIGSEGV/SIGBUS/syntax error)
    if [ "$val_exit" -ge 128 ]; then
        echo "[MUTATION ${mut_id} FAIL] Validator crashed with signal $((val_exit - 128))!"
        echo "$val_output"
        return 1
    fi
    local val_status="PASS"

    # 3. INTENDED SEMANTIC REJECT
    if [ "$val_exit" -ne "$expect_exit_code" ]; then
        echo "[MUTATION ${mut_id} FAIL] Expected validator exit code ${expect_exit_code}, got ${val_exit}!"
        echo "Output was:"
        echo "$val_output"
        return 1
    fi

    if ! echo "$val_output" | grep -Eq "$expect_reject_pattern"; then
        echo "[MUTATION ${mut_id} FAIL] Validator output did not match expected reject pattern: ${expect_reject_pattern}"
        echo "Output was:"
        echo "$val_output"
        return 1
    fi
    local reject_status="PASS"

    echo "Status: MUTATION BUILD/PREP ${prep_status} / VALIDATOR EXECUTION ${val_status} / INTENDED REJECT ${reject_status}"
    echo "[PASS] Mutation ${mut_id} successfully rejected by production validator"
    PASSED_MUTATIONS=$((PASSED_MUTATIONS + 1))
    return 0
}

# Mutation 1: Host binary fed into F01 diagnostic oracle (diagnose_f01.sh)
run_mutation \
    1 \
    "Host x86-64 binary fed into F01 architecture oracle" \
    "echo 'int main(void){return 0;}' | $HOST_CC -x c - -O2 -o $MUT_DIR/mut1_host" \
    "bash faults/F01-wrong-architecture/diagnose_f01.sh $MUT_DIR/mut1_host" \
    "Architecture mismatch! Expected ARM target" \
    1

# Mutation 2: Missing dynamic loader rootfs fed into F02 oracle (diagnose_f02.sh)
run_mutation \
    2 \
    "Target dynamic binary with missing dynamic interpreter in rootfs" \
    "mkdir -p $MUT_DIR/mut2_rootfs/bin $MUT_DIR/mut2_rootfs/lib && echo 'int main(void){return 0;}' | ${CROSS_COMPILE}gcc -x c - -O2 -o $MUT_DIR/mut2_rootfs/bin/app_dynamic" \
    "bash faults/F02-missing-loader/diagnose_f02.sh $MUT_DIR/mut2_rootfs" \
    "Rootfs lacks the requested interpreter" \
    1

# Mutation 3: Non-ELF artifact fed into ELF audit classifier
run_mutation \
    3 \
    "Plain text shell script / non-ELF artifact fed into audit tool" \
    "printf '#!/bin/sh\n# A non-ELF shell script that exceeds fifty-two bytes in size for magic audit\necho hello\n' > $MUT_DIR/mut3_script.sh" \
    "./$AUDIT_TOOL $MUT_DIR/mut3_script.sh" \
    "CLASSIFICATION: NOT_ELF" \
    0

# Mutation 4: Static ARM binary with decoy interpreter string in .rodata
run_mutation \
    4 \
    "Static ARM binary with decoy ld-linux string in .rodata fed into audit classifier" \
    "echo 'const char *p = \"/lib/ld-linux-armhf.so.3\"; int main(void){return (long)p & 1;}' | ${CROSS_COMPILE}gcc -static -x c - -O2 -o $MUT_DIR/mut4_decoy_static" \
    "./$AUDIT_TOOL $MUT_DIR/mut4_decoy_static" \
    "CLASSIFICATION: TARGET_STATIC" \
    0

# Cleanup
rm -rf "$MUT_DIR"

echo "------------------------------------------------------------------"
if [ "$PASSED_MUTATIONS" -eq "$TOTAL_MUTATIONS" ]; then
    echo "=== ALL P3-M01 NEGATIVE CONTROL MUTATIONS REJECTED AS EXPECTED (${PASSED_MUTATIONS}/${TOTAL_MUTATIONS}) ==="
    exit 0
else
    echo "=== ERROR: Only ${PASSED_MUTATIONS}/${TOTAL_MUTATIONS} mutations passed! ==="
    exit 1
fi
