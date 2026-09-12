#!/usr/bin/env python3
"""Minimal, dependency-free Flattened Device Tree (FDT/DTB) reader and writer.

P3-M05 teaching library.  It implements exactly the subset of the Devicetree
Specification v0.4 binary format that the module needs, so that the labs and
validators work on the real QEMU-generated ``virt`` DTB even on a host that has
no ``dtc`` installed.

Design notes
------------
* The binary format is parsed *structurally* (token stream + string block +
  memory reservation block), never by searching for substrings.  A validator
  built on this library therefore cannot be fooled by a decoy string that only
  appears in a comment, in an unrelated node, or in dead padding.
* Property values are kept as raw ``bytes``.  Callers must choose an encoding
  (``prop_str`` / ``prop_strs`` / ``prop_cells``) that matches the property's
  declared type.  Treating an arbitrary property as plain text is a bug, and
  the module teaches why.
* Errors are split into two classes on purpose:
    - ``FdtFormatError``   -> the artifact is not a well-formed DTB.  This is a
      tool/format ERROR, not a semantic rejection.
    - ``FdtSemanticError`` -> the artifact is well-formed but violates an
      addressing/type rule (for example ``reg`` cell count incompatible with
      the parent's ``#address-cells``/``#size-cells``).  This is a semantic
      REJECT.
  The distinction is required by the Phase 3 negative-control contract: a
  crash or parser error must never be counted as an intended semantic
  rejection.

Binary layout (Devicetree Specification v0.4, chapter 5):

    header (40 bytes, big endian)
    memory reservation block  (pairs of u64, terminated by 0,0)
    structure block           (token stream)
    strings block             (NUL-terminated property names)

Structure tokens: FDT_BEGIN_NODE(1), FDT_END_NODE(2), FDT_PROP(3), FDT_NOP(4),
FDT_END(9).
"""

from __future__ import annotations

import struct
from typing import Dict, Iterator, List, Optional, Sequence, Tuple

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

FDT_MAGIC = 0xD00DFEED
FDT_BEGIN_NODE = 0x1
FDT_END_NODE = 0x2
FDT_PROP = 0x3
FDT_NOP = 0x4
FDT_END = 0x9

#: Supported header versions.  v16 and v17 differ only in whether the ``size_dt_*``
#: fields are present; QEMU 11.1.1 emits v17.
SUPPORTED_VERSIONS = (16, 17)

#: Default cell counts used when a node has no ``#address-cells``/``#size-cells``
#: of its own.  Per the specification the root node defaults to 2/1; every other
#: node inherits the value of its parent.
ROOT_DEFAULT_ADDRESS_CELLS = 2
ROOT_DEFAULT_SIZE_CELLS = 1

HEADER_FMT = ">10I"
HEADER_SIZE = struct.calcsize(HEADER_FMT)  # 40


class FdtFormatError(Exception):
    """The artifact is not a well-formed FDT.  Maps to a tool/format ERROR."""


class FdtSemanticError(Exception):
    """The artifact is well-formed but violates a DT addressing/type rule."""


# ---------------------------------------------------------------------------
# Node model
# ---------------------------------------------------------------------------


