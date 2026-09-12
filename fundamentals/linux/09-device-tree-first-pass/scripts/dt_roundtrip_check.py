#!/usr/bin/env python3
"""Semantic-equivalence checker for a DTB -> DTS -> DTB round trip (P3-M05).

Lab 5.2 requires the learner to *prove* that decompiling and recompiling the
QEMU ``virt`` device tree yields a structurally valid tree with unchanged
semantics.  Raw byte equality is the wrong test (property order, padding,
phandle renumbering and the ``chosen`` seed properties all legitimately
change), and raw string presence is the wrong test too (a decoy string proves
nothing).  This tool compares the two trees *semantically*:

  * identical node hierarchy and node order,
  * identical property set per node,
  * identical property values, byte for byte,
  * identical memory reservation entries,

with an explicit, documented exclusion list for properties a producer is
allowed to randomise.  QEMU randomises ``chosen/rng-seed`` and
``chosen/kaslr-seed`` on every invocation, so they are excluded by default --
and the module teaches why a DTB hash alone is not a stable identity.

Exit status
-----------
0  PASS   -- semantically equal
1  REJECT -- well-formed but semantically different
2  ERROR  -- one of the artifacts could not be parsed

Usage
-----
    python3 scripts/dt_roundtrip_check.py ORIGINAL.dtb ROUNDTRIPPED.dtb
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import List, Optional

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fdtlib_min import (  # noqa: E402
    FdtFormatError,
    FdtSemanticError,
    parse_file,
    semantic_diff,
)

EXIT_PASS = 0
EXIT_REJECT = 1
EXIT_ERROR = 2

DEFAULT_SKIP = ("rng-seed", "kaslr-seed")


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="P3-M05 DTB round-trip semantic check")
    parser.add_argument("original")
    parser.add_argument("roundtripped")
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--skip-props", default=",".join(DEFAULT_SKIP),
                        help="comma-separated property names excluded from the comparison "
                             "(default: the QEMU-randomised chosen seeds)")
    args = parser.parse_args(argv)

    skip = tuple(p for p in args.skip_props.split(",") if p)

    try:
        left = parse_file(args.original)
    except (FdtFormatError, FdtSemanticError) as exc:
        print(f"ERROR: cannot parse {args.original}: {exc}", file=sys.stderr)
        return EXIT_ERROR
    try:
        right = parse_file(args.roundtripped)
    except (FdtFormatError, FdtSemanticError) as exc:
        print(f"ERROR: cannot parse {args.roundtripped}: {exc}", file=sys.stderr)
        return EXIT_ERROR

    diff = semantic_diff(left, right, skip_props=skip)

    if not args.quiet:
        print("=" * 66)
        print("=== P3-M05 DTB -> DTS -> DTB semantic round-trip check")
        print(f"=== original:      {args.original}")
        print(f"=== round-tripped: {args.roundtripped}")
        print(f"=== excluded (non-deterministic) properties: {list(skip) or 'none'}")
        print("=" * 66)

    if diff:
        print(f"REJECT: the round-tripped tree differs semantically "
              f"({len(diff)} diff line(s)):")
        for line in diff[:60]:
            print("    " + line)
        if len(diff) > 60:
            print(f"    ... {len(diff) - 60} more line(s)")
        return EXIT_REJECT

    assert left.root is not None and right.root is not None
    nodes_left = sum(1 for _ in left.root.walk())
    nodes_right = sum(1 for _ in right.root.walk())
    print(f"[PASS] node hierarchy identical ({nodes_left} node(s) each)")
    print(f"[PASS] property sets and values identical")
    print(f"[PASS] memory reservation block identical ({len(left.reservations)} entry/entries)")
    print("=== ROUND-TRIP: SEMANTICALLY EQUIVALENT ===")
    return EXIT_PASS


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
