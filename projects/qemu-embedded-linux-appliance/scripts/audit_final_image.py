#!/usr/bin/env python3
"""P3-M08 final image audit: overlay propagation into the booted initramfs.

Standalone wrapper in the spirit of P3-M06 scripts/audit_output_tree.py.
The newc/crc cpio reader below is a minimal self-contained implementation
(duplicated rather than imported) so this project stays runnable without
depending on the fundamentals/ tree at review time. Behaviour matches the
M06 overlay checks: in-image, not-stale, no-decoy.

Checks:
  overlay.in-image -- every overlay file present and byte-identical in IMAGE
  overlay.not-stale -- with --staged: staged-but-not-imaged files are stale;
                       without --staged: overlay mtime newer than IMAGE is stale
  overlay.no-decoy  -- marker string elsewhere in the image is not the file
  image.entries     -- regular-file count inside IMAGE

Exit status: 0 PASS / 1 REJECT / 2 ERROR.
"""
from __future__ import annotations

import argparse
import gzip
import json
import os
import stat
import sys
from typing import Dict, Iterator, List, Optional, Tuple

EXIT_PASS = 0
EXIT_REJECT = 1
EXIT_ERROR = 2

CPIO_MAGIC_NEWC = b"070701"
CPIO_MAGIC_CRC = b"070702"


class CpioError(Exception):
    pass


def _read_cpio_stream(data: bytes) -> Iterator[Tuple[str, int, int, bytes]]:
    """Yield (name, mode, mtime, content) for each regular file entry."""
    pos = 0
    while True:
        if pos + 110 > len(data):
            raise CpioError("cpio archive ends inside a header")
        magic = data[pos:pos + 6]
        if magic not in (CPIO_MAGIC_NEWC, CPIO_MAGIC_CRC):
            raise CpioError(f"unexpected cpio magic {magic!r} at offset {pos}")
        fields = []
        for index in range(13):
            start = pos + 6 + index * 8
            try:
                fields.append(int(data[start:start + 8], 16))
            except ValueError as exc:
                raise CpioError(f"malformed cpio header field at offset {start}") from exc
        mode = fields[1]
        filesize = fields[6]
        namesize = fields[11]
        pos += 110
        if pos + namesize > len(data):
            raise CpioError("cpio name extends past end of archive")
        raw_name = data[pos:pos + namesize]
        name = raw_name.split(b"\x00", 1)[0].decode("utf-8", errors="replace")
        pos += namesize
        pos = (pos + 3) & ~3
        if pos + filesize > len(data):
            raise CpioError(f"cpio entry {name!r} extends past end of archive")
        content = data[pos:pos + filesize]
        pos += filesize
        pos = (pos + 3) & ~3
        if name == "TRAILER!!!":
            return
        if stat.S_ISREG(mode):
            yield name.lstrip("./"), mode, fields[5], content


def read_cpio(path: str) -> Dict[str, Tuple[int, int, bytes]]:
    with open(path, "rb") as handle:
        raw = handle.read()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    out: Dict[str, Tuple[int, int, bytes]] = {}
    for name, mode, mtime, content in _read_cpio_stream(raw):
        out[name] = (mode, mtime, content)
    return out


def walk_overlay(root: str) -> Dict[str, bytes]:
    out: Dict[str, bytes] = {}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in (".git", ".svn", ".hg")]
        for name in filenames:
            if name.endswith("~") or name == ".empty":
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            with open(full, "rb") as handle:
                out[rel] = handle.read()
    return out


