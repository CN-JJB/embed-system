#!/usr/bin/env python3
"""Deterministic DTB patcher for P3-M05 labs, faults and assessments.

The module must work on a host that has no ``dtc`` installed, so this tool
provides the *bounded* subset of editing operations the curriculum needs:

  * ``--set-string  PATH PROP VALUE``            ``status = "disabled";``
  * ``--set-cells   PATH PROP C1 [C2 ...]``      ``reg = <0x09000000 0x1000>;``
  * ``--set-empty   PATH PROP``                  a boolean property
  * ``--delete      PATH PROP``                  remove a property
  * ``--rename-node PATH NEWNAME``               rename a node

All edits are performed on the *parsed tree* and the result is re-serialised in
the canonical layout, so the output is always a well-formed DTB.  The tool is
deliberately dumb: it does not validate that the edit makes sense.  Deciding
whether a tree is *semantically* correct is the job of the validators -- and of
the learner.

Every operation is recorded on stdout as ``PATCH <op> <path> <prop>`` so a lab
log shows exactly what was changed.

Usage
-----
    python3 scripts/fdt_patch.py --in fixtures/qemu-virt.dtb --out /tmp/mod.dtb \\
        --set-string /pl011@9000000 status disabled
"""

from __future__ import annotations

import argparse
import os
import struct
import sys
from typing import List, Optional, Sequence

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fdtlib_min import (  # noqa: E402
    FdtFormatError,
    FdtSemanticError,
    Node,
    parse_file,
    write_file,
)

EXIT_OK = 0
EXIT_REJECT = 1
EXIT_ERROR = 2


def find_node(root: Node, path: str) -> Node:
    if path in ("", "/"):
        return root
    node: Optional[Node] = root
    for part in path.strip("/").split("/"):
        node = node.child(part) if node else None
        if node is None:
            raise FdtSemanticError(f"no such node: {path}")
    return node


def encode_string_list(value: str) -> bytes:
    """``"a", "b"`` -> ``b"a\\0b\\0"``.  A single string is the common case."""
    parts = [p.strip() for p in value.split(",")]
    return b"".join(p.encode("utf-8") + b"\x00" for p in parts)


def encode_cells(values: Sequence[str]) -> bytes:
    out = bytearray()
    for raw in values:
        try:
            number = int(raw, 0)
        except ValueError as exc:
            raise FdtSemanticError(f"'{raw}' is not an integer cell value") from exc
        if not 0 <= number <= 0xFFFFFFFF:
            raise FdtSemanticError(f"cell value 0x{number:x} does not fit in 32 bits")
        out.extend(struct.pack(">I", number))
    return bytes(out)


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Deterministic DTB patcher (P3-M05)")
    parser.add_argument("--in", dest="src", required=True, help="input DTB")
    parser.add_argument("--out", dest="dst", required=True, help="output DTB")
    parser.add_argument("--set-string", nargs=3, action="append", default=[],
                        metavar=("PATH", "PROP", "VALUE"))
    parser.add_argument("--set-cells", nargs="+", action="append", default=[],
                        metavar="PATH PROP CELL...")
    parser.add_argument("--set-empty", nargs=2, action="append", default=[],
                        metavar=("PATH", "PROP"))
    parser.add_argument("--delete", nargs=2, action="append", default=[],
                        metavar=("PATH", "PROP"))
    parser.add_argument("--rename-node", nargs=2, action="append", default=[],
                        metavar=("PATH", "NEWNAME"))
    args = parser.parse_args(argv)

    try:
        fdt = parse_file(args.src)
    except FdtFormatError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return EXIT_ERROR
    except FdtSemanticError as exc:
        print(f"REJECT: {exc}", file=sys.stderr)
        return EXIT_REJECT

    assert fdt.root is not None

    try:
        for path, prop, value in args.set_string:
            node = find_node(fdt.root, path)
            node.props[prop] = encode_string_list(value)
            print(f"PATCH set-string {path} {prop} = {value!r}")

        for group in args.set_cells:
            if len(group) < 3:
                raise FdtSemanticError("--set-cells needs PATH PROP CELL [CELL ...]")
            path, prop, *cells = group
            node = find_node(fdt.root, path)
            node.props[prop] = encode_cells(cells)
            print(f"PATCH set-cells {path} {prop} = <{' '.join(cells)}>")

        for path, prop in args.set_empty:
            node = find_node(fdt.root, path)
            node.props[prop] = b""
            print(f"PATCH set-empty {path} {prop}")

        for path, prop in args.delete:
            node = find_node(fdt.root, path)
            if prop not in node.props:
                raise FdtSemanticError(f"{path} has no property '{prop}' to delete")
            del node.props[prop]
            print(f"PATCH delete {path} {prop}")

        for path, new_name in args.rename_node:
            node = find_node(fdt.root, path)
            if node.parent is None:
                raise FdtSemanticError("refusing to rename the root node")
            if any(c.name == new_name for c in node.parent.children if c is not node):
                raise FdtSemanticError(
                    f"{node.parent.path} already has a child named '{new_name}'")
            old = node.name
            node.name = new_name
            print(f"PATCH rename-node {path} -> {new_name} (was {old})")
    except FdtSemanticError as exc:
        print(f"REJECT: {exc}", file=sys.stderr)
        return EXIT_REJECT

    try:
        write_file(fdt, args.dst)
    except (OSError, FdtFormatError) as exc:
        print(f"ERROR: cannot write {args.dst}: {exc}", file=sys.stderr)
        return EXIT_ERROR

    print(f"[OK] wrote {args.dst}")
    return EXIT_OK


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
