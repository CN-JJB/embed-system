#!/usr/bin/env python3
"""Semantic contract validator for P3-M05 device tree artifacts.

This validator is *structural and type-aware*: it parses the DTB with
``fdtlib_min`` and interprets ``reg`` / ``interrupts`` / ``status`` under the
addressing rules of the actual tree.  It never searches for substrings, so the
following defect classes -- all of which defeat a text-matching validator --
are caught:

* the expected string appears only in a comment, a ``/delete-property/`` decoy,
  or dead padding (the DTB is binary: comments do not exist in it at all);
* a property carries the expected value but on the wrong node;
* ``reg`` has the wrong cell count for its parent's
  ``#address-cells``/``#size-cells``, or decodes to the wrong address;
* both ``"okay"`` and ``"disabled"`` strings are present somewhere but the
  *effective* ``status`` of the node in question is wrong;
* a phandle reference (``interrupt-parent``) does not resolve, or resolves to a
  node that is not an interrupt controller.

Exit status
-----------
0  PASS     -- every invariant in the requested profile holds
1  REJECT   -- well-formed DTB that violates the semantic contract
2  ERROR    -- the artifact could not be read/parsed, or the profile is unusable

The 1/2 split is mandatory: a malformed DTB must be reported as ERROR and must
never be counted as an intended semantic rejection.

Usage
-----
    python3 scripts/validate_dt_semantics.py --profile fixtures/profiles/qemu-virt-a7-canonical.json CANDIDATE.dtb
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any, Dict, List, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fdtlib_min import (  # noqa: E402
    Fdt,
    FdtFormatError,
    FdtSemanticError,
    Node,
    decode_interrupts,
    decode_reg,
    interrupt_parent_of,
    parse_file,
    resolve_phandle,
)

EXIT_PASS = 0
EXIT_REJECT = 1
EXIT_ERROR = 2

DEFAULT_PROFILE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "fixtures", "profiles", "qemu-virt-a7-canonical.json")


class Check:
    """Accumulates invariant results and distinguishes REJECT from ERROR."""

    def __init__(self) -> None:
        self.results: List[Tuple[str, bool, str]] = []
        self.errors: List[str] = []

    def ok(self, ident: str, detail: str = "") -> None:
        self.results.append((ident, True, detail))

    def bad(self, ident: str, detail: str) -> None:
        self.results.append((ident, False, detail))

    def error(self, detail: str) -> None:
        self.errors.append(detail)

    # -- helpers -----------------------------------------------------------

    def expect(self, ident: str, condition: bool, detail: str) -> bool:
        if condition:
            self.ok(ident, detail)
        else:
            self.bad(ident, detail)
        return condition

    def guard(self, ident: str, fn, detail_ok: str = "") -> Any:
        """Run ``fn``; convert addressing/type violations into REJECTs.

        A ``FdtSemanticError`` raised while interpreting a property means the
        tree is well-formed but violates an addressing rule -- that is a
        semantic rejection, not a tool error.
        """
        try:
            value = fn()
        except FdtSemanticError as exc:
            self.bad(ident, str(exc))
            return None
        except FdtFormatError as exc:  # pragma: no cover - parse already done
            self.error(str(exc))
            return None
        self.ok(ident, detail_ok)
        return value


# ---------------------------------------------------------------------------
# Individual invariant families
# ---------------------------------------------------------------------------


def check_root(check: Check, root: Node, profile: Dict[str, Any]) -> None:
    spec = profile["root"]
    compat = check.guard("root.compatible.read", lambda: root.prop_strs("compatible"))
    if compat is not None:
        check.expect("root.compatible.contains",
                     spec["compatible"] in compat,
                     f"root compatible={compat!r} must contain {spec['compatible']!r}")
    if "model" in spec:
        model = check.guard("root.model.read", lambda: root.prop_str("model"))
        if model is not None:
            check.expect("root.model.value", model == spec["model"],
                         f"root model={model!r} expected {spec['model']!r}")
    ac = check.guard("root.address-cells", lambda: root.prop_cells("#address-cells"))
    if ac is not None:
        check.expect("root.address-cells.value", ac == [spec["address_cells"]],
                     f"root #address-cells={ac} expected [{spec['address_cells']}]")
    sc = check.guard("root.size-cells", lambda: root.prop_cells("#size-cells"))
    if sc is not None:
        check.expect("root.size-cells.value", sc == [spec["size_cells"]],
                     f"root #size-cells={sc} expected [{spec['size_cells']}]")


def check_reg_node(check: Check, root: Node, ident: str, path: str,
                   expected: List[List[int]], *, require_device_type: Optional[str] = None,
                   required: bool = True) -> Optional[Node]:
    node = None
    for candidate in root.walk():
        if candidate.path == path:
            node = candidate
            break
    if node is None:
        if required:
            check.bad(f"{ident}.node", f"required node {path} is absent")
        return None
    check.ok(f"{ident}.node", f"{path} present")

    if require_device_type is not None:
        dt = check.guard(f"{ident}.device_type", lambda: node.prop_str("device_type"))
        if dt is not None:
            check.expect(f"{ident}.device_type.value", dt == require_device_type,
                         f"{path} device_type={dt!r} expected {require_device_type!r}")

    entries = check.guard(f"{ident}.reg.decode", lambda: decode_reg(node))
    if entries is not None:
        check.expect(f"{ident}.reg.entries",
                     entries == [tuple(e) for e in expected],
                     f"{path} reg decodes to {entries} under parent "
                     f"{node.parent.path if node.parent else '<none>'} "
                     f"#address-cells={node.parent.address_cells() if node.parent else '?'}"
                     f"/#size-cells={node.parent.size_cells() if node.parent else '?'}; "
                     f"expected {[tuple(e) for e in expected]}")
    return node


def check_status(check: Check, node: Optional[Node], ident: str, expect_enabled: bool) -> None:
    if node is None:
        return
    enabled = check.guard(f"{ident}.status.effective", lambda: node.is_enabled())
    if enabled is None:
        return
    raw = node.props.get("status")
    rendered = "<absent>" if raw is None else repr(raw)
    check.expect(f"{ident}.status.value", enabled == expect_enabled,
                 f"{node.path} effective status={enabled} (raw {rendered}) "
                 f"expected {'enabled' if expect_enabled else 'disabled'}")


def check_interrupts(check: Check, node: Optional[Node], ident: str,
                     expected: List[List[int]]) -> None:
    if node is None:
        return
    specs = check.guard(f"{ident}.interrupts.decode", lambda: decode_interrupts(node))
    if specs is None:
        return
    parent = interrupt_parent_of(node)
    check.expect(f"{ident}.interrupts.specifiers",
                 specs == expected,
                 f"{node.path} interrupts decode to {specs} under "
                 f"{parent.path if parent else '<none>'} #interrupt-cells="
                 f"{parent.interrupt_cells() if parent else '?'}; expected {expected}")


def check_peripheral(check: Check, root: Node, ident: str, spec: Dict[str, Any]) -> None:
    """Generic resource contract for a leaf device node.

    ``reg`` is interpreted under the *parent's* cell rules and ``interrupts``
    under the *interrupt parent's* ``#interrupt-cells``.  A node that declares
    the right strings but the wrong resources fails here, which is precisely
    the class of defect a string-matching validator cannot see.

    ``reg`` and ``interrupts`` are both optional: some nodes (for example the
    architected ``/timer``) carry interrupts but no register window.
    """
    node: Optional[Node] = None
    if "reg" in spec:
        entries = spec["reg"]
        # Accept either a single (address, size) pair or a list of them.
        if entries and not isinstance(entries[0], list):
            entries = [entries]
        node = check_reg_node(check, root, ident, spec["path"], entries,
                              require_device_type=spec.get("device_type"))
        if node is None:
            return
    else:
        for candidate in root.walk():
            if candidate.path == spec["path"]:
                node = candidate
                break
        if node is None:
            check.bad(f"{ident}.node", f"required node {spec['path']} is absent")
            return
        check.ok(f"{ident}.node", f"{spec['path']} present")
    if "compatible" in spec:
        compat = check.guard(f"{ident}.compatible.read", lambda: node.prop_strs("compatible"))
        if compat is not None:
            check.expect(f"{ident}.compatible.value", compat == spec["compatible"],
                         f"{spec['path']} compatible={compat!r} expected {spec['compatible']!r}")
    if "compatible_contains" in spec:
        compat = check.guard(f"{ident}.compatible.read", lambda: node.prop_strs("compatible"))
        if compat is not None:
            check.expect(f"{ident}.compatible.contains",
                         spec["compatible_contains"] in compat,
                         f"{spec['path']} compatible={compat!r} must contain "
                         f"{spec['compatible_contains']!r}")
    if "status_enabled" in spec:
        check_status(check, node, ident, spec["status_enabled"])
    if "interrupts" in spec:
        raw = spec["interrupts"]
        specs = raw if raw and isinstance(raw[0], list) else [raw]
        check_interrupts(check, node, ident, specs)


def check_virtio_windows(check: Check, root: Node, profile: Dict[str, Any]) -> None:
    """The whole `virtio-mmio` window bank must be present and disjoint.

    QEMU's `virt` machine exposes 32 identical 0x200-byte virtio-mmio windows at
    0x0a000000 + i * 0x200, with SPI (16 + i).  Checking the *bank* rather than
    one window is what exposes a defect on a window that is not individually
    listed in a contract profile: a wrong size silently overlaps the next
    window, and the overlap is only visible in the interpreted address space.
    """
    spec = profile.get("virtio_windows")
    if not spec:
        return
    base = spec["first_base"]
    stride = spec["stride"]
    size = spec["size"]
    count = spec["count"]
    first_spi = spec["first_spi"]
    trigger = spec["trigger"]

    found: Dict[int, Node] = {}
    for node in root.walk():
        if not node.name.startswith("virtio_mmio@"):
            continue
        try:
            entries = decode_reg(node)
        except FdtSemanticError as exc:
            check.bad("virtio_windows.decode", str(exc))
            continue
        if len(entries) != 1:
            check.bad("virtio_windows.decode",
                      f"{node.path}: virtio-mmio node must map exactly one window")
            continue
        found[entries[0][0]] = node

    expected_bases = [base + i * stride for i in range(count)]
    missing = [hex(b) for b in expected_bases if b not in found]
    extra = [hex(b) for b in sorted(found) if b not in expected_bases]
    check.expect("virtio_windows.present", not missing and not extra,
                 f"{len(found)} virtio-mmio window(s) found; "
                 f"missing={missing[:4]}{'...' if len(missing) > 4 else ''} "
                 f"unexpected={extra[:4]}{'...' if len(extra) > 4 else ''}")

    size_problems: List[str] = []
    spi_problems: List[str] = []
    for index, expected_base in enumerate(expected_bases):
        node = found.get(expected_base)
        if node is None:
            continue
        entries = decode_reg(node)
        if entries[0][1] != size:
            size_problems.append(
                f"{node.path}: size {entries[0][1]:#x} expected {size:#x}")
        try:
            specs = decode_interrupts(node)
        except FdtSemanticError as exc:
            spi_problems.append(str(exc))
            continue
        expected_spi = first_spi + index
        if specs != [[0, expected_spi, trigger]]:
            spi_problems.append(
                f"{node.path}: interrupts {specs} expected [[0, {expected_spi}, {trigger}]]")

    check.expect("virtio_windows.sizes", not size_problems,
                 "every virtio-mmio window is 0x200 bytes"
                 if not size_problems else "; ".join(size_problems[:4]))
    check.expect("virtio_windows.interrupts", not spi_problems,
                 "every virtio-mmio window carries its own SPI specifier"
                 if not spi_problems else "; ".join(spi_problems[:4]))


def check_uart(check: Check, root: Node, profile: Dict[str, Any]) -> None:
    spec = profile.get("uart")
    if not spec:
        return
    check_peripheral(check, root, "uart", spec)


def check_gic(check: Check, root: Node, profile: Dict[str, Any]) -> None:
    spec = profile["gic"]
    node = check_reg_node(check, root, "gic", spec["path"], spec["reg_entries"])
    if node is None:
        return
    compat = check.guard("gic.compatible.read", lambda: node.prop_strs("compatible"))
    if compat is not None:
        check.expect("gic.compatible.contains",
                     spec["compatible_contains"] in compat,
                     f"{spec['path']} compatible={compat!r} must contain "
                     f"{spec['compatible_contains']!r}")
    is_ic = check.guard("gic.interrupt-controller", lambda: node.prop_bool("interrupt-controller"))
    if is_ic is not None:
        check.expect("gic.interrupt-controller.present", is_ic,
                     f"{spec['path']} must declare the boolean interrupt-controller property")
    ic = check.guard("gic.interrupt-cells", lambda: node.interrupt_cells())
    if ic is not None:
        check.expect("gic.interrupt-cells.value", ic == spec["interrupt_cells"],
                     f"{spec['path']} #interrupt-cells={ic} expected {spec['interrupt_cells']}")
    ph = check.guard("gic.phandle", lambda: node.prop_cells("phandle"))
    if ph is not None:
        check.expect("gic.phandle.single", len(ph) == 1,
                     f"{spec['path']} phandle={ph} must be exactly one cell")


def check_phandle_graph(check: Check, root: Node) -> None:
    """Every phandle reference in the tree must resolve to a real node."""
    seen: Dict[int, str] = {}
    dangling: List[str] = []
    for node in root.walk():
        if not node.has("phandle"):
            continue
        try:
            value = node.prop_cells("phandle")
        except FdtSemanticError as exc:
            check.bad("phandle.wellformed", str(exc))
            continue
        if len(value) != 1:
            check.bad("phandle.wellformed",
                      f"{node.path}: phandle must hold exactly one cell, got {value}")
            continue
        if value[0] in seen:
            check.bad("phandle.unique",
                      f"phandle 0x{value[0]:x} is declared by both {seen[value[0]]} and {node.path}")
        seen[value[0]] = node.path
        if resolve_phandle(root, value[0]) is None:  # pragma: no cover - impossible by construction
            dangling.append(node.path)
    if not dangling:
        check.ok("phandle.unique", f"{len(seen)} distinct phandle(s) declared")

    # References that must resolve.
    for node in root.walk():
        if node.has("interrupt-parent"):
            try:
                cells = node.prop_cells("interrupt-parent")
            except FdtSemanticError as exc:
                check.bad("phandle.interrupt-parent.type", str(exc))
                continue
            if len(cells) != 1:
                check.bad("phandle.interrupt-parent.type",
                          f"{node.path}: interrupt-parent must hold exactly one cell")
                continue
            target = resolve_phandle(root, cells[0])
            if target is None:
                check.bad("phandle.interrupt-parent.resolve",
                          f"{node.path}: interrupt-parent <0x{cells[0]:x}> does not resolve")
                continue
            if not target.has("interrupt-controller"):
                check.bad("phandle.interrupt-parent.is-controller",
                          f"{node.path}: interrupt-parent resolves to {target.path} which is not "
                          "an interrupt controller")
    check.ok("phandle.interrupt-parent.resolve", "all interrupt-parent references resolve")


def check_chosen(check: Check, root: Node, profile: Dict[str, Any]) -> None:
    spec = profile.get("chosen")
    if not spec:
        return
    chosen = None
    for node in root.walk():
        if node.path == "/chosen":
            chosen = node
            break
    if chosen is None:
        check.bad("chosen.node", "required node /chosen is absent")
        return
    check.ok("chosen.node", "/chosen present")
    if chosen.has("stdout-path"):
        stdout = check.guard("chosen.stdout-path.read", lambda: chosen.prop_str("stdout-path"))
        if stdout is not None:
            target = stdout.split(":")[0]
            resolved = None
            for node in root.walk():
                if node.path == target:
                    resolved = node
                    break
            check.expect("chosen.stdout-path.resolves", resolved is not None,
                         f"/chosen stdout-path={stdout!r} must name an existing node path "
                         f"(resolved {target!r})")
            if resolved is not None:
                check.expect("chosen.stdout-path.is-uart",
                             resolved.path == spec["stdout_path"],
                             f"/chosen stdout-path points at {resolved.path} "
                             f"expected {spec['stdout_path']}")
    else:
        check.bad("chosen.stdout-path.read", "/chosen has no stdout-path")


def check_memory(check: Check, root: Node, profile: Dict[str, Any]) -> None:
    spec = profile.get("memory")
    if not spec:
        return
    node = check_reg_node(check, root, "memory", spec["path"],
                          spec["reg_entries"],
                          require_device_type=spec.get("device_type"))
    if node is None:
        return
    check_status(check, node, "memory", True)


def check_virtio(check: Check, root: Node, profile: Dict[str, Any]) -> None:
    spec = profile.get("virtio")
    if not spec:
        return
    check_peripheral(check, root, "virtio", spec)


def check_cpu(check: Check, root: Node, profile: Dict[str, Any]) -> None:
    spec = profile.get("cpu")
    if not spec:
        return
    node = check_reg_node(check, root, "cpu", spec["path"], spec["reg_entries"],
                          require_device_type="cpu")
    if node is None:
        return
    compat = check.guard("cpu.compatible.read", lambda: node.prop_strs("compatible"))
    if compat is not None:
        check.expect("cpu.compatible.contains",
                     spec["compatible_contains"] in compat,
                     f"{spec['path']} compatible={compat!r} must contain "
                     f"{spec['compatible_contains']!r}")


def check_peripherals(check: Check, root: Node, profile: Dict[str, Any]) -> None:
    """Resource contract for every declared leaf peripheral."""
    for ident, spec in sorted(profile.get("peripherals", {}).items()):
        check_peripheral(check, root, ident, spec)


def check_no_overlap(check: Check, root: Node, profile: Dict[str, Any]) -> None:
    """Every mapped MMIO range in the tree must be disjoint.

    A ``reg`` address typo that silently overlaps another device is exactly the
    F11 defect class; a *detected* overlap is a strong, non-textual signal.
    """
    ranges: List[Tuple[int, int, str]] = []
    for node in root.walk():
        if node.parent is None or not node.has("reg"):
            continue
        try:
            entries = decode_reg(node)
        except FdtSemanticError:
            continue  # already reported by the node-specific invariant
        for base, size in entries:
            if size:
                ranges.append((base, base + size, node.path))
    ranges.sort()
    overlaps: List[str] = []
    for (a_start, a_end, a_path), (b_start, b_end, b_path) in zip(ranges, ranges[1:]):
        if b_start < a_end:
            overlaps.append(f"{a_path} [0x{a_start:x},0x{a_end:x}) overlaps "
                            f"{b_path} [0x{b_start:x},0x{b_end:x})")
    if overlaps:
        check.bad("mmio.no-overlap", "; ".join(overlaps))
    else:
        check.ok("mmio.no-overlap", f"{len(ranges)} mapped MMIO range(s), all disjoint")


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------


def load_profile(path: str) -> Dict[str, Any]:
    if not os.path.isfile(path):
        raise FileNotFoundError(f"profile not found: {path}")
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def validate(dtb_path: str, profile: Dict[str, Any]) -> Check:
    check = Check()
    try:
        fdt: Fdt = parse_file(dtb_path)
    except FdtFormatError as exc:
        check.error(f"cannot parse {dtb_path} as a DTB: {exc}")
        return check
    except FdtSemanticError as exc:
        # Duplicate siblings / duplicate properties are detected while parsing
        # but are semantic defects, not tool failures.
        check.bad("tree.wellformed", str(exc))
        return check

    assert fdt.root is not None
    root = fdt.root
    check.ok("tree.wellformed", f"parsed {sum(1 for _ in root.walk())} node(s), "
                                f"FDT v{fdt.version}")

    check_root(check, root, profile)
    check_gic(check, root, profile)
    check_memory(check, root, profile)
    check_uart(check, root, profile)
    check_virtio(check, root, profile)
    check_cpu(check, root, profile)
    check_peripherals(check, root, profile)
    check_virtio_windows(check, root, profile)
    check_chosen(check, root, profile)
    check_phandle_graph(check, root)
    check_no_overlap(check, root, profile)
    return check


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="P3-M05 device tree semantic validator")
    parser.add_argument("dtb", help="device tree blob under test")
    parser.add_argument("--profile", default=DEFAULT_PROFILE,
                        help="JSON contract profile (default: canonical QEMU virt/A7)")
    parser.add_argument("--json", action="store_true", help="emit machine-readable results")
    parser.add_argument("--quiet", action="store_true", help="only print the verdict")
    args = parser.parse_args(argv)

    try:
        profile = load_profile(args.profile)
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return EXIT_ERROR

    check = validate(args.dtb, profile)

    if args.json:
        print(json.dumps({
            "artifact": args.dtb,
            "profile": profile.get("profile"),
            "errors": check.errors,
            "results": [{"id": i, "ok": o, "detail": d} for i, o, d in check.results],
            "verdict": "ERROR" if check.errors else
                       ("PASS" if all(o for _, o, _ in check.results) else "REJECT"),
        }, indent=2))
        if check.errors:
            return EXIT_ERROR
        return EXIT_PASS if all(o for _, o, _ in check.results) else EXIT_REJECT

    if not args.quiet:
        print("=" * 66)
        print(f"=== P3-M05 DT semantic contract: {profile.get('profile')}")
        print(f"=== Artifact: {args.dtb}")
        print("=" * 66)
        for ident, good, detail in check.results:
            print(f"[{'PASS' if good else 'FAIL'}] {ident}"
                  + (f" -- {detail}" if detail else ""))

    if check.errors:
        for err in check.errors:
            print(f"ERROR: {err}", file=sys.stderr)
        print("=== DT SEMANTIC CONTRACT: ERROR (artifact could not be evaluated) ===",
              file=sys.stderr)
        return EXIT_ERROR

    failed = [i for i, good, _ in check.results if not good]
    if failed:
        print(f"=== DT SEMANTIC CONTRACT: REJECT ({len(failed)} invariant(s) violated) ===",
              file=sys.stderr)
        for ident in failed:
            print(f"    - {ident}", file=sys.stderr)
        return EXIT_REJECT

    print(f"=== DT SEMANTIC CONTRACT: PASS ({len(check.results)} invariants) ===")
    return EXIT_PASS


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
