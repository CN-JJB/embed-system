#!/usr/bin/env python3
"""Generate a SYNTHETIC Buildroot output-tree sample (P3-M06 teaching fixture).

WHAT THIS IS
------------
A hand-built, fully deterministic stand-in for the parts of a Buildroot
``output/`` tree that the audit tooling inspects.  It lets Labs 6.4/6.5 and the
assessment validators be exercised on any host, without a multi-hour Buildroot
build.

WHAT THIS IS NOT
----------------
It is **not** a Buildroot build.  No Buildroot source was compiled, no
toolchain was built, and no real kernel image is present.  It is a *shape*
fixture for audit tooling.  Every generated tree therefore carries a
``SYNTHETIC`` sentinel file and this disclaimer in its README.  Never present
its contents as build evidence.

The generated tree is byte-reproducible: file modes and mtimes are fixed, and
the cpio archive is written with fixed inode numbers, so the same inputs always
produce the same archive.

Usage
-----
    python3 scripts/make_sample_output_tree.py --out fixtures/output-tree-sample
    python3 scripts/make_sample_output_tree.py --out /tmp/stale --mode stale
"""

from __future__ import annotations

import argparse
import gzip
import io
import os
import shutil
import stat
import struct
import sys
from typing import Dict, List, Optional, Tuple

#: Fixed timestamps so the generated archive is reproducible.
FIXED_MTIME = 1757000000

BASE_ROOTFS: Dict[str, Tuple[int, bytes]] = {
    "init": (0o755, b"#!/bin/sh\nexec /bin/sh\n"),
    "bin/busybox": (0o755, b"SYNTHETIC-BUSYBOX-MULTICALL-STANDIN\n"),
    "bin/sh": (0o755, b"SYNTHETIC-SHELL-STANDIN\n"),
    "etc/inittab": (0o644, b"::sysinit:/etc/init.d/rcS\n::askfirst:-/bin/sh\n"),
    "etc/init.d/rcS": (0o755, b"#!/bin/sh\nmount -t proc proc /proc\nmount -t sysfs sysfs /sys\n"),
    "etc/os-release": (0o644, b'NAME=Buildroot\nID=buildroot\nVERSION="2026.05.2"\n'),
    "usr/bin/README": (0o644, b"SYNTHETIC ROOTFS SAMPLE - NOT A BUILDROOT BUILD\n"),
}


def cpio_newc(entries: Dict[str, Tuple[int, bytes]]) -> bytes:
    """Write a deterministic newc cpio archive."""

    def header(name: str, mode: int, size: int, ino: int) -> bytes:
        # cpio stores the full st_mode: the file-type bits matter, because a
        # reader decides whether an entry is a regular file from them.
        fields = [ino, mode | stat.S_IFREG, 0, 0, 1, FIXED_MTIME, size, 0, 0, 0, 0,
                  len(name) + 1, 0]
        return b"070701" + b"".join(b"%08X" % f for f in fields)

    out = bytearray()
    ino = 1
    for name in sorted(entries):
        mode, content = entries[name]
        full = ("." + "/" + name).encode("utf-8") + b"\x00"
        out += header("./" + name, mode, len(content), ino)
        out += full
        out += b"\x00" * ((4 - (len(out) % 4)) % 4)
        out += content
        out += b"\x00" * ((4 - (len(out) % 4)) % 4)
        ino += 1
    trailer = b"TRAILER!!!\x00"
    out += header("TRAILER!!!", 0, 0, 0)
    out += trailer
    out += b"\x00" * ((4 - (len(out) % 4)) % 4)
    return bytes(out)


def overlay_entries(overlay_dir: str) -> Dict[str, Tuple[int, bytes]]:
    entries: Dict[str, Tuple[int, bytes]] = {}
    for dirpath, dirnames, filenames in os.walk(overlay_dir):
        dirnames[:] = [d for d in dirnames if d not in (".git", ".svn", ".hg")]
        for name in filenames:
            if name.endswith("~") or name == ".empty":
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, overlay_dir).replace(os.sep, "/")
            mode = 0o755 if os.access(full, os.X_OK) else 0o644
            with open(full, "rb") as handle:
                entries[rel] = (mode, handle.read())
    return entries


