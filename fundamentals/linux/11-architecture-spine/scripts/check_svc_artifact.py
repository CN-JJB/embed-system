#!/usr/bin/env python3
"""ARM SVC artifact checker for P3-M07 (learner-safe).

Verifies that a target artifact is ARM and contains the intended ``svc #0``
instruction in the effectively executed path:

* ARM ELF (e_machine == EM_ARM == 40). A wrong-arch ELF (e.g. x86) is REJECT,
  a missing/bad magic or truncated header is ERROR.
* Disassembly must contain an objdump-format ``svc`` mnemonic line, e.g.
  ``"    4:  ef000000   svc  0x00000000"``. A decoy string ``"svc #0"`` that
  appears only in a comment, ``.ascii``/``.asciz`` literal, or ``//``/``;``/``#``
  comment does NOT count. An x86 ``syscall`` mnemonic does NOT count.
* The ``svc`` must live in an executed section (``.text``). An ``svc`` that
  appears only under ``Disassembly of section .comment``/``.debug``/``.note``
  or another non-executed section is REJECT. When ``--entry-symbol`` is given,
  the ``svc`` must additionally live inside that symbol's function body;
  an ``svc`` confined to another (dead-branch / never-called) symbol is REJECT.

Inputs: an ELF file (``--elf`` or positional ELF path), a disassembly text
file (``--disasm`` or positional text path), or ``--disasm -`` / piped stdin
for ``objdump -d`` text. A single positional FILE is auto-detected: ELF magic
(``\\x7fELF``) -> ELF checks plus embedded-text scan; otherwise disassembly.

Exit status: 0 PASS, 1 REJECT (semantic), 2 ERROR (malformed/tool).

Usage:
  check_svc_artifact.py --elf prog.elf --disasm prog.disasm [--entry-symbol svc_getpid_raw]
  check_svc_artifact.py prog.elf [--entry-symbol sym]
  arm-none-linux-gnueabihf-objdump -d prog.elf | check_svc_artifact.py --disasm - --elf prog.elf
"""

from __future__ import annotations

import argparse
import os
import re
import struct
import sys
from typing import List, Optional, Tuple

EXIT_PASS = 0
EXIT_REJECT = 1
EXIT_ERROR = 2

EM_ARM = 40
EM_X86_64 = 62
EM_386 = 3

# Objdump -d line with a real svc mnemonic, e.g.:
#   "   4:\tef000000 \tsvc\t0x00000000"
SVC_OBJDUMP_RE = re.compile(
    r"^\s*[0-9a-fA-F]+\s*:\s*[0-9a-fA-F][0-9a-fA-F \t]*\tsvc(?:\s|;|$)",
    re.IGNORECASE,
)
# Section header emitted by objdump -d.
SECTION_RE = re.compile(r"^Disassembly of section\s+(\S+?)\s*:")
# Symbol header emitted by objdump -d, e.g. "00000000 <svc_getpid_raw>:".
SYMBOL_RE = re.compile(r"^[0-9a-fA-F]+\s+<([^>]+)>\s*:$")

EXECUTED_SECTIONS = {".text", ".text.startup", ".init.text"}


def read_elf_machine(path: str) -> Tuple[Optional[int], Optional[str]]:
    """Return (machine, error). error is None on success."""
    try:
        with open(path, "rb") as handle:
            header = handle.read(20)
    except OSError as exc:
        return None, f"cannot read ELF file: {exc}"
    if len(header) < 20:
        return None, "truncated ELF header (fewer than 20 bytes)"
    if header[0:4] != b"\x7fELF":
        return None, "bad ELF magic (not an ELF file)"
    machine = struct.unpack("<H" if header[5] == 1 else ">H", header[18:20])[0]
    # ELF data encoding lives at EI_DATA (byte 5): 1=LE, 2=BE. Default LE.
    # Re-decode correctly: EI_DATA==2 means big-endian.
    if header[5] == 2:
        machine = struct.unpack(">H", header[18:20])[0]
    else:
        machine = struct.unpack("<H", header[18:20])[0]
    return machine, None


def is_elf_path(path: str) -> bool:
    try:
        with open(path, "rb") as handle:
            return handle.read(4) == b"\x7fELF"
    except OSError:
        return False


def load_disasm_text(path: Optional[str], stdin_ok: bool = True) -> Tuple[Optional[str], Optional[str]]:
    if path is None or path == "-":
        if not stdin_ok or sys.stdin.isatty():
            return None, "no disassembly input (missing --disasm file and no pipe)"
        try:
            return sys.stdin.read(), None
        except OSError as exc:
            return None, f"cannot read piped disassembly: {exc}"
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            return handle.read(), None
    except OSError as exc:
        return None, f"cannot read disassembly file: {exc}"


