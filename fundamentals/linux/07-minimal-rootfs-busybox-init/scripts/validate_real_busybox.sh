#!/bin/bash
set -euo pipefail

# REAL BusyBox artifact validation for P3-M03 (IMPORT-SAFE / LEARNER-SAFE).
#
# Enforces that a submitted rootfs staging tree or packaged initramfs archive
# carries a REAL BusyBox multi-call binary as its multicall/init provider:
#
#   1. the multicall binary is a static ARM ELF (no PT_INTERP / DT_NEEDED);
#   2. it identifies itself as BusyBox (BusyBox banner + applet-table magic);
#   3. it physically implements the required applets (applet name strings);
#   4. it is NOT the synthetic pedagogical fixture (explicit banner check);
#   5. /sbin/init and the required /bin applets resolve to that binary and
#      resolve INSIDE the (unpacked) tree;
#   6. if a directory tree is supplied, the packaged archive's binary is
#      byte-identical to the staged binary (staging/archive divergence).
#
# Evidence class: STATIC artifact identity + archive metadata only. It never
# claims that BusyBox executed; runtime proof is produced by
# scripts/run_real_busybox_candidate.sh.
#
# Usage: validate_real_busybox.sh <rootfs-dir | archive.cpio.gz> [staged-rootfs-dir]

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

TARGET="${1:-}"
STAGED_DIR="${2:-}"
REQUIRED_APPLETS=(sh ls ps mount echo cat init)

if [ -z "$TARGET" ]; then
    echo "ERROR: rootfs directory or initramfs archive required." >&2
    exit 1
fi

WORK=$(mktemp -d /tmp/m03_bb_ident_XXXXXX)
trap 'rm -rf "$WORK"' EXIT

MODE="dir"
TREE="$TARGET"
if [ -f "$TARGET" ]; then
    MODE="archive"
    case "$TARGET" in
        *synthetic*)
            echo "REJECT: synthetic pedagogical fixture archive is not a real BusyBox submission: $TARGET" >&2
            exit 2
            ;;
    esac
    TREE="$WORK/unpacked"
    ARCHIVE_TREE="$TREE"
    mkdir -p "$TREE"
    # Fail closed on a corrupt stream: reading the whole archive into the CPIO
    # file surfaces gzip/trailing-data damage as a non-zero status.
    if ! zcat "$TARGET" > "$WORK/archive.cpio" 2>/dev/null; then
        echo "REJECT: packaged archive is not a readable gzip stream (corrupt/truncated): $TARGET" >&2
        exit 2
    fi
    # pycpio extraction is authoritative: it preserves modes and symlink
    # targets from the CPIO metadata (no umask influence), which the staged
    # vs packaged comparison below depends on.
    python3 "$M03_ROOT/scripts/pycpio.py" --extract "$WORK/archive.cpio" "$TREE"
fi

[ -d "$TREE" ] || { echo "REJECT: supplied staging tree not found: $TARGET" >&2; exit 2; }

FAILURES=0
fail() { echo "REJECT: $1" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "[PASS] $1"; }

# --- 1. Locate the multicall provider -------------------------------------
BUSYBOX=""
for candidate in "$TREE/bin/busybox" "$TREE/usr/bin/busybox"; do
    [ -f "$candidate" ] && BUSYBOX="$candidate" && break
done
if [ -z "$BUSYBOX" ]; then
    fail "no /bin/busybox present in the submission (a synthetic or otherwise renamed multicall binary cannot satisfy the scored contract)"
else
    pass "real BusyBox multi-call binary located: ${BUSYBOX#$TREE/}"
fi

