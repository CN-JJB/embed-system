#!/usr/bin/env python3
"""Generic opaque assignment-layer applicator (LEARNER-SAFE).

Applies a small opaque ``candidate.layer`` assignment input on top of an
already-provisioned candidate rootfs tree. The layer carries file
replacements (with executable-mode state), symlink replacements, and
deletion markers. It never carries a BusyBox executable or an applet
forest: those always come from the verified local staging.

The applicator is fully generic: it takes the layer path and the
destination tree as arguments and contains no assessment-specific file
names, values, or defect lists. It prints nothing about the layer
contents; success is silent.

Layer format (inner payload is gzip-compressed, deterministic encoding):
  magic ``M03L``, version byte ``0x01``, u16-BE record count N (1..16),
  then N records sorted by path, then end-of-stream (no trailing bytes).
  Record: u8 type, u16-BE path length, path bytes (UTF-8), then by type:
    0x46 file:      u16 mode (0o644 or 0o755), u32-BE length (1..4096),
                    content bytes (no NUL).
    0x53 symlink:   u16-BE target length (1..256), target bytes: a bare
                    relative name (no ``/``, no ``..``, no NUL).
    0x57 deletion:  no payload; path must live under an applet directory.

Fail-closed contract, exit codes:
  0  applied cleanly (two-phase: fully parsed and validated first).
  2  semantic REJECT: absolute path, ``..``/``.`` traversal, write outside
     the candidate root, duplicate/conflicting records for one path,
     unsupported entry type, disallowed mode, illegal symlink target,
     oversize field, write to the protected BusyBox payload, deletion
     outside applet directories.
  1  infrastructure/materialization failure: missing layer, oversize layer,
     bad gzip envelope, bad magic/version, truncation, trailing garbage,
     empty layer, destination errors, deletion target absent.

Usage: apply_candidate_layer.py <candidate.layer> <candidate-rootfs-dir>
"""

import gzip
import os
import struct
import sys

MAGIC = b"M03L"
VERSION = 0x01

T_FILE = 0x46
T_SYMLINK = 0x53
T_WHITEOUT = 0x57

MAX_RECORDS = 16
MAX_PATH_LEN = 256
MAX_CONTENT_LEN = 4096
MAX_TARGET_LEN = 256
MAX_COMPRESSED = 32 * 1024
MAX_DECOMPRESSED = 64 * 1024

ALLOWED_MODES = (0o644, 0o755)

# The verified real BusyBox payload must never be touched by a layer.
PROTECTED_PATHS = ("bin/busybox", "usr/bin/busybox")

# Deletion markers are only meaningful for applet entries.
WHITEOUT_ROOTS = ("bin/", "sbin/", "usr/bin/", "usr/sbin/")


def _reject(msg):
    sys.stderr.write("REJECT: %s\n" % msg)
    return 2


def _error(msg):
    sys.stderr.write("ERROR: %s (materialization failure)\n" % msg)
    return 1


def _check_path(path):
    """Value-level path policy. Returns an error string or None."""
    if not path:
        return "empty path"
    if len(path.encode("utf-8")) > MAX_PATH_LEN:
        return "path exceeds bound"
    if path.startswith("/"):
        return "absolute path %r" % path
    if "\\" in path or "\x00" in path:
        return "illegal characters in path %r" % path
    parts = path.split("/")
    for part in parts:
        if part in ("", ".", ".."):
            return "traversal or empty component in path %r" % path
    if path in PROTECTED_PATHS:
        return "protected BusyBox payload path %r" % path
    return None


def _check_target(target):
    if not target:
        return "empty symlink target"
    if len(target.encode("utf-8")) > MAX_TARGET_LEN:
        return "symlink target exceeds bound"
    if "/" in target or "\\" in target or "\x00" in target:
        return "symlink target must be a bare relative name"
    if target in (".", ".."):
        return "illegal symlink target %r" % target
    return None


