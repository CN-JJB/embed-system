#!/usr/bin/env python3
"""Derive the expected ``/sys/firmware/devicetree/base`` layout from a DTB.

``/sys/firmware/devicetree/base`` is a direct projection of the flattened tree
the kernel consumed: every node becomes a directory, every property becomes a
file, and the file contents are the raw property bytes (binary cells and
NUL-terminated strings -- *not* arbitrary plain text).

This tool renders that projection from a DTB so that a learner can predict what
a booted guest should show and compare it with what they actually captured.

IMPORTANT EVIDENCE STATUS
-------------------------
The output of this tool is a *derived expectation*, not a runtime capture.  It
is correct as a prediction of the sysfs projection, but it is not evidence that
a kernel booted or that a driver probed.  Real runtime evidence must come from
``scripts/run_qemu_dtb_boot.sh`` and must be bound by
``scripts/verify_runtime_binding.py``.

Usage
-----
    python3 scripts/derive_sysfs_tree.py DTB [--hex] [--path /pl011@9000000]
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
    Node,
    parse_file,
)

EXIT_OK = 0
EXIT_ERROR = 2


def render(node: Node, lines: List[str], show_hex: bool) -> None:
    for name in sorted(node.props):
        value = node.props[name]
        if show_hex:
            lines.append(f"{name} = {value.hex()}")
        else:
            printable = value.rstrip(b"\x00")
            if all(32 <= b < 127 for b in printable) and printable:
                lines.append(f'{name} = "{printable.decode("ascii")}"')
            elif value == b"":
                lines.append(f"{name} = (boolean)")
            else:
                lines.append(f"{name} = <{value.hex()}>")
    for child in node.children:
        lines.append(f"[dir] {child.name}/")
        render(child, lines, show_hex)


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Derive the sysfs DT projection from a DTB")
    parser.add_argument("dtb")
    parser.add_argument("--hex", action="store_true", help="render every value as raw hex bytes")
    parser.add_argument("--path", help="render only this subtree")
    args = parser.parse_args(argv)

    try:
        fdt = parse_file(args.dtb)
    except FdtFormatError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return EXIT_ERROR
    except FdtSemanticError as exc:
        print(f"REJECT: {exc}", file=sys.stderr)
        return 1

    assert fdt.root is not None
    node = fdt.root
    if args.path:
        node = None
        for cand in fdt.root.walk():
            if cand.path == args.path:
                node = cand
                break
        if node is None:
            print(f"ERROR: no such node: {args.path}", file=sys.stderr)
            return EXIT_ERROR

    print("# DERIVED EXPECTATION -- not a runtime capture.")
    print(f"# projected from: {args.dtb}")
    print(f"# node: {node.path}")
    print("/sys/firmware/devicetree/base" + ("" if node.path == "/" else node.path) + ":")
    lines: List[str] = []
    render(node, lines, args.hex)
    for line in lines:
        print("  " + line)
    return EXIT_OK


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
