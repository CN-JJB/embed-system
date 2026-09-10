#!/bin/bash
set -euo pipefail

# Learner-safe provisioner for the P3-M03 Gate candidate (LEARNER-SAFE).
#
# Materializes a defective REAL BusyBox candidate tree from:
#   1. verified local BUSYBOX_STAGING (real BusyBox 1.36.1 install tree from
#      scripts/build_real_busybox.sh), via scripts/provision_real_busybox_tree.sh;
#   2. the small learner-visible assessment delta in
#      gate/fixtures/defective_overlay/ + gate/fixtures/defects.manifest.
#
# The full BusyBox binary + applet forest are NEVER tracked in Git; they are
# injected reproducibly from the learner/author's verified local staging.
# This script never calls the grading subtree and never reveals hidden
# reference logic: it only instantiates the candidate defect state the
# learner must diagnose.
#
# Usage: provision_gate_candidate.sh <out-rootfs-dir>
# Environment:
#   BUSYBOX_STAGING : verified staging (default /tmp/rootfs-busybox-staging)

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
FIXTURE_DIR="$M03_ROOT/gate/fixtures"
OVERLAY_DIR="$FIXTURE_DIR/defective_overlay"
MANIFEST="$FIXTURE_DIR/defects.manifest"

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

if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: assessment delta manifest missing: $MANIFEST" >&2
    exit 1
fi
if [ ! -d "$OVERLAY_DIR" ]; then
    echo "ERROR: assessment overlay missing: $OVERLAY_DIR" >&2
    exit 1
fi

# 1. Provision the verified real BusyBox base tree (validates staging identity).
bash "$M03_ROOT/scripts/provision_real_busybox_tree.sh" "$OUT" >/dev/null

# 2. Apply the small assessment delta described by defects.manifest.
#    Supported ops (one per line, '#' comments and blanks ignored):
#      overlay <rel>          copy overlay/<rel> over the tree
#      chmod <mode> <rel>     set octal mode on <rel>
#      symlink <rel> <target> replace <rel> with a symlink to <target>
#      remove <rel>           delete <rel> from the tree
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        ''|'#'*) continue ;;
    esac
    # shellcheck disable=SC2086
    set -- $line
    op="${1:-}"
    case "$op" in
        overlay)
            rel="${2:-}"
            [ -n "$rel" ] || { echo "ERROR: malformed overlay line: $line" >&2; exit 1; }
            case "$rel" in
                /*|*..*) echo "ERROR: refusing unsafe overlay path: $rel" >&2; exit 1 ;;
            esac
            src="$OVERLAY_DIR/$rel"
            dst="$OUT/$rel"
            [ -e "$src" ] || { echo "ERROR: overlay source missing: $src" >&2; exit 1; }
            mkdir -p "$(dirname "$dst")"
            cp -a "$src" "$dst"
            ;;
        chmod)
            mode="${2:-}"; rel="${3:-}"
            [ -n "$mode" ] && [ -n "$rel" ] || { echo "ERROR: malformed chmod line: $line" >&2; exit 1; }
            case "$rel" in
                /*|*..*) echo "ERROR: refusing unsafe chmod path: $rel" >&2; exit 1 ;;
            esac
            chmod "$mode" "$OUT/$rel"
            ;;
        symlink)
            rel="${2:-}"; target="${3:-}"
            [ -n "$rel" ] && [ -n "$target" ] || { echo "ERROR: malformed symlink line: $line" >&2; exit 1; }
            case "$rel" in
                /*|*..*) echo "ERROR: refusing unsafe symlink path: $rel" >&2; exit 1 ;;
            esac
            case "$target" in
                /*|*..*) echo "ERROR: refusing unsafe symlink target: $target" >&2; exit 1 ;;
            esac
            rm -f "$OUT/$rel"
            ln -sf "$target" "$OUT/$rel"
            ;;
        remove)
            rel="${2:-}"
            [ -n "$rel" ] || { echo "ERROR: malformed remove line: $line" >&2; exit 1; }
            case "$rel" in
                /*|*..*) echo "ERROR: refusing unsafe remove path: $rel" >&2; exit 1 ;;
            esac
            # Only assessment applet entries may be removed; never the real binary.
            case "$rel" in
                bin/*|sbin/*|usr/bin/*|usr/sbin/*) ;;
                *) echo "ERROR: remove op refused outside applet dirs: $rel" >&2; exit 1 ;;
            esac
            if [ "$rel" = "bin/busybox" ] || [ "$rel" = "usr/bin/busybox" ]; then
                echo "ERROR: refusing to remove the real BusyBox binary: $rel" >&2
                exit 1
            fi
            rm -f "$OUT/$rel"
            ;;
        *)
            echo "ERROR: unknown manifest op '$op' in: $line" >&2
            exit 1
            ;;
    esac
done < "$MANIFEST"

echo "[PASS] Gate candidate provisioned at: $OUT (verified staging + small assessment delta)"