def _parse(data):
    """Parse and fully validate. Returns (records, err, infra).

    records is a list of (type, path, payload) on success. err is a
    semantic-REJECT message or None. infra is True when the failure is a
    corrupt/truncated envelope rather than a semantic violation.
    """
    if data[0:4] != MAGIC:
        return None, None, True
    if len(data) < 7:
        return None, None, True
    if data[4] != VERSION:
        return None, None, True
    (count,) = struct.unpack_from(">H", data, 5)
    if count < 1 or count > MAX_RECORDS:
        return None, None, True
    pos = 7
    records = []
    seen = set()
    for _ in range(count):
        if pos + 3 > len(data):
            return None, None, True
        rtype = data[pos]
        (plen,) = struct.unpack_from(">H", data, pos + 1)
        pos += 3
        if plen < 1 or plen > MAX_PATH_LEN:
            # A zero/oversize length with otherwise intact framing is a
            # malformed record, not truncation.
            if pos + plen > len(data):
                return None, None, True
            return None, "malformed record", False
        if pos + plen > len(data):
            return None, None, True
        try:
            path = data[pos:pos + plen].decode("utf-8")
        except UnicodeDecodeError:
            return None, "malformed path encoding", False
        pos += plen
        problem = _check_path(path)
        if problem is not None:
            return None, problem, False
        if path in seen:
            return None, "conflicting records for path %r" % path, False
        seen.add(path)
        if rtype == T_FILE:
            if pos + 6 > len(data):
                return None, None, True
            (mode,) = struct.unpack_from(">H", data, pos)
            (clen,) = struct.unpack_from(">L", data, pos + 2)
            pos += 6
            if mode not in ALLOWED_MODES:
                return None, "disallowed mode for path %r" % path, False
            if clen < 1 or clen > MAX_CONTENT_LEN:
                if pos + clen > len(data):
                    return None, None, True
                return None, "oversize file content for path %r" % path, False
            if pos + clen > len(data):
                return None, None, True
            content = data[pos:pos + clen]
            pos += clen
            if b"\x00" in content:
                return None, "illegal file content for path %r" % path, False
            records.append((rtype, path, (mode, content)))
        elif rtype == T_SYMLINK:
            if pos + 2 > len(data):
                return None, None, True
            (tlen,) = struct.unpack_from(">H", data, pos)
            pos += 2
            if tlen < 1 or tlen > MAX_TARGET_LEN:
                if pos + tlen > len(data):
                    return None, None, True
                return None, "malformed symlink record for path %r" % path, False
            if pos + tlen > len(data):
                return None, None, True
            try:
                target = data[pos:pos + tlen].decode("utf-8")
            except UnicodeDecodeError:
                return None, "malformed symlink target for path %r" % path, False
            pos += tlen
            problem = _check_target(target)
            if problem is not None:
                return None, "%s for path %r" % (problem, path), False
            records.append((rtype, path, target))
        elif rtype == T_WHITEOUT:
            if not path.startswith(WHITEOUT_ROOTS):
                return None, "deletion outside applet directories for path %r" % path, False
            records.append((rtype, path, None))
        else:
            return None, "unsupported entry type 0x%02x" % rtype, False
    if pos != len(data):
        return None, None, True
    return records, None, False


def main(argv):
    if len(argv) != 3:
        sys.stderr.write("Usage: apply_candidate_layer.py <candidate.layer> <dest-root>\n")
        return 1
    layer_path, dest = argv[1], argv[2]
    if not os.path.isdir(dest):
        return _error("destination tree missing: %r" % dest)
    try:
        with open(layer_path, "rb") as fh:
            blob = fh.read()
    except OSError as exc:
        return _error("cannot read assignment layer: %s" % exc)
    if len(blob) > MAX_COMPRESSED:
        return _error("assignment layer exceeds bound")
    try:
        data = gzip.decompress(blob)
    except (OSError, EOFError, ValueError):
        return _error("assignment layer is not a valid compressed layer")
    if len(data) > MAX_DECOMPRESSED:
        return _error("assignment layer exceeds bound")
    records, err, infra = _parse(data)
    if records is None:
        if infra:
            return _error("assignment layer is corrupt or truncated")
        return _reject(err)
    dest_real = os.path.realpath(dest)
    staged = []
    for rtype, path, payload in records:
        full = os.path.normpath(os.path.join(dest_real, path))
        if os.path.commonpath([dest_real, full]) != dest_real:
            return _reject("write outside candidate root for path %r" % path)
        staged.append((rtype, full, payload))
    for rtype, full, payload in staged:
        try:
            if rtype == T_WHITEOUT:
                if not os.path.lexists(full):
                    return _error("deletion target absent in base tree")
                if os.path.isdir(full) and not os.path.islink(full):
                    return _error("deletion target is a directory")
                os.remove(full)
            elif rtype == T_SYMLINK:
                if os.path.lexists(full):
                    if os.path.isdir(full) and not os.path.islink(full):
                        return _error("cannot replace directory with symlink")
                    os.remove(full)
                else:
                    parent = os.path.dirname(full)
                    os.makedirs(parent, exist_ok=True)
                os.symlink(payload, full)
            else:
                mode, content = payload
                parent = os.path.dirname(full)
                os.makedirs(parent, exist_ok=True)
                if os.path.lexists(full):
                    if os.path.isdir(full) and not os.path.islink(full):
                        return _error("cannot replace directory with file")
                    os.remove(full)
                with open(full, "wb") as fh:
                    fh.write(content)
                os.chmod(full, mode)
        except OSError as exc:
            return _error("cannot materialize assignment layer: %s" % exc)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