def audit(image: str, overlay: str, staged: Optional[str]) -> Tuple[List[Tuple[str, bool, str]], List[str]]:
    results: List[Tuple[str, bool, str]] = []
    errors: List[str] = []
    if not os.path.isfile(image):
        return results, [f"final image not found: {image}"]
    if not os.path.isdir(overlay):
        return results, [f"overlay tree not found: {overlay}"]
    overlay_files = walk_overlay(overlay)
    results.append(("overlay.source", bool(overlay_files),
                    f"{len(overlay_files)} file(s) in the overlay source tree"))
    try:
        entries = read_cpio(image)
    except (CpioError, OSError, EOFError) as exc:
        return results, [f"cannot read final image {image}: {exc}"]

    missing = [rel for rel, content in sorted(overlay_files.items())
               if rel not in entries or entries[rel][2] != content]
    differ = [rel for rel in missing if rel in entries]
    absent = [rel for rel in missing if rel not in entries]
    results.append(("overlay.in-image", not missing,
                    f"all {len(overlay_files)} overlay file(s) byte-identical inside "
                    f"{os.path.basename(image)}" if not missing else
                    f"absent from image: {absent[:4]}; differs: {differ[:4]}"))

    if staged is not None:
        if not os.path.isdir(staged):
            return results, [f"staged tree not found: {staged}"]
        stale = [rel for rel in overlay_files
                 if os.path.isfile(os.path.join(staged, rel)) and rel not in entries]
        results.append(("overlay.not-stale", not stale,
                        "no staged overlay file missing from the image" if not stale else
                        f"STALE IMAGE: {stale[:4]} staged but not imaged"))
    else:
        try:
            image_mtime = os.path.getmtime(image)
        except OSError as exc:
            return results, [f"cannot stat image: {exc}"]
        newer = []
        for dirpath, _d, filenames in os.walk(overlay):
            for name in filenames:
                full = os.path.join(dirpath, name)
                try:
                    if os.path.getmtime(full) > image_mtime + 1:
                        newer.append(os.path.relpath(full, overlay).replace(os.sep, "/"))
                except OSError:
                    pass
        results.append(("overlay.not-stale", not newer,
                        "image is not older than the overlay source" if not newer else
                        f"STALE IMAGE: overlay newer than image: {newer[:4]}"))

    decoys: List[str] = []
    for rel, content in sorted(overlay_files.items()):
        if rel in entries:
            continue
        needle = content.strip()
        if not needle:
            continue
        for name, (_mode, _mtime, body) in entries.items():
            if needle in body:
                decoys.append(f"{rel} (string found inside {name})")
                break
    results.append(("overlay.no-decoy", not decoys,
                    "no overlay file represented only by a decoy string" if not decoys else
                    f"decoy-only representation: {decoys[:4]}"))
    results.append(("image.entries", True, f"{len(entries)} regular file(s) inside "
                                           f"{os.path.basename(image)}"))
    return results, errors


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="P3-M08 final image audit")
    parser.add_argument("--image", required=True)
    parser.add_argument("--overlay", required=True)
    parser.add_argument("--staged", default=None)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    results, errors = audit(args.image, args.overlay, args.staged)
    if args.json:
        print(json.dumps({
            "image": args.image, "overlay": args.overlay,
            "errors": errors,
            "results": [{"id": i, "ok": o, "detail": d} for i, o, d in results],
            "verdict": "ERROR" if errors else ("PASS" if all(o for _, o, _ in results) else "REJECT"),
        }, indent=2))
        if errors:
            return EXIT_ERROR
        return EXIT_PASS if all(o for _, o, _ in results) else EXIT_REJECT
    if not args.quiet:
        print("=" * 66)
        print("=== P3-M08 final image audit")
        print(f"=== image  : {args.image}")
        print(f"=== overlay: {args.overlay}")
        print("=" * 66)
        for ident, ok, detail in results:
            print(f"[{'PASS' if ok else 'FAIL'}] {ident}" + (f" -- {detail}" if detail else ""))
    if errors:
        for err in errors:
            print(f"ERROR: {err}", file=sys.stderr)
        print("=== FINAL IMAGE AUDIT: ERROR ===", file=sys.stderr)
        return EXIT_ERROR
    failed = [i for i, ok, _ in results if not ok]
    if failed:
        print(f"=== FINAL IMAGE AUDIT: REJECT ({len(failed)} violated) ===", file=sys.stderr)
        for ident in failed:
            print(f"    - {ident}", file=sys.stderr)
        return EXIT_REJECT
    if not args.quiet:
        print(f"=== FINAL IMAGE AUDIT: PASS ({len(results)} checks) ===")
    return EXIT_PASS


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