def write_tree(root: str, entries: Dict[str, Tuple[int, bytes]]) -> None:
    # Remove any previous tree so that switching --mode cannot leave stale files
    # behind.  Failure to remove is tolerated: every file we manage is written
    # unconditionally below, so the result is still deterministic.  (Some
    # sandboxed hosts refuse recursive deletes; that is not a correctness
    # problem for this generator.)
    if os.path.isdir(root):
        try:
            shutil.rmtree(root)
        except OSError as exc:
            print(f"[NOTE] could not remove the previous tree at {root}: {exc}", file=sys.stderr)
    for rel, (mode, content) in sorted(entries.items()):
        full = os.path.join(root, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "wb") as handle:
            handle.write(content)
        os.chmod(full, mode)


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Generate the P3-M06 synthetic output-tree sample")
    parser.add_argument("--out", required=True, help="destination directory")
    parser.add_argument("--overlay", help="overlay source tree "
                                          "(default: fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay)")
    parser.add_argument("--mode", choices=("healthy", "stale"), default="healthy",
                        help="'healthy' propagates the overlay into the image; 'stale' updates "
                             "output/target but leaves the packaged image untouched")
    args = parser.parse_args(argv)

    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    overlay_dir = args.overlay or os.path.join(
        here, "fixtures", "br2-external", "board", "qemu-virt-a7", "rootfs-overlay")

    if not os.path.isdir(overlay_dir):
        print(f"ERROR: overlay source not found: {overlay_dir}", file=sys.stderr)
        return 2

    out = os.path.abspath(args.out)
    target_dir = os.path.join(out, "target")
    images_dir = os.path.join(out, "images")
    build_dir = os.path.join(out, "build", "appliance-diag-1.0")

    overlay = overlay_entries(overlay_dir)

    # --- output/target: base rootfs + overlay (the staging view) -------------
    target_entries = dict(BASE_ROOTFS)
    target_entries.update(overlay)
    write_tree(target_dir, target_entries)

    # --- output/build: package work area with build stamps -------------------
    os.makedirs(build_dir, exist_ok=True)
    for stamp in (".stamp_configured", ".stamp_built", ".stamp_target_installed"):
        path = os.path.join(build_dir, stamp)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(f"SYNTHETIC build stamp: {stamp}\n")
        os.utime(path, (FIXED_MTIME, FIXED_MTIME))
    with open(os.path.join(build_dir, "appliance-diag.c"), "w", encoding="utf-8") as handle:
        handle.write("/* synthetic package source stand-in */\nint main(void){return 0;}\n")
    os.utime(os.path.join(build_dir, "appliance-diag.c"), (FIXED_MTIME, FIXED_MTIME))

    # --- output/images: the final deployable artifact ------------------------
    os.makedirs(images_dir, exist_ok=True)
    image_entries = dict(BASE_ROOTFS)
    if args.mode == "healthy":
        image_entries.update(overlay)
    else:
        # Stale image: the packaged image keeps the *previous* release marker
        # and does not contain the new overlay file at all.
        image_entries["etc/appliance-release"] = (
            0o644, b"EMBED-SYSTEM P3-M06 appliance release 0.9\n")
    archive = cpio_newc(image_entries)
    with open(os.path.join(images_dir, "rootfs.cpio.gz"), "wb") as handle:
        handle.write(gzip.compress(archive, mtime=0))

    # --- sentinels and provenance -------------------------------------------
    with open(os.path.join(out, "SYNTHETIC"), "w", encoding="utf-8") as handle:
        handle.write("This directory is a SYNTHETIC output-tree sample.\n"
                     "It was NOT produced by Buildroot and contains no real artifacts.\n")
    with open(os.path.join(out, "README.md"), "w", encoding="utf-8") as handle:
        handle.write(
            "# SYNTHETIC Buildroot output-tree sample\n\n"
            "Generated by `scripts/make_sample_output_tree.py`. **This is not a Buildroot "
            "build.** No Buildroot source was compiled, no toolchain exists here, and "
            "`images/rootfs.cpio.gz` is a synthetic archive containing stand-in files.\n\n"
            f"Mode: `{args.mode}`\n\n"
            "| Path | Class of artifact |\n|---|---|\n"
            "| `build/appliance-diag-1.0/` | package build work area, carrying `.stamp_*` state |\n"
            "| `target/` | staging view of the target filesystem |\n"
            "| `images/` | final deployable artifacts |\n\n"
            "Use it to exercise `scripts/audit_output_tree.py`; never cite it as build "
            "or runtime evidence.\n")

    print(f"[OK] synthetic output tree ({args.mode}) written to {out}")
    print(f"     overlay source : {overlay_dir} ({len(overlay)} file(s))")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
