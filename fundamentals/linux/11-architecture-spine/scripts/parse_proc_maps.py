#!/usr/bin/env python3
"""Strict /proc/<pid>/maps parser and address classifier for P3-M07.

Parses maps lines in the exact
``Documentation/filesystems/proc.rst`` section 1.1 shape::

  address           perms offset  dev   inode   pathname
  00400000-0040b000 r-xp 00000000 b3:02 12345   /home/root/addrspace.elf

Only addresses that fall inside a well-formed maps line count. A decoy
address printed in unrelated text (a comment, a log line, a bare hex dump)
is REJECTed: the classifier requires a ``START-END`` range match, never a
substring search.

Exit status: 0 PASS (every candidate address classifies), 1 REJECT
(semantic: well-formed maps, but an address is outside every region or a
claimed region mismatches), 2 ERROR (malformed maps file / tool failure).

Usage:
  parse_proc_maps.py MAPS_FILE --addrs 0x400100 0xbefdf100
  parse_proc_maps.py MAPS_FILE --addr-file addrs.txt [--expect-region ...]
  parse_proc_maps.py MAPS_FILE --addr-file addrs.txt --claims claims.json
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from typing import Dict, List, Optional, Tuple

EXIT_PASS = 0
EXIT_REJECT = 1
EXIT_ERROR = 2

MAPS_RE = re.compile(
    r"^([0-9a-fA-F]+)-([0-9a-fA-F]+)\s+"
    r"([r-][w-][x-][ps])\s+"
    r"([0-9a-fA-F]+)\s+"
    r"([0-9a-fA-F]{2}:[0-9a-fA-F]{2})\s+"
    r"(\d+)\s*(.*)$"
)


def parse_maps(path: str):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            raw_lines = handle.read().splitlines()
    except OSError as exc:
        return None, f"cannot read maps file: {exc}", []
    regions = []
    errors = []
    for lineno, line in enumerate(raw_lines, start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        match = MAPS_RE.match(stripped)
        if not match:
            errors.append(f"line {lineno}: not a well-formed maps line: {line!r}")
            continue
        start_s, end_s, perms, offset_s, dev, inode_s, pathname = match.groups()
        try:
            start = int(start_s, 16)
            end = int(end_s, 16)
            offset = int(offset_s, 16)
            inode = int(inode_s)
        except ValueError:
            errors.append(f"line {lineno}: bad numeric field: {line!r}")
            continue
        if not (0 <= start < end <= 0xFFFFFFFF):
            errors.append(f"line {lineno}: bad address range: {line!r}")
            continue
        regions.append({
            "start": start, "end": end, "perms": perms,
            "offset": offset, "dev": dev, "inode": inode,
            "pathname": pathname.strip(), "lineno": lineno,
        })
    if errors:
        return None, "; ".join(errors[:4]), []
    if not regions:
        return None, "maps file contains no well-formed mapping lines", []
    return regions, "", raw_lines


def parse_addr(text: str) -> int:
    s = text.strip().strip(",;")
    return int(s, 0)


def classify(regions, addr: int) -> Optional[Dict]:
    for region in regions:
        if region["start"] <= addr < region["end"]:
            return region
    return None


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="P3-M07 /proc maps classifier")
    parser.add_argument("maps", help="maps file in proc.rst section 1.1 shape")
    parser.add_argument("--addrs", nargs="*", default=[],
                        help="candidate addresses (hex)")
    parser.add_argument("--addr-file", help="file with one address per line")
    parser.add_argument("--claims", help="optional JSON {addr: expected-substring}")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    if not os.path.isfile(args.maps):
        print(f"ERROR: maps file not found: {args.maps}", file=sys.stderr)
        return EXIT_ERROR

    regions, error, _ = parse_maps(args.maps)
    if regions is None:
        print(f"ERROR: {error}", file=sys.stderr)
        return EXIT_ERROR

    candidates: List[str] = list(args.addrs or [])
    if args.addr_file:
        if not os.path.isfile(args.addr_file):
            print(f"ERROR: addr file not found: {args.addr_file}", file=sys.stderr)
            return EXIT_ERROR
        try:
            with open(args.addr_file, "r", encoding="utf-8", errors="replace") as handle:
                for line in handle:
                    s = line.strip()
                    if not s or s.startswith("#"):
                        continue
                    # An addr-file holds bare addresses only. A line carrying
                    # extra prose is a decoy carrier, not an address list.
                    if len(s.split()) != 1:
                        print(f"ERROR: addr file line is not a bare address: {line!r}",
                              file=sys.stderr)
                        return EXIT_ERROR
                    candidates.append(s)
        except OSError as exc:
            print(f"ERROR: cannot read addr file: {exc}", file=sys.stderr)
            return EXIT_ERROR

    if not candidates:
        print("ERROR: no candidate addresses supplied (--addrs / --addr-file)",
              file=sys.stderr)
        return EXIT_ERROR

    claims: Dict[str, str] = {}
    if args.claims:
        try:
            with open(args.claims, "r", encoding="utf-8") as handle:
                loaded = json.load(handle)
            if isinstance(loaded, dict):
                claims = {str(k): str(v) for k, v in loaded.items()}
        except (OSError, ValueError) as exc:
            print(f"ERROR: cannot load claims file: {exc}", file=sys.stderr)
            return EXIT_ERROR

    results = []
    saw_reject = False
    for text in candidates:
        try:
            addr = parse_addr(text)
        except ValueError:
            print(f"ERROR: malformed candidate address: {text!r}", file=sys.stderr)
            return EXIT_ERROR
        if not (0 <= addr <= 0xFFFFFFFF):
            print(f"ERROR: address out of 32-bit range: {text!r}", file=sys.stderr)
            return EXIT_ERROR
        region = classify(regions, addr)
        if region is None:
            saw_reject = True
            results.append({
                "addr": f"0x{addr:08X}", "ok": False,
                "detail": f"0x{addr:08X} lies in no well-formed mapping region: REJECT "
                          "(decoy addresses in unrelated text do not count)",
            })
            continue
        detail = (f"0x{addr:08X} in "
                  f"0x{region['start']:08X}-0x{region['end']:08X} {region['perms']} "
                  f"{region['pathname'] or '(anonymous)'}")
        # Optional claimed-region check (e.g. learner labels heap vs stack).
        key_variants = [text, text.lower(), f"0x{addr:08X}", f"0x{addr:x}"]
        expected = ""
        for key in key_variants:
            if key in claims:
                expected = claims[key]
                break
        if expected and expected not in (region["pathname"] + " " + region["perms"]):
            # Substring match against "pathname perms" keeps the check generic:
            # a claim of "heap" must appear in the region's pathname.
            if expected not in region["pathname"]:
                saw_reject = True
                results.append({
                    "addr": f"0x{addr:08X}", "ok": False,
                    "detail": detail + f"; claimed {expected!r} mismatches region: REJECT",
                })
                continue
            detail += f"; matches claimed {expected!r}"
        results.append({"addr": f"0x{addr:08X}", "ok": True, "detail": detail})

    if args.json:
        print(json.dumps({"maps": args.maps, "results": results,
                          "verdict": "REJECT" if saw_reject else "PASS"},
                         indent=2, sort_keys=True))
    elif not args.quiet:
        print("=" * 66)
        print("=== P3-M07 /proc maps classification ===")
        print(f"=== maps: {args.maps} ({len(regions)} regions)")
        for item in results:
            print(f"[{'PASS' if item['ok'] else 'FAIL'}] {item['detail']}")

    if saw_reject:
        if not args.json and not args.quiet:
            print("=== MAPS CONTRACT: REJECT ===", file=sys.stderr)
        return EXIT_REJECT
    if not args.json and not args.quiet:
        print("=== MAPS CONTRACT: PASS ===")
    return EXIT_PASS


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
