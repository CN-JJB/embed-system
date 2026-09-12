#!/usr/bin/env python3
"""Learner-safe structural / safety invariant checker for a DTB (P3-M05).

This is the check that a *learner* is allowed to run against their own
candidate artifact.  It deliberately contains **no** expectation about the
canonical QEMU ``virt`` contract: it only answers "is this a well-formed,
internally consistent device tree blob?".

That distinction matters for assessment integrity.  A candidate whose
``pl011`` node carries a wrong-but-well-formed ``reg`` address is structurally
*valid*, so this checker passes it; the semantic contract conformance is graded
separately by the reviewer oracle.  The learner is expected to prove semantic
correctness by decompiling the tree and reasoning about the hardware model --
which is exactly the competency the module assesses.

Exit status
-----------
0  PASS  -- well-formed and internally consistent
1  REJECT -- well-formed DTB that violates a structural rule
2  ERROR -- the file is not a parseable DTB (tool/format error, never a
            semantic rejection)

Usage
-----
    python3 scripts/dt_structural_check.py CANDIDATE.dtb
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import Any, Dict, List, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fdtlib_min import (  # noqa: E402
    Fdt,
    FdtFormatError,
    FdtSemanticError,
    decode_interrupts,
    decode_reg,
    parse_file,
    resolve_phandle,
)

EXIT_PASS = 0
EXIT_REJECT = 1
EXIT_ERROR = 2

NAME_RE_ALLOWED = set(
    "abcdefghijklmnopqrstuvwxyz"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "0123456789,._+-@#?"
)


def check(dtb_path: str) -> Tuple[List[Tuple[str, bool, str]], List[str]]:
    results: List[Tuple[str, bool, str]] = []
    errors: List[str] = []

    try:
        fdt: Fdt = parse_file(dtb_path)
    except FdtFormatError as exc:
        return results, [f"not a parseable DTB: {exc}"]
    except FdtSemanticError as exc:
        results.append(("tree.structure", False, str(exc)))
        return results, errors

    assert fdt.root is not None
    root = fdt.root
    nodes = list(root.walk())
    results.append(("tree.parse", True, f"FDT v{fdt.version}, {len(nodes)} node(s), "
                                        f"totalsize={fdt.totalsize}"))

    if root.name != "":
        results.append(("tree.root-name", False,
                        f"root node name must be the empty string, got {root.name!r}"))
    else:
        results.append(("tree.root-name", True, "root node has the empty name"))

    # Node name shape and property name shape.
    bad_names = []
    for node in nodes:
        if node.parent is None:
            continue
        if not node.name or not set(node.name) <= NAME_RE_ALLOWED:
            bad_names.append(node.path)
        for prop in node.props:
            if not prop or set(prop) - NAME_RE_ALLOWED:
                bad_names.append(f"{node.path}:{prop!r}")
    results.append(("names.wellformed", not bad_names,
                    "all node and property names are well formed"
                    if not bad_names else f"malformed name(s): {bad_names[:6]}"))

    # Sibling uniqueness and property uniqueness are enforced during parsing;
    # reaching this point proves they hold.
    results.append(("tree.unique-siblings", True, "no duplicate sibling node names"))
    results.append(("tree.unique-props", True, "no duplicate property names within a node"))

    # Every declared phandle must be unique and single-celled.
    declared: Dict[int, str] = {}
    phandle_problems: List[str] = []
    for node in nodes:
        if not node.has("phandle"):
            continue
        try:
            value = node.prop_cells("phandle")
        except FdtSemanticError as exc:
            phandle_problems.append(str(exc))
            continue
        if len(value) != 1:
            phandle_problems.append(f"{node.path}: phandle holds {len(value)} cells")
            continue
        if value[0] in declared:
            phandle_problems.append(
                f"phandle 0x{value[0]:x} declared by both {declared[value[0]]} and {node.path}")
        declared[value[0]] = node.path
    results.append(("phandle.declared", not phandle_problems,
                    f"{len(declared)} phandle(s) declared uniquely"
                    if not phandle_problems else "; ".join(phandle_problems[:4])))

    # Every phandle reference must resolve.
    dangling: List[str] = []
    for node in nodes:
        for ref_prop in ("interrupt-parent", "clocks", "next-level-cache"):
            if not node.has(ref_prop):
                continue
            try:
                cells = node.prop_cells(ref_prop)
            except FdtSemanticError as exc:
                dangling.append(str(exc))
                continue
            if ref_prop == "interrupt-parent":
                if len(cells) != 1:
                    dangling.append(f"{node.path}: interrupt-parent must be one cell")
                    continue
                if resolve_phandle(root, cells[0]) is None:
                    dangling.append(
                        f"{node.path}: interrupt-parent <0x{cells[0]:x}> does not resolve")
    results.append(("phandle.references-resolve", not dangling,
                    "all phandle references resolve"
                    if not dangling else "; ".join(dangling[:4])))

    # Addressing self-consistency: every reg / interrupts must decode under the
    # rules of the tree that declares it.  This is a *type* check, not a value
    # check -- it says nothing about whether the address is the right one.
    reg_problems: List[str] = []
    reg_nodes = 0
    for node in nodes:
        if node.parent is None or not node.has("reg"):
            continue
        reg_nodes += 1
        try:
            decode_reg(node)
        except FdtSemanticError as exc:
            reg_problems.append(str(exc))
    results.append(("reg.cell-arithmetic", not reg_problems,
                    f"{reg_nodes} node(s) with reg decode consistently with their parent cells"
                    if not reg_problems else "; ".join(reg_problems[:4])))

    int_problems: List[str] = []
    int_nodes = 0
    for node in nodes:
        if not node.has("interrupts"):
            continue
        int_nodes += 1
        try:
            decode_interrupts(node)
        except FdtSemanticError as exc:
            int_problems.append(str(exc))
    results.append(("interrupts.cell-arithmetic", not int_problems,
                    f"{int_nodes} node(s) with interrupts decode consistently with their "
                    f"interrupt parent's #interrupt-cells"
                    if not int_problems else "; ".join(int_problems[:4])))

    # Cell-count properties must be single-celled and sane.
    cell_problems: List[str] = []
    for node in nodes:
        for prop in ("#address-cells", "#size-cells", "#interrupt-cells", "#gpio-cells",
                     "#clock-cells", "#phy-cells"):
            if not node.has(prop):
                continue
            try:
                value = node.prop_cells(prop)
            except FdtSemanticError as exc:
                cell_problems.append(str(exc))
                continue
            if len(value) != 1:
                cell_problems.append(f"{node.path}: {prop} must hold exactly one cell")
            elif not 0 <= value[0] <= 4:
                cell_problems.append(f"{node.path}: {prop}={value[0]} is outside the "
                                     "specification's 0..4 range")
    results.append(("cells.properties-sane", not cell_problems,
                    "all #*-cells properties are single-celled and within 0..4"
                    if not cell_problems else "; ".join(cell_problems[:4])))

    # String-list properties must not contain interior empty elements.
    string_problems: List[str] = []
    for node in nodes:
        for prop in ("compatible", "model", "status", "device_type"):
            if not node.has(prop):
                continue
            raw = node.props[prop]
            if b"\x00\x00" in raw.rstrip(b"\x00"):
                string_problems.append(f"{node.path}:{prop} contains an empty element")
    results.append(("strings.no-empty-elements", not string_problems,
                    "no string-list property contains an empty element"
                    if not string_problems else "; ".join(string_problems[:4])))

    return results, errors


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="P3-M05 learner-safe DTB structural check")
    parser.add_argument("dtb", help="device tree blob under test")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    results, errors = check(args.dtb)

    if args.json:
        import json
        print(json.dumps({
            "artifact": args.dtb,
            "errors": errors,
            "results": [{"id": i, "ok": o, "detail": d} for i, o, d in results],
            "verdict": "ERROR" if errors else
                       ("PASS" if all(o for _, o, _ in results) else "REJECT"),
        }, indent=2))
    else:
        print("=" * 66)
        print(f"=== P3-M05 learner-safe DTB structural check: {args.dtb}")
        print("=" * 66)
        for ident, good, detail in results:
            print(f"[{'PASS' if good else 'FAIL'}] {ident}" + (f" -- {detail}" if detail else ""))

    if errors:
        for err in errors:
            print(f"ERROR: {err}", file=sys.stderr)
        print("=== STRUCTURAL CHECK: ERROR (artifact is not a parseable DTB) ===", file=sys.stderr)
        return EXIT_ERROR

    failed = [i for i, good, _ in results if not good]
    if failed:
        print(f"=== STRUCTURAL CHECK: REJECT ({len(failed)} structural defect(s)) ===",
              file=sys.stderr)
        return EXIT_REJECT

    if not args.quiet:
        print(f"=== STRUCTURAL CHECK: PASS ({len(results)} structural invariants) ===")
    return EXIT_PASS


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