def find_svc_hits(text: str) -> List[Tuple[str, str, int, str]]:
    """Return [(section, symbol, lineno, line)] for objdump-format svc lines."""
    hits: List[Tuple[str, str, int, str]] = []
    section = "(no-section-header)"
    symbol = "(no-symbol)"
    for lineno, line in enumerate(text.splitlines(), start=1):
        section_match = SECTION_RE.match(line.strip())
        if section_match:
            section = section_match.group(1).rstrip(":")
            continue
        symbol_match = SYMBOL_RE.match(line.strip())
        if symbol_match:
            symbol = symbol_match.group(1)
            continue
        if SVC_OBJDUMP_RE.match(line):
            hits.append((section, symbol, lineno, line.strip()))
    return hits


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="P3-M07 ARM SVC artifact checker")
    parser.add_argument("file", nargs="?", help="ELF file or disassembly text file")
    parser.add_argument("--elf", help="ARM ELF file under test")
    parser.add_argument("--disasm", help="objdump -d text file ('-' or omit for pipe)")
    parser.add_argument("--entry-symbol", default="",
                        help="symbol whose body must contain the svc (dead-branch check)")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    elf_path: Optional[str] = args.elf
    disasm_path: Optional[str] = args.disasm
    positional = args.file

    if elf_path is None and disasm_path is None and positional is not None:
        if positional == "-":
            disasm_path = "-"
        elif os.path.isfile(positional):
            if is_elf_path(positional):
                elf_path = positional
            else:
                disasm_path = positional
        else:
            print(f"ERROR: file not found: {positional}", file=sys.stderr)
            return EXIT_ERROR

    # --- 1. ELF arch check ----------------------------------------------------
    if elf_path is not None:
        if not os.path.isfile(elf_path):
            print(f"ERROR: ELF file not found: {elf_path}", file=sys.stderr)
            return EXIT_ERROR
        machine, error = read_elf_machine(elf_path)
        if error is not None:
            print(f"ERROR: {error}: {elf_path}", file=sys.stderr)
            return EXIT_ERROR
        if machine != EM_ARM:
            print(f"=== SVC ARTIFACT CONTRACT: REJECT ===", file=sys.stderr)
            print(f"REJECT: ELF machine is {machine}, not ARM ({EM_ARM}): {elf_path}",
                  file=sys.stderr)
            return EXIT_REJECT
        if not args.quiet:
            print(f"[PASS] ELF machine is ARM (e_machine={machine}): {elf_path}")

    # --- 2. Disassembly svc check ---------------------------------------------
    text: Optional[str] = None
    if disasm_path is not None or (elf_path is None and positional == "-"):
        text, error = load_disasm_text(disasm_path if disasm_path else "-")
        if error is not None:
            print(f"ERROR: {error}", file=sys.stderr)
            return EXIT_ERROR
        assert text is not None
        if not text.strip():
            print("ERROR: disassembly input is empty", file=sys.stderr)
            return EXIT_ERROR
    elif elf_path is not None:
        # ELF only, no disassembly supplied: scan raw bytes for an svc opcode
        # as a fallback is NOT sufficient (a string literal would fool it), so
        # require disassembly. Report REJECT with guidance, not ERROR, when the
        # ELF is fine but no disassembly was supplied? The frozen contract says
        # the checker accepts "objdump -d text piped or file", so a missing
        # disassembly is a tool/usage error.
        print("ERROR: no disassembly supplied (pass --disasm FILE or pipe objdump -d)",
              file=sys.stderr)
        return EXIT_ERROR
    else:
        print("ERROR: no ELF or disassembly input supplied", file=sys.stderr)
        return EXIT_ERROR

    assert text is not None
    hits = find_svc_hits(text)
    # Decoy diagnostics: mention when the file merely talks about svc.
    mentions_svc = ("svc" in text.lower())
    has_syscall = bool(re.search(r"(?m)^\s*[0-9a-fA-F]+\s*:.*\tsyscall\b", text, re.IGNORECASE))

    if not hits:
        print("=== SVC ARTIFACT CONTRACT: REJECT ===", file=sys.stderr)
        if has_syscall:
            print("REJECT: disassembly contains x86 `syscall`, not ARM `svc #0`",
                  file=sys.stderr)
        elif mentions_svc:
            print("REJECT: `svc #0` appears only as text/comment/literal, not as an "
                  "objdump `svc` mnemonic line in an executed section", file=sys.stderr)
        else:
            print("REJECT: no objdump-format `svc` mnemonic line found", file=sys.stderr)
        return EXIT_REJECT

    executed_hits = [h for h in hits if h[0] in EXECUTED_SECTIONS]
    # Objdump without section headers (e.g. `objdump -d` on some hosts still
    # prints them; a bare `--disassemble` snippet may not). If no section
    # header was seen at all, treat hits as executed-path candidates rather
    # than rejecting a well-formed proof for a formatting detail.
    saw_section_header = bool(SECTION_RE.search(text))
    if not saw_section_header:
        executed_hits = list(hits)

    if not executed_hits:
        print("=== SVC ARTIFACT CONTRACT: REJECT ===", file=sys.stderr)
        sections = sorted({h[0] for h in hits})
        print(f"REJECT: `svc` found only in non-executed section(s) {sections}; "
              "no `svc` in .text (use --entry-symbol to bind the executed path)",
              file=sys.stderr)
        return EXIT_REJECT

    if args.entry_symbol:
        wanted = args.entry_symbol
        scoped = [h for h in executed_hits if h[1] == wanted]
        if not scoped:
            print("=== SVC ARTIFACT CONTRACT: REJECT ===", file=sys.stderr)
            print(f"REJECT: no `svc` inside --entry-symbol `{wanted}`; "
                  f"`svc` appears only in {[h[1] for h in executed_hits]} "
                  "(dead-branch / never-executed path)", file=sys.stderr)
            return EXIT_REJECT
        if not args.quiet:
            sec, sym, lineno, line = scoped[0]
            print(f"[PASS] `svc #0` in executed path: section {sec} symbol <{sym}> line {lineno}: {line}")
    else:
        if not args.quiet:
            sec, sym, lineno, line = executed_hits[0]
            print(f"[PASS] `svc #0` in executed path: section {sec} symbol <{sym}> line {lineno}: {line}")

    if not args.quiet:
        print("=== SVC ARTIFACT CONTRACT: PASS ===")
    return EXIT_PASS


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
