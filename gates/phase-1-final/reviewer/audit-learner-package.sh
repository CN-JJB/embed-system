#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
EXPORT_SCRIPT="$ROOT_DIR/scripts/export-learner.sh"
AUDIT_TMP_DIR=$(mktemp -d /tmp/final_gate_audit_XXXXXX)

trap 'rm -rf "$AUDIT_TMP_DIR"' EXIT

echo "=== Running Reviewer Learner Package Secrecy & Leakage Audit ==="

# Global denylist across entire exported package
GLOBAL_DENYLIST=(
    "reviewer"
    "ANSWER_KEY"
    "POSTMORTEM"
    "BUGGY"
    "FIXED"
    "heap-use-after-free"
    "leaked descriptors"
    "ephemeral batch"
    "reassigned without releasing"
    "Dropping lock"
    "Multi-field invariant violation"
    "close(p_fd[1])"
)

# Source-level ELF answer denylist (must not appear in part-c/src/ learner source code)
PART_C_SOURCE_DENYLIST=(
    ".rodata"
    ".data"
    ".bss"
    "COMMON"
    "relocation entry"
    "LOCAL symbol"
    "GLOBAL symbol"
)

for var in b1 b2 b3; do
    PKG_DIR="$AUDIT_TMP_DIR/$var"
    echo "--- Auditing Export Package for Variant $var ---"
    "$EXPORT_SCRIPT" "$PKG_DIR" "$var" >/dev/null

    # 1. Verify reviewer directory is strictly absent
    if [ -d "$PKG_DIR/reviewer" ]; then
        echo "FAIL [$var]: reviewer directory exists in learner package!"
        exit 1
    fi

    # 2. Check for global secret / diagnostic strings across entire package
    for pattern in "${GLOBAL_DENYLIST[@]}"; do
        MATCHES=$(grep -rnF "$pattern" "$PKG_DIR" 2>/dev/null || true)
        if [ -n "$MATCHES" ]; then
            echo "FAIL [$var]: Prohibited secret/diagnostic pattern '$pattern' found in learner package:"
            echo "$MATCHES"
            exit 1
        fi
    done

    # 3. Check for source-level ELF answer narrations in part-c/src
    for pattern in "${PART_C_SOURCE_DENYLIST[@]}"; do
        MATCHES=$(grep -rnF "$pattern" "$PKG_DIR/part-c/src" 2>/dev/null || true)
        if [ -n "$MATCHES" ]; then
            echo "FAIL [$var]: Prohibited ELF answer narration '$pattern' found in part-c/src:"
            echo "$MATCHES"
            exit 1
        fi
    done

    # 4. Check for commented-out C repair lines (e.g. /* ...close(...) */, /* ...free(...) */)
    COMMENTED_REPAIRS=$(grep -rnE '/\*.*(close|free|join|mutex|pthread_).*\*/' "$PKG_DIR/part-b" "$PKG_DIR/part-c" "$PKG_DIR/part-d" 2>/dev/null || true)
    if [ -n "$COMMENTED_REPAIRS" ]; then
        echo "FAIL [$var]: Commented-out repair line found in learner package:"
        echo "$COMMENTED_REPAIRS"
        exit 1
    fi

    # 5. Verify pipeline_stop in learner part-d does not contain consumer thread shutdown/join
    if grep -A 20 "int pipeline_stop" "$PKG_DIR/part-d/src/pipeline.c" | grep -F "consumer_thread"; then
        echo "FAIL [$var]: consumer_thread reference found inside pipeline_stop in learner package!"
        exit 1
    fi

    echo "PASS [$var]: Package is clean with zero answer leakage."
done

echo ">>> SUCCESS: All exported learner packages passed secrecy and leakage audit <<<"
