#!/usr/bin/env python3
"""Build an opaque candidate.layer assignment input (REVIEWER-ONLY).

Generic builder: every record is supplied on the command line, so this
script embeds no assessment-specific file names, values, or defect lists.
Records are sorted by path and compressed deterministically (gzip mtime 0),
so rebuilding with the same arguments is byte-identical and causes no
repository churn.

Usage:
  make_candidate_layer.py --out <candidate.layer>
      [--file PATH:MODE:BASE64 ...] [--symlink PATH:TARGET ...]
      [--whiteout PATH ...]

MODE is an octal file mode (only 644 or 755 are representable).
BASE64 is the base64 encoding of the exact replacement file bytes.
"""

import argparse
import base64
import gzip
import struct
import sys

MAGIC = b"M03L"
VERSION = 0x01

T_FILE = 0x46
T_SYMLINK = 0x53
T_WHITEOUT = 0x57

MAX_RECORDS = 16


def _parse_file(spec):
    path, _, rest = spec.partition(":")
    mode_s, _, b64 = rest.partition(":")
    if not path or not mode_s or not b64:
        raise ValueError("malformed --file record (want PATH:MODE:BASE64)")
    try:
        mode = int(mode_s, 8)
    except ValueError:
        raise ValueError("bad mode in --file record: %r" % mode_s)
    try:
        content = base64.b64decode(b64, validate=True)
    except (ValueError, base64.binascii.Error):
        raise ValueError("bad base64 in --file record for %r" % path)
    return (path, T_FILE, (mode, content))


def _parse_symlink(spec):
    path, _, target = spec.partition(":")
    if not path or not target:
        raise ValueError("malformed --symlink record (want PATH:TARGET)")
    return (path, T_SYMLINK, target)


def _parse_whiteout(spec):
    if not spec:
        raise ValueError("malformed --whiteout record (want PATH)")
    return (spec, T_WHITEOUT, None)


def main(argv):
    ap = argparse.ArgumentParser(description="Build an opaque candidate.layer (reviewer-only)")
    ap.add_argument("--out", required=True)
    ap.add_argument("--file", action="append", default=[])
    ap.add_argument("--symlink", action="append", default=[])
    ap.add_argument("--whiteout", action="append", default=[])
    args = ap.parse_args(argv)

    records = []
    for spec in args.file:
        records.append(_parse_file(spec))
    for spec in args.symlink:
        records.append(_parse_symlink(spec))
    for spec in args.whiteout:
        records.append(_parse_whiteout(spec))
    if not records or len(records) > MAX_RECORDS:
        ap.error("record count must be 1..%d" % MAX_RECORDS)
    paths = [p for p, _, _ in records]
    if len(set(paths)) != len(paths):
        ap.error("duplicate paths in layer records")

    records.sort(key=lambda r: r[0].encode("utf-8"))
    buf = bytearray()
    buf += MAGIC
    buf += bytes((VERSION,))
    buf += struct.pack(">H", len(records))
    for path, rtype, payload in records:
        pb = path.encode("utf-8")
        buf += bytes((rtype,))
        buf += struct.pack(">H", len(pb))
        buf += pb
        if rtype == T_FILE:
            mode, content = payload
            buf += struct.pack(">H", mode)
            buf += struct.pack(">L", len(content))
            buf += content
        elif rtype == T_SYMLINK:
            tb = payload.encode("utf-8")
            buf += struct.pack(">H", len(tb))
            buf += tb
        elif rtype == T_WHITEOUT:
            pass
    blob = gzip.compress(bytes(buf), compresslevel=9, mtime=0)
    with open(args.out, "wb") as fh:
        fh.write(blob)
    import hashlib
    print("layer: %s (%d bytes, sha256 %s)" % (args.out, len(blob), hashlib.sha256(blob).hexdigest()))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