if [ -n "$BUSYBOX" ]; then
    # --- 2. Static ARM ELF shape ------------------------------------------
    if bash "$M03_ROOT/scripts/audit_busybox_elf.sh" "$BUSYBOX" >/dev/null 2>&1; then
        pass "multicall binary is a static ARM ELF (no PT_INTERP, no DT_NEEDED)"
    else
        fail "multicall binary fails the static ARM ELF contract"
        bash "$M03_ROOT/scripts/audit_busybox_elf.sh" "$BUSYBOX" 2>&1 | tail -n 2 >&2 || true
    fi

    # --- 3. Real BusyBox identity ----------------------------------------
    # Read the strings dump ONCE into a variable: piping a large dump into
    # 'grep -q' closes the pipe early and races under 'set -o pipefail'.
    BB_STRINGS=$(strings -a "$BUSYBOX" 2>/dev/null || true)
    BB_TOKENS=$(strings -a -n 2 "$BUSYBOX" 2>/dev/null || true)

    if [[ "$BB_STRINGS" == *"SYNTHETIC PEDAGOGICAL FIXTURE"* ]]; then
        fail "multicall binary is the SYNTHETIC pedagogical fixture, not BusyBox"
    fi
    if [[ "$BB_STRINGS" != *"BusyBox v1.36.1"* ]]; then
        fail "multicall binary does not carry the real BusyBox v1.36.1 identity string"
    else
        pass "multicall binary carries the real BusyBox v1.36.1 identity string"
    fi
    # The upstream BusyBox banner/help text is emitted by every real build
    # (main.c / libbb). A hand-written lookalike does not carry it.
    if [[ "$BB_STRINGS" != *"BusyBox is a multi-call binary"* ]]; then
        fail "multicall binary lacks the upstream BusyBox multi-call banner"
    else
        pass "multicall binary carries the upstream BusyBox multi-call banner"
    fi
    # Real BusyBox embeds its applet-name table; a lookalike does not. The
    # exact set varies with configuration, so require broad coverage instead
    # of an exact count.
    APPLET_CANDIDATES=(init sh ash ls ps mount umount echo cat mdev blkid
                       route ifconfig udhcpc syslogd klogd switch_root
                       start-stop-daemon vi find grep sed awk tar gzip)
    APPLET_HITS=0
    for app in "${APPLET_CANDIDATES[@]}"; do
        if grep -qx -- "$app" <<<"$BB_TOKENS"; then
            APPLET_HITS=$((APPLET_HITS + 1))
        fi
    done
    if [ "$APPLET_HITS" -lt 18 ]; then
        fail "multicall binary exposes only $APPLET_HITS/${#APPLET_CANDIDATES[@]} expected BusyBox applet-table names; not a real BusyBox multi-call binary"
    else
        pass "multicall binary exposes a real BusyBox applet table ($APPLET_HITS/${#APPLET_CANDIDATES[@]} expected names)"
    fi
    # A real statically linked BusyBox image is a large multi-applet binary.
    BB_SIZE=$(stat -c '%s' "$BUSYBOX")
    if [ "$BB_SIZE" -lt 200000 ]; then
        fail "multicall binary is only $BB_SIZE bytes; too small to be a real BusyBox multi-call artifact"
    else
        pass "multicall binary size ($BB_SIZE bytes) is consistent with a real BusyBox build"
    fi

    # --- 4. Required applets are implemented by this binary ---------------
    for app in "${REQUIRED_APPLETS[@]}"; do
        if ! grep -qx -- "$app" <<<"$BB_TOKENS"; then
            fail "required applet '$app' is not implemented by the multicall binary"
        fi
    done
    pass "required applets implemented by the multicall binary: ${REQUIRED_APPLETS[*]}"

    # --- 5. init/applet resolution inside the tree ------------------------
    resolve_in_tree() {
        local link="$1" target
        target=$(readlink "$link" 2>/dev/null || echo "")
        [ -n "$target" ] || { echo ""; return; }
        case "$target" in
            /*) echo "$TREE$target" ;;
            *)  echo "$(cd "$(dirname "$link")" && pwd)/$target" ;;
        esac
    }
    for app in "${REQUIRED_APPLETS[@]}"; do
        local_path="$TREE/bin/$app"
        [ "$app" = "init" ] && local_path="$TREE/sbin/init"
        if [ ! -e "$local_path" ]; then
            fail "required applet entry $app missing at ${local_path#$TREE/}"
            continue
        fi
        if [ -L "$local_path" ]; then
            resolved=$(resolve_in_tree "$local_path")
            if [ ! -f "$resolved" ]; then
                fail "applet symlink ${local_path#$TREE/} does not resolve inside the submission"
            elif [ "$(readlink -f "$resolved")" != "$(readlink -f "$BUSYBOX")" ]; then
                fail "applet symlink ${local_path#$TREE/} does not resolve to the real BusyBox binary"
            fi
        elif [ "$(readlink -f "$local_path")" != "$(readlink -f "$BUSYBOX")" ]; then
            fail "applet entry ${local_path#$TREE/} is not the real BusyBox binary"
        fi
    done
    pass "all required applet entries resolve to the real BusyBox binary"

    # --- 6. /init must actively mount the kernel pseudo-filesystems --------
    # (CONFIG_DEVTMPFS_MOUNT does not automount devtmpfs for initramfs boot,
    # so the rdinit=/init path must mount proc/sys/dev itself.)
    if [ -f "$TREE/init" ]; then
        INIT_ACTIVE=$(grep -v '^[[:space:]]*#' "$TREE/init" | grep -vE '^[[:space:]]*echo([[:space:]]|$)' || true)
        init_mount_ok() {
            local fstype="$1" target="$2"
            echo "$INIT_ACTIVE" | grep -Eq "^[[:space:]]*mount.*-t[[:space:]]+$fstype[[:space:]]+[^[:space:]]+[[:space:]]+$target([[:space:]]|$|;)"
        }
        init_mount_ok proc /proc \
            || fail "/init lacks an ACTIVE 'mount -t proc ... /proc' (documented-but-not-executed is not enough)"
        init_mount_ok sysfs /sys \
            || fail "/init lacks an ACTIVE 'mount -t sysfs ... /sys'"
        pass "/init actively mounts proc/sys (comment/echo decoys do not count)"
    fi

    # --- 7. Packaged archive must match the staged tree -------------------
    if [ "$MODE" = "archive" ] && [ -n "$STAGED_DIR" ] && [ -d "$STAGED_DIR" ]; then
        STAGED_BB="$STAGED_DIR/bin/busybox"
        if [ ! -f "$STAGED_BB" ]; then
            fail "staged tree has no bin/busybox to compare against the archive"
        else
            ARCH_SHA=$(sha256sum "$BUSYBOX" | awk '{print $1}')
            STAGE_SHA=$(sha256sum "$STAGED_BB" | awk '{print $1}')
            if [ "$ARCH_SHA" != "$STAGE_SHA" ]; then
                fail "packaged archive binary differs from the staged binary (staging/archive divergence)"
            else
                pass "packaged archive BusyBox is byte-identical to the staged BusyBox"
            fi
        fi

        # The packaged tree must be equivalent to the staging tree, not merely
        # to contain a good binary: a submission whose staged tree is correct
        # but whose PACKAGED archive was produced from a different/defective
        # tree (or damaged afterwards) must be rejected.
        DIVERGENCE=0
        DIVERGENCE_DETAIL=""
        STAGED_RELS=$(mktemp /tmp/m03_rels_XXXXXX)
        ( cd "$STAGED_DIR" && find . -mindepth 1 | LC_ALL=C sort ) > "$STAGED_RELS"
        while IFS= read -r rel; do
            rel="${rel#./}"
            [ -z "$rel" ] && continue
            # devnodes.manifest is a packaging CONTROL file: pycpio consumes it
            # to synthesize device entries and deliberately never packages it.
            [ "$rel" = "devnodes.manifest" ] && continue
            s_path="$STAGED_DIR/$rel"
            a_path="$ARCHIVE_TREE/$rel"
            if [ ! -e "$s_path" ] && [ ! -L "$s_path" ]; then
                continue
            fi
            if [ ! -e "$a_path" ] && [ ! -L "$a_path" ]; then
                DIVERGENCE=$((DIVERGENCE + 1))
                DIVERGENCE_DETAIL="$rel missing from packaged archive"
                break
            fi
            s_mode=$(stat -c '%f' "$s_path" 2>/dev/null || echo "")
            a_mode=$(stat -c '%f' "$a_path" 2>/dev/null || echo "")
            if [ "$s_mode" != "$a_mode" ]; then
                DIVERGENCE=$((DIVERGENCE + 1))
                DIVERGENCE_DETAIL="$rel mode differs (staged $s_mode vs packaged $a_mode)"
                break
            fi
            if [ -L "$s_path" ]; then
                if [ "$(readlink "$s_path")" != "$(readlink "$a_path")" ]; then
                    DIVERGENCE=$((DIVERGENCE + 1))
                    DIVERGENCE_DETAIL="$rel symlink target differs"
                    break
                fi
            elif [ -f "$s_path" ]; then
                s_sha=$(sha256sum "$s_path" | awk '{print $1}')
                a_sha=$(sha256sum "$a_path" | awk '{print $1}')
                if [ "$s_sha" != "$a_sha" ]; then
                    DIVERGENCE=$((DIVERGENCE + 1))
                    DIVERGENCE_DETAIL="$rel content differs"
                    break
                fi
            fi
        done < "$STAGED_RELS"
        rm -f "$STAGED_RELS"

        if [ "$DIVERGENCE" -ne 0 ]; then
            fail "packaged archive diverges from the staged tree: $DIVERGENCE_DETAIL"
        else
            pass "packaged archive entries (modes, symlink targets, contents) match the staged tree"
        fi
    fi
fi

echo "------------------------------------------------------------------"
if [ "$FAILURES" -eq 0 ]; then
    echo "[PASS] Real BusyBox artifact identity VERIFIED (static): $TARGET"
    exit 0
fi
echo "REJECT: $FAILURES real-BusyBox identity mismatch(es) in: $TARGET" >&2
exit 2
