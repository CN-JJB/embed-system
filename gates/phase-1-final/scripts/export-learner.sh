#!/usr/bin/env bash
set -euo pipefail

# Deterministic Learner Package Exporter
# Usage: ./scripts/export-learner.sh <output-directory> [variant: b1|b2|b3]

if [ $# -lt 1 ]; then
    echo "Usage: $0 <output-directory> [variant: b1|b2|b3]"
    exit 1
fi

DEST_DIR="$1"
VARIANT="${2:-b1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ "$VARIANT" != "b1" ] && [ "$VARIANT" != "b2" ] && [ "$VARIANT" != "b3" ]; then
    echo "Error: Invalid variant '$VARIANT'. Must be b1, b2, or b3."
    exit 1
fi

echo "=== Exporting Phase 1 Final Gate Learner Package ==="
echo "Target Directory: $DEST_DIR"
echo "Selected Part B Variant: $VARIANT"

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

# 1. Global Documentation and Templates
cp "$ROOT_DIR/README.md" "$DEST_DIR/"
cp "$ROOT_DIR/RULES.md" "$DEST_DIR/"
cp "$ROOT_DIR/SCORE.md" "$DEST_DIR/"
cp "$ROOT_DIR/ENVIRONMENT.md" "$DEST_DIR/"
cp "$ROOT_DIR/SUBMISSION_TEMPLATE.md" "$DEST_DIR/"

# 2. Part A (Requirements & Fixtures only)
mkdir -p "$DEST_DIR/part-a/fixtures"
cp "$ROOT_DIR/part-a/README.md" "$DEST_DIR/part-a/"
cp "$ROOT_DIR/part-a/fixtures/"* "$DEST_DIR/part-a/fixtures/"

# 3. Part B (Selected Variant Only)
mkdir -p "$DEST_DIR/part-b/variants/$VARIANT"
cp "$ROOT_DIR/part-b/README.md" "$DEST_DIR/part-b/"
cp -r "$ROOT_DIR/part-b/variants/$VARIANT/"* "$DEST_DIR/part-b/variants/$VARIANT/"

# 4. Part C (Source and Build)
mkdir -p "$DEST_DIR/part-c/src"
cp "$ROOT_DIR/part-c/README.md" "$DEST_DIR/part-c/"
cp "$ROOT_DIR/part-c/Makefile" "$DEST_DIR/part-c/"
cp -r "$ROOT_DIR/part-c/src/"* "$DEST_DIR/part-c/src/"

# 5. Part D (Learner Fixture and Harness)
mkdir -p "$DEST_DIR/part-d"
cp "$ROOT_DIR/part-d/README.md" "$DEST_DIR/part-d/"
cp "$ROOT_DIR/part-d/Makefile" "$DEST_DIR/part-d/"
cp -r "$ROOT_DIR/part-d/src" "$DEST_DIR/part-d/"

# 6. Scripts (Utility scripts, excluding export script itself)
mkdir -p "$DEST_DIR/scripts"
cp "$ROOT_DIR/scripts/fd_audit.sh" "$DEST_DIR/scripts/"

# 7. Verification: Ensure ZERO reviewer answers or references are included
echo "--- Verifying Package Isolation ---"
if grep -rn "reviewer" "$DEST_DIR" 2>/dev/null; then
    echo "ERROR: Package contains references to reviewer files!"
    exit 2
fi

if [ -d "$DEST_DIR/reviewer" ]; then
    echo "ERROR: Reviewer directory leaked into learner package!"
    exit 2
fi

echo ">>> SUCCESS: Learner package exported cleanly to $DEST_DIR <<<"
