#!/usr/bin/env python3
"""Materialise a well-formed newc cpio.gz sample image for P3-M08.

Used by scripts/verify_project.sh to produce a synthetic final image from
overlay/ (plus a couple of guest-side placeholder files) so the final-image
audit path can be exercised without a real Buildroot build.

The newc archive writer here is deliberately self-contained: it does NOT
depend on the fundamentals/ tree nor on scripts/audit_final_image.py.  It is
the single source of truth for sample-image materialisation in this project.

newc header layout (13 x 8-hex fields after the 6-byte "070701" magic):

    c_ino, c_mode, c_uid, c_gid, c_nlink, c_mtime, c_filesize,
    c_devmajor, c_devminor, c_rdevmajor, c_rdevminor, c_namesize, c_check

BUG #1 regression: an earlier inline generator wrote len(name) into
c_rdevminor and 0 into c_namesize, producing a corrupt archive that
scripts/audit_final_image.py correctly rejected ("unexpected cpio magic").
``--self-test`` pins the field layout explicitly and round-trips every entry
through an independent reader so that regression cannot silently return.

Exit status: 0 OK / 1 SELF-TEST-FAIL / 2 ERROR.
"""
from __future__ import annotations

import argparse
import gzip
import os
import sys
import tempfile
from typing import Dict, Optional

MAGIC_NEWC = "070701"
TRAILER_NAME = "TRAILER!!!"
GUEST_EXTRAS = {
    "usr/bin/appliance-diag": b"ELF-placeholder\n",
    "etc/init.d/rcS": b"#!/bin/sh\nmount -t proc none /proc\nmount -t sysfs none /sys\n",
}

# newc header field order (zero-based field index), per
# Documentation/early-userspace/buffer-format.rst / gen_init_cpio.c.
#   index 10 -> c_rdevminor, index 11 -> c_namesize.
_FIELD_NAMES = ("c_ino", "c_mode", "c_uid", "c_gid", "c_nlink", "c_mtime",
                "c_filesize", "c_devmajor", "c_devminor", "c_rdevmajor",
                "c_rdevminor", "c_namesize", "c_check")


def newc_header(namesize: int, filesize: int, mode: int, ino: int,
                nlink: int = 1, mtime: int = 0) -> bytes:
    """Build the 110-byte newc header with the field order fixed explicitly."""
    fields = (ino, mode, 0, 0, nlink, mtime, filesize,
              0, 0, 0, 0, namesize, 0)
    return (MAGIC_NEWC + ("%08x" * 13) % fields).encode("ascii")


def newc_entry(name: str, body: bytes, ino: int) -> bytes:
    """One regular-file newc entry (name + data, both 4-byte aligned)."""
    n = name.encode("utf-8") + b"\x00"
    chunk = newc_header(len(n), len(body), 0o100644, ino) + n
    chunk += b"\x00" * (-len(chunk) % 4)
    chunk += body
    chunk += b"\x00" * (-len(body) % 4)
    return chunk


def newc_trailer() -> bytes:
    """Terminating TRAILER!!! entry (ino 0, filesize 0)."""
    n = TRAILER_NAME.encode("utf-8") + b"\x00"
    chunk = newc_header(len(n), 0, 0, 0) + n
    chunk += b"\x00" * (-len(chunk) % 4)
    return chunk


def collect_overlay(overlay: str) -> Dict[str, bytes]:
    out: Dict[str, bytes] = {}
    for dirpath, dirnames, filenames in os.walk(overlay):
        dirnames[:] = [d for d in dirnames if d not in (".git", ".svn", ".hg")]
        for name in filenames:
            if name.endswith("~") or name == ".empty":
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, overlay).replace(os.sep, "/")
            with open(full, "rb") as handle:
                out[rel] = handle.read()
    return out


def merged_files(overlay: str, extras: Optional[Dict[str, bytes]] = None) -> Dict[str, bytes]:
    files = collect_overlay(overlay)
    for rel, body in (extras if extras is not None else GUEST_EXTRAS).items():
        files.setdefault(rel, body)
    return files


def write_image(overlay: str, out: str, extras: Optional[Dict[str, bytes]] = None) -> int:
    files = merged_files(overlay, extras)
    blob = b""
    ino = 1
    for rel in sorted(files):
        blob += newc_entry(rel, files[rel], ino)
        ino += 1
    blob += newc_trailer()
    outdir = os.path.dirname(os.path.abspath(out)) or "."
    os.makedirs(outdir, exist_ok=True)
    with gzip.open(out, "wb") as handle:
        handle.write(blob)
    print(f"materialised {len(files)} file(s) -> {out}")
    return 0