class Node:
    """A device tree node.

    ``props`` preserves the on-disk property order (important for byte-exact
    round-trips and for teaching that property order is not semantically
    significant, while node order among siblings with equal names is not
    permitted at all).
    """

    __slots__ = ("name", "props", "children", "parent")

    def __init__(self, name: str, parent: Optional["Node"] = None) -> None:
        self.name = name
        self.props: Dict[str, bytes] = {}
        self.children: List["Node"] = []
        self.parent = parent

    # -- structure ---------------------------------------------------------

    @property
    def path(self) -> str:
        if self.parent is None:
            return "/"
        parts: List[str] = []
        node: Optional[Node] = self
        while node is not None and node.parent is not None:
            parts.append(node.name)
            node = node.parent
        return "/" + "/".join(reversed(parts))

    def child(self, name: str) -> Optional["Node"]:
        for c in self.children:
            if c.name == name:
                return c
        return None

    def require_child(self, name: str) -> "Node":
        c = self.child(name)
        if c is None:
            raise FdtSemanticError(f"{self.path}: required child node '{name}' is absent")
        return c

    def children_named(self, base: str) -> List["Node"]:
        """Return children whose node name equals ``base`` or starts with ``base@``."""
        out = []
        for c in self.children:
            if c.name == base or c.name.startswith(base + "@"):
                out.append(c)
        return out

    def walk(self) -> Iterator["Node"]:
        yield self
        for c in self.children:
            yield from c.walk()

    def __repr__(self) -> str:  # pragma: no cover - debugging aid
        return f"<Node {self.path} props={len(self.props)} children={len(self.children)}>"

    # -- properties --------------------------------------------------------

    def has(self, name: str) -> bool:
        return name in self.props

    def raw(self, name: str) -> Optional[bytes]:
        return self.props.get(name)

    def prop_strs(self, name: str) -> List[str]:
        """Decode a string-list property.

        Device tree string properties are NUL-terminated *and* the value is
        NUL-padded, so ``compatible = "arm,pl011", "arm,primecell"`` is stored
        as ``b"arm,pl011\\0arm,primecell\\0"``.  Trailing empty elements are
        dropped; interior empty elements are preserved (they are a real defect).
        """
        raw = self.props.get(name)
        if raw is None:
            raise FdtSemanticError(f"{self.path}: property '{name}' is absent")
        if not raw:
            raise FdtSemanticError(f"{self.path}: property '{name}' is empty")
        parts = raw.split(b"\x00")
        while parts and parts[-1] == b"":
            parts.pop()
        try:
            return [p.decode("utf-8") for p in parts]
        except UnicodeDecodeError as exc:
            raise FdtSemanticError(
                f"{self.path}: property '{name}' is not a valid UTF-8 string list"
            ) from exc

    def prop_str(self, name: str) -> str:
        """First element of a string-list property (the usual lookup key)."""
        strs = self.prop_strs(name)
        if not strs:
            raise FdtSemanticError(f"{self.path}: property '{name}' has no elements")
        return strs[0]

    def prop_cells(self, name: str) -> List[int]:
        """Decode a 32-bit cell array (``<a b c>``)."""
        raw = self.props.get(name)
        if raw is None:
            raise FdtSemanticError(f"{self.path}: property '{name}' is absent")
        if len(raw) % 4 != 0:
            raise FdtSemanticError(
                f"{self.path}: property '{name}' length {len(raw)} is not a multiple of 4 "
                "(not a 32-bit cell array)"
            )
        return list(struct.unpack(">%dI" % (len(raw) // 4), raw))

    def prop_bool(self, name: str) -> bool:
        """A boolean (empty) property."""
        raw = self.props.get(name)
        if raw is None:
            return False
        if raw != b"":
            raise FdtSemanticError(
                f"{self.path}: property '{name}' is declared boolean but carries "
                f"{len(raw)} byte(s) of value"
            )
        return True

    # -- cell context ------------------------------------------------------

    def address_cells(self) -> int:
        if self.has("#address-cells"):
            cells = self.prop_cells("#address-cells")
            if len(cells) != 1:
                raise FdtSemanticError(f"{self.path}: #address-cells must hold exactly 1 cell")
            return cells[0]
        if self.parent is None:
            return ROOT_DEFAULT_ADDRESS_CELLS
        return self.parent.address_cells()

    def size_cells(self) -> int:
        if self.has("#size-cells"):
            cells = self.prop_cells("#size-cells")
            if len(cells) != 1:
                raise FdtSemanticError(f"{self.path}: #size-cells must hold exactly 1 cell")
            return cells[0]
        if self.parent is None:
            return ROOT_DEFAULT_SIZE_CELLS
        return self.parent.size_cells()

    def interrupt_cells(self) -> int:
        if not self.has("#interrupt-cells"):
            raise FdtSemanticError(f"{self.path}: not an interrupt controller (#interrupt-cells absent)")
        cells = self.prop_cells("#interrupt-cells")
        if len(cells) != 1:
            raise FdtSemanticError(f"{self.path}: #interrupt-cells must hold exactly 1 cell")
        return cells[0]

    def is_enabled(self) -> bool:
        """Effective availability.

        ``status`` is absent -> the node is enabled (the specification default).
        ``status = "okay"`` or ``"ok"`` -> enabled.  Everything else
        ("disabled", "reserved", "fail", "fail-sss") -> not available.
        """
        if not self.has("status"):
            return True
        value = self.prop_str("status")
        return value in ("okay", "ok")


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------


def _align4(n: int) -> int:
    return (n + 3) & ~3


class Fdt:
    """A parsed DTB: header metadata + root node + memory reservations."""

    __slots__ = ("version", "last_comp_version", "boot_cpuid_phys",
                 "totalsize", "size_dt_struct", "size_dt_strings",
                 "off_dt_struct", "off_dt_strings", "off_mem_rsvmap",
                 "reservations", "root")

    def __init__(self) -> None:
        self.version = 17
        self.last_comp_version = 16
        self.boot_cpuid_phys = 0
        self.totalsize = 0
        self.size_dt_struct = 0
        self.size_dt_strings = 0
        self.off_dt_struct = 0
        self.off_dt_strings = 0
        self.off_mem_rsvmap = 0
        self.reservations: List[Tuple[int, int]] = []
        self.root: Optional[Node] = None


def parse_bytes(blob: bytes) -> Fdt:
    """Parse a DTB image into an :class:`Fdt`.

    Raises :class:`FdtFormatError` for anything that is not a well-formed FDT.
    """
    if len(blob) < HEADER_SIZE:
        raise FdtFormatError(f"file is only {len(blob)} byte(s); too short to hold an FDT header")

    (magic, totalsize, off_struct, off_strings, off_rsvmap,
     version, last_comp_version, boot_cpuid, size_strings, size_struct) = struct.unpack(
        HEADER_FMT, blob[:HEADER_SIZE])

    if magic != FDT_MAGIC:
        raise FdtFormatError(
            f"bad FDT magic 0x{magic:08x} (expected 0x{FDT_MAGIC:08x}) -- not a device tree blob")

    if version < 16 or version > 17:
        # v17 is the last version and is backwards compatible with v16.
        raise FdtFormatError(f"unsupported FDT version {version} (expected 16 or 17)")

    if totalsize < HEADER_SIZE:
        raise FdtFormatError(f"header totalsize {totalsize} is smaller than the header itself")

    # A truncated file is a format error, but a file *larger* than totalsize is
    # tolerated: QEMU's ``dumpdtb`` writes the whole reserved region.
    if totalsize > len(blob):
        raise FdtFormatError(
            f"header totalsize {totalsize} exceeds file length {len(blob)} -- truncated DTB")

    for label, off, size in (("structure", off_struct, size_struct),
                             ("strings", off_strings, size_strings),
                             ("reservation map", off_rsvmap, 0)):
        if off < HEADER_SIZE or off > totalsize:
            raise FdtFormatError(f"{label} block offset {off} is outside the blob")
        if size and off + size > totalsize:
            raise FdtFormatError(
                f"{label} block (offset {off}, size {size}) extends past totalsize {totalsize}")

    fdt = Fdt()
    fdt.version = version
    fdt.last_comp_version = last_comp_version
    fdt.boot_cpuid_phys = boot_cpuid
    fdt.totalsize = totalsize
    fdt.off_dt_struct = off_struct
    fdt.off_dt_strings = off_strings
    fdt.off_mem_rsvmap = off_rsvmap
    fdt.size_dt_struct = size_struct
    fdt.size_dt_strings = size_strings

    # --- memory reservation block (u64 pairs, terminated by a 0,0 pair) ----
    pos = off_rsvmap
    while True:
        if pos + 16 > totalsize:
            raise FdtFormatError("memory reservation block is not terminated before end of blob")
        addr, size = struct.unpack(">QQ", blob[pos:pos + 16])
        pos += 16
        if addr == 0 and size == 0:
            break
        fdt.reservations.append((addr, size))

    # --- structure block ---------------------------------------------------
    strings = blob[off_strings:off_strings + size_strings]
    struct_end = off_struct + size_struct
    pos = off_struct
    root: Optional[Node] = None
    stack: List[Node] = []
    saw_end = False

    def read_cstr(at: int, limit: int) -> Tuple[str, int]:
        end = blob.find(b"\x00", at, limit)
        if end < 0:
            raise FdtFormatError("unterminated node name in structure block")
        try:
            text = blob[at:end].decode("utf-8")
        except UnicodeDecodeError as exc:
            raise FdtFormatError("node name is not valid UTF-8") from exc
        return text, _align4(end + 1)

    while pos < struct_end:
        if pos + 4 > struct_end:
            raise FdtFormatError("structure block ends in the middle of a token")
        (token,) = struct.unpack(">I", blob[pos:pos + 4])
        pos += 4

        if token == FDT_BEGIN_NODE:
            name, pos = read_cstr(pos, struct_end)
            parent = stack[-1] if stack else None
            node = Node(name, parent)
            if parent is None:
                if root is not None:
                    raise FdtFormatError("structure block contains more than one root node")
                root = node
            else:
                for existing in parent.children:
                    if existing.name == name:
                        raise FdtSemanticError(
                            f"{parent.path}: duplicate sibling node name '{name}' "
                            "(node names must be unique among siblings)")
                parent.children.append(node)
            stack.append(node)

        elif token == FDT_END_NODE:
            if not stack:
                raise FdtFormatError("FDT_END_NODE without a matching FDT_BEGIN_NODE")
            stack.pop()

        elif token == FDT_PROP:
            if pos + 8 > struct_end:
                raise FdtFormatError("truncated FDT_PROP header")
            length, nameoff = struct.unpack(">II", blob[pos:pos + 8])
            pos += 8
            if nameoff >= len(strings):
                raise FdtFormatError(f"property name offset {nameoff} is outside the strings block")
            if pos + length > struct_end:
                raise FdtFormatError("property value extends past the structure block")
            end = strings.find(b"\x00", nameoff)
            if end < 0:
                raise FdtFormatError("unterminated property name in strings block")
            try:
                prop_name = strings[nameoff:end].decode("utf-8")
            except UnicodeDecodeError as exc:
                raise FdtFormatError("property name is not valid UTF-8") from exc
            if not stack:
                raise FdtFormatError("FDT_PROP outside of any node")
            value = blob[pos:pos + length]
            pos = _align4(pos + length)
            node = stack[-1]
            if prop_name in node.props:
                raise FdtSemanticError(
                    f"{node.path}: duplicate property '{prop_name}' "
                    "(a node may define each property at most once)")
            node.props[prop_name] = value

        elif token == FDT_NOP:
            continue

        elif token == FDT_END:
            saw_end = True
            break

        else:
            raise FdtFormatError(f"unknown structure token 0x{token:x}")

    if not saw_end:
        raise FdtFormatError("structure block has no FDT_END token")
    if stack:
        raise FdtFormatError(
            f"structure block ended with {len(stack)} unclosed node(s): "
            + ", ".join(n.path for n in stack))
    if root is None:
        raise FdtFormatError("structure block contains no root node")

    fdt.root = root
    return fdt


def parse_file(path: str) -> Fdt:
    with open(path, "rb") as handle:
        return parse_bytes(handle.read())


# ---------------------------------------------------------------------------
# Serialisation
# ---------------------------------------------------------------------------


def _iter_props(node: Node) -> Iterator[Tuple[str, bytes]]:
    for name, value in node.props.items():
        yield name, value


def serialise(fdt: Fdt) -> bytes:
    """Rebuild a canonical-layout DTB from a parsed :class:`Fdt`.

    The node order, sibling order, property order and property values are
    preserved exactly; only the *layout* is canonicalised (compact header,
    reservation block, structure block, strings block).  This is what turns a
    QEMU ``dumpdtb`` image (which pads ``totalsize`` to the reserved region)
    into a portable, comparable artifact.
    """
    if fdt.root is None:
        raise FdtFormatError("cannot serialise an FDT without a root node")

    strings: List[str] = []
    string_index: Dict[str, int] = {}
    string_bytes = bytearray()

    def intern(name: str) -> int:
        if name in string_index:
            return string_index[name]
        offset = len(string_bytes)
        string_index[name] = offset
        string_bytes.extend(name.encode("utf-8"))
        string_bytes.append(0)
        strings.append(name)
        return offset

    body = bytearray()

    def emit_node(node: Node) -> None:
        body.extend(struct.pack(">I", FDT_BEGIN_NODE))
        name = node.name.encode("utf-8")
        body.extend(name)
        body.append(0)
        while len(body) % 4:
            body.append(0)
        for prop_name, value in _iter_props(node):
            nameoff = intern(prop_name)
            body.extend(struct.pack(">III", FDT_PROP, len(value), nameoff))
            body.extend(value)
            while len(body) % 4:
                body.append(0)
        for child in node.children:
            emit_node(child)
        body.extend(struct.pack(">I", FDT_END_NODE))

    emit_node(fdt.root)
    body.extend(struct.pack(">I", FDT_END))

    rsvmap = bytearray()
    for addr, size in fdt.reservations:
        rsvmap.extend(struct.pack(">QQ", addr, size))
    rsvmap.extend(struct.pack(">QQ", 0, 0))

    off_rsvmap = HEADER_SIZE
    off_struct = off_rsvmap + len(rsvmap)
    off_strings = off_struct + len(body)
    totalsize = off_strings + len(string_bytes)
    totalsize = (totalsize + 7) & ~7

    header = struct.pack(
        HEADER_FMT,
        FDT_MAGIC, totalsize, off_struct, off_strings, off_rsvmap,
        fdt.version, fdt.last_comp_version, fdt.boot_cpuid_phys,
        len(string_bytes), len(body),
    )
    out = bytearray(header)
    out.extend(rsvmap)
    out.extend(body)
    out.extend(string_bytes)
    out.extend(b"\x00" * (totalsize - len(out)))
    return bytes(out)


def write_file(fdt: Fdt, path: str) -> None:
    with open(path, "wb") as handle:
        handle.write(serialise(fdt))


# ---------------------------------------------------------------------------
# Resource decoding helpers (the heart of the module's mental model)
# ---------------------------------------------------------------------------


def decode_reg(node: Node) -> List[Tuple[int, int]]:
    """Interpret ``reg`` under the *parent's* addressing rules.

    Returns a list of ``(address, size)`` pairs.  Raises
    :class:`FdtSemanticError` when the cell count does not match
    ``parent.#address-cells + parent.#size-cells`` -- the single most common
    real-world device tree defect, and the mechanism behind fault F11.
    """
    if node.parent is None:
        raise FdtSemanticError(f"{node.path}: the root node has no parent addressing context")
    a_cells = node.parent.address_cells()
    s_cells = node.parent.size_cells()
    if a_cells + s_cells == 0:
        raise FdtSemanticError(
            f"{node.path}: parent {node.parent.path} declares 0 address and 0 size cells")
    cells = node.prop_cells("reg")
    stride = a_cells + s_cells
    if stride == 0 or len(cells) % stride != 0:
        raise FdtSemanticError(
            f"{node.path}: 'reg' holds {len(cells)} cell(s) which is not a multiple of "
            f"parent {node.parent.path} #address-cells({a_cells}) + #size-cells({s_cells}) = {stride}")
    entries: List[Tuple[int, int]] = []
    for base in range(0, len(cells), stride):
        address = 0
        for cell in cells[base:base + a_cells]:
            address = (address << 32) | cell
        size = 0
        for cell in cells[base + a_cells:base + stride]:
            size = (size << 32) | cell
        entries.append((address, size))
    return entries


def tree_root(node: Node) -> Node:
    """Walk up to the root of the tree containing ``node``."""
    while node.parent is not None:
        node = node.parent
    return node


def resolve_phandle(root: Node, phandle: int) -> Optional[Node]:
    """Resolve a phandle value.

    Phandles are unique across the *whole* tree, so resolution is always
    performed against the root regardless of where the reference appears.  A
    node that merely has a numeric property is never mistaken for a phandle
    target: only the ``phandle`` property declares one.
    """
    for node in root.walk():
        if node.has("phandle"):
            try:
                value = node.prop_cells("phandle")
            except FdtSemanticError:
                continue
            if len(value) == 1 and value[0] == phandle:
                return node
    return None


def interrupt_parent_of(node: Node) -> Optional[Node]:
    """Resolve the interrupt controller that owns this node's interrupt specifier.

    ``interrupt-parent`` is an *inherited* property: a node without its own
    takes the value of its nearest ancestor.  The QEMU ``virt`` machine sets
    ``interrupt-parent`` on the root node and on ``/platform-bus@c000000``, so
    an implementation that only looks at the node itself gets this wrong.
    """
    if node.has("interrupt-parent"):
        cells = node.prop_cells("interrupt-parent")
        if len(cells) != 1:
            raise FdtSemanticError(f"{node.path}: interrupt-parent must hold exactly 1 cell")
        target = resolve_phandle(tree_root(node), cells[0])
        if target is None:
            raise FdtSemanticError(
                f"{node.path}: interrupt-parent phandle <0x{cells[0]:x}> does not resolve")
        return target
    if node.parent is not None:
        return interrupt_parent_of(node.parent)
    return None


def decode_interrupts(node: Node) -> List[List[int]]:
    """Interpret ``interrupts`` with the *interrupt parent's* ``#interrupt-cells``.

    ``interrupts`` is not self-describing: the number of cells per specifier is
    defined by the interrupt controller the node points at (directly, or by
    inheritance).  Reading it without resolving the parent is the classic
    mistake this module is designed to prevent.
    """
    parent = interrupt_parent_of(node)
    if parent is None:
        raise FdtSemanticError(f"{node.path}: no interrupt parent is reachable")
    n = parent.interrupt_cells()
    if n == 0:
        raise FdtSemanticError(f"{parent.path}: #interrupt-cells is zero")
    cells = node.prop_cells("interrupts")
    if len(cells) % n != 0:
        raise FdtSemanticError(
            f"{node.path}: 'interrupts' holds {len(cells)} cell(s) which is not a multiple of "
            f"#interrupt-cells({n}) from {parent.path}")
    return [cells[i:i + n] for i in range(0, len(cells), n)]


def canonical_dump(fdt: Fdt, *, skip_props: Sequence[str] = ()) -> List[str]:
    """A deterministic, order-independent textual rendering of a tree.

    Used for *semantic* equality between two DTBs (for example before/after a
    ``dtb -> dts -> dtb`` round trip).  Property order inside a node is
    normalised because the specification does not give it meaning; node order
    is preserved because sibling node names must be unique anyway.

    ``skip_props`` removes properties that a given producer is allowed to
    randomise -- notably QEMU's ``chosen/rng-seed`` and ``chosen/kaslr-seed``.
    """
    lines: List[str] = []

    def render(node: Node) -> None:
        lines.append(f"NODE {node.path}")
        for name in sorted(node.props):
            if name in skip_props:
                continue
            lines.append(f"  PROP {name} = {node.props[name].hex()}")
        for child in node.children:
            render(child)

    if fdt.root is None:
        raise FdtFormatError("empty FDT")
    render(fdt.root)
    lines.append(f"RSVMAP {fdt.reservations}")
    return lines


def semantic_diff(a: Fdt, b: Fdt, *, skip_props: Sequence[str] = ()) -> List[str]:
    """Return human-readable differences between two trees (empty == equal)."""
    import difflib

    da = canonical_dump(a, skip_props=skip_props)
    db = canonical_dump(b, skip_props=skip_props)
    if da == db:
        return []
    return [line for line in difflib.unified_diff(da, db, "left", "right", lineterm="")]


# ---------------------------------------------------------------------------
# CLI (small inspection helper; the real tooling lives in sibling scripts)
# ---------------------------------------------------------------------------


def _main(argv: Sequence[str]) -> int:
    import argparse
    import sys

    parser = argparse.ArgumentParser(description="Minimal FDT inspector (P3-M05)")
    parser.add_argument("dtb", help="device tree blob to inspect")
    parser.add_argument("--path", help="print only this node path")
    parser.add_argument("--serialise", help="rewrite the tree to this canonical-layout DTB")
    parser.add_argument("--skip-props", default="rng-seed,kaslr-seed",
                        help="comma-separated property names excluded from --dump")
    parser.add_argument("--dump", action="store_true", help="print the canonical semantic dump")
    args = parser.parse_args(argv)

    try:
        fdt = parse_file(args.dtb)
    except FdtFormatError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    except FdtSemanticError as exc:
        print(f"REJECT: {exc}", file=sys.stderr)
        return 1

    assert fdt.root is not None
    if args.path:
        node = fdt.root
        if args.path != "/":
            for part in args.path.strip("/").split("/"):
                node = node.child(part)  # type: ignore[assignment]
                if node is None:
                    print(f"REJECT: no such node: {args.path}", file=sys.stderr)
                    return 1
        print(f"NODE {node.path}")
        for name, value in node.props.items():
            print(f"  {name} = {value.hex()}")
        for child in node.children:
            print(f"  CHILD {child.name}")
    if args.dump:
        for line in canonical_dump(fdt, skip_props=tuple(args.skip_props.split(","))):
            print(line)
    if args.serialise:
        write_file(fdt, args.serialise)
        print(f"[OK] wrote canonical-layout DTB: {args.serialise}")
    if not (args.path or args.dump or args.serialise):
        print(f"FDT version={fdt.version} totalsize={fdt.totalsize} "
              f"reservations={len(fdt.reservations)} nodes={sum(1 for _ in fdt.root.walk())}")
    return 0


if __name__ == "__main__":  # pragma: no cover
    import sys

    raise SystemExit(_main(sys.argv[1:]))