def _independent_read(data: bytes) -> Dict[str, bytes]:
    """Minimal independent newc reader (mirrors the audit tool's expectations).

    Raises AssertionError on any structural problem. Deliberately NOT shared
    with scripts/audit_final_image.py so the self-test cannot tautologically
    agree with a co-broken writer.
    """
    out: Dict[str, bytes] = {}
    pos = 0
    seen_trailer = False
    while True:
        assert pos + 110 <= len(data), "archive ends inside a header"
        assert data[pos:pos + 6] == b"070701", \
            f"unexpected cpio magic {data[pos:pos+6]!r} at offset {pos}"
        fields = [int(data[pos + 6 + i * 8:pos + 14 + i * 8], 16) for i in range(13)]
        mode, filesize, namesize = fields[1], fields[6], fields[11]
        # The exact regression pin: namesize lives at index 11, rdevminor at 10.
        assert fields[10] == 0, \
            f"c_rdevminor must be 0, got {fields[10]} (namesize misplaced in header)"
        pos += 110
        assert pos + namesize <= len(data), "name extends past end of archive"
        raw_name = data[pos:pos + namesize]
        assert raw_name.endswith(b"\x00"), "name is not NUL-terminated"
        assert len(raw_name) == namesize, "namesize does not match raw name length"
        name = raw_name.split(b"\x00", 1)[0].decode("utf-8", errors="replace")
        pos += namesize
        pos = (pos + 3) & ~3
        assert pos + filesize <= len(data), f"entry {name!r} extends past end of archive"
        content = data[pos:pos + filesize]
        pos += filesize
        pos = (pos + 3) & ~3
        if name == TRAILER_NAME:
            seen_trailer = True
            return out
        out[name] = content


def self_test() -> int:
    # Names chosen to exercise every 4-byte padding residue of the name field.
    cases = {
        "etc/appliance-release": b"EMBED-SYSTEM P3-M08 appliance release 1.0\n",
        "etc/init.d/S99appliance-diag": b"#!/bin/sh\n",
        "usr/bin/appliance-diag": b"ELF-placeholder\n",
        "pad0": b"x",          # name len 4 -> 0 padding
        "pad1": b"12",         # name len 5 -> 3 padding
        "pad2": b"123",        # name len 6 -> 2 padding
        "pad3": b"1234",       # name len 7 -> 1 padding
    }
    blob = b""
    ino = 1
    expected: Dict[str, bytes] = {}
    for rel in sorted(cases):
        blob += newc_entry(rel, cases[rel], ino)
        expected[rel] = cases[rel]
        ino += 1
    blob += newc_trailer()

    # Explicit header field-layout pin (the BUG #1 root cause).
    first = blob[:110]
    f = [int(first[6 + i * 8:14 + i * 8], 16) for i in range(13)]
    first_name = sorted(cases)[0]
    assert f[10] == 0, f"c_rdevminor must be 0, got {f[10]} (namesize misplaced)"
    assert f[11] == len(first_name) + 1, \
        f"c_namesize {f[11]} != {len(first_name) + 1} for {first_name!r}"

    got = _independent_read(blob)
    assert got == expected, f"round-trip mismatch: {sorted(set(got) ^ set(expected))}"

    # Real gzip file round-trip.
    fd, path = tempfile.mkstemp(suffix=".cpio.gz")
    os.close(fd)
    try:
        with gzip.open(path, "wb") as handle:
            handle.write(blob)
        with gzip.open(path, "rb") as handle:
            got2 = _independent_read(handle.read())
        assert got2 == expected, "gzip round-trip mismatch"
    finally:
        os.unlink(path)

    print("[PASS] cpio materialisation self-test: field layout + plain/gzip round-trip")
    return 0


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser(description="P3-M08 sample-image materialiser (newc cpio.gz)")
    parser.add_argument("--overlay", default="overlay", help="overlay source tree")
    parser.add_argument("--out", default="", help="output rootfs.cpio.gz path")
    parser.add_argument("--self-test", action="store_true",
                        help="run the newc field-layout + round-trip regression and exit")
    args = parser.parse_args(argv)

    if args.self_test:
        try:
            return self_test()
        except AssertionError as exc:
            print(f"SELF-TEST-FAIL: {exc}", file=sys.stderr)
            return 1
    if not args.out:
        print("ERROR: --out FILE is required (or use --self-test)", file=sys.stderr)
        return 2
    if not os.path.isdir(args.overlay):
        print(f"ERROR: overlay tree not found: {args.overlay}", file=sys.stderr)
        return 2
    return write_image(args.overlay, args.out)


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
