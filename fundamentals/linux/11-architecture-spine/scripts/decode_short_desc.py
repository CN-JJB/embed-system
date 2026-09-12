#!/usr/bin/env python3
"""ARMv7 short-descriptor decoder for P3-M07 (learner-safe).

Frozen assumptions (must appear in output as assumption_stamp):
  TRE=1, PRRR=0xff0a81a8, NMRR=0x40e040e0, AFE=0, DACR=Client.

Decodes (level, word) pairs:
  L1 bits[1:0]: 00 fault -> REJECT, 01 page table -> PASS,
                10 section (bit18=0) / supersection (bit18=1) -> decode,
                11 PXN-section-or-reserved -> REJECT (never ACCEPT as section).
  L2 bits[1:0]: 00 fault -> REJECT, 01 large page -> REJECT (outside M07 scope),
                0b1x small page -> decode, bit0 IS XN (0b10 XN=0, 0b11 XN=1).

Field positions (verified against goldens):
  L1 section: TEX[2:0]=bits[14:12], AP[1:0]=bits[11:10], APX=bit15,
              domain=bits[8:5], XN=bit4, C=bit3, B=bit2, S=bit16,
              nG=bit17, NS=bit19, bit18 selects section(0)/supersection(1).
  L2 small page: TEX[2:0]=bits[8:6], AP[1:0]=bits[5:4], APX=bit9,
                 C=bit3, B=bit2, S=bit10, nG=bit11, XN=bit0.

AP table (SCTLR.AFE=0, ARM DDI 0406C Table B3-8):
  000 no access -> REJECT, 001 PL1-RW/PL0-none -> PASS,
  010 PL1-RW/PL0-RO -> PASS, 011 PL1-RW/PL0-RW -> PASS,
  100 Reserved -> REJECT, 101 PL1-RO/PL0-none -> PASS,
  110 PL1-RO/PL0-RO -> PASS, 111 PL1-RO/PL0-RO -> PASS.

n={TEX0,C,B} under frozen PRRR/NMRR (TEX[2:1] ignored by HW under TRE=1):
  111 Normal WBWA -> PASS, 011 Normal WB-noWA -> PASS,
  001 Normal NC -> PASS, 000 Strongly-Ordered -> PASS,
  100 Device -> PASS, 110 IMPLEMENTATION-DEFINED -> REJECT,
  010/101 reserved under this PRRR/NMRR -> REJECT (documented assumption).
S=0 on Normal is still Normal (UP policy); decoder never hard-requires S=1.

Exit status:
  0 PASS   -- well-formed descriptor(s), all invariants hold
  1 REJECT -- well-formed but semantically invalid / type mismatch
  2 ERROR  -- malformed input / tool failure (bad hex, truncated JSON, etc.)

Usage:
  decode_short_desc.py --level 1 --word 0x4001140E [--expect Normal|Device|SO]
  decode_short_desc.py DESCRIPTOR.json [--expect ...] [--json] [--quiet]
  JSON may be a single {"level":1,"word":"0x..."} object, or
  {"entries":[...]} (taught fixture shape), or {"descriptors":[...]}
  (assessment shape). Each entry may carry "raw"/"word", "level"/"Level",
  and optional "expect"/"claimed"/"memory_type" for type-match checking.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any, Dict, List, Optional, Tuple

EXIT_PASS = 0
EXIT_REJECT = 1
EXIT_ERROR = 2

ASSUMPTION_STAMP = "TRE=1 PRRR=0xff0a81a8 NMRR=0x40e040e0 AFE=0 DACR=Client"

AP_MEANING = {
    0b000: "no access (fault)",
    0b001: "PL1 RW / PL0 none",
    0b010: "PL1 RW / PL0 RO",
    0b011: "PL1 RW / PL0 RW",
    0b100: "Reserved (Table B3-8)",
    0b101: "PL1 RO / PL0 none",
    0b110: "PL1 RO / PL0 RO",
    0b111: "PL1 RO / PL0 RO",
}

N_MAP = {
    0b111: ("Normal", "Normal, Write-Back Write-Allocate (WBWA)"),
    0b011: ("Normal", "Normal, Write-Back no Write-Allocate"),
    0b001: ("Normal", "Normal, Non-cacheable"),
    0b000: ("SO", "Strongly-Ordered"),
    0b100: ("Device", "Device, Shareable"),
}


def parse_word(text: str) -> int:
    s = text.strip()
    try:
        if s.lower().startswith("0x"):
            return int(s, 16)
        return int(s, 0)
    except ValueError:
        raise ValueError(f"malformed descriptor word: {text!r}")


def norm_level(value: Any) -> int:
    if isinstance(value, int):
        if value in (1, 2):
            return value
        raise ValueError(f"bad level: {value!r}")
    s = str(value).strip().upper()
    if s in ("1", "L1", "LEVEL1"):
        return 1
    if s in ("2", "L2", "LEVEL2"):
        return 2
    raise ValueError(f"bad level: {value!r}")


def norm_expect(value: Any) -> str:
    s = str(value).strip().lower()
    if "normal" in s:
        return "Normal"
    if "device" in s:
        return "Device"
    if s in ("so", "strongly-ordered", "strongly_ordered", "strongly ordered"):
        return "SO"
    if s in ("accept", "pass"):
        return "ANY-VALID"
    if "reject" in s:
        return "EXPECT-REJECT"
    raise ValueError(f"bad expect value: {value!r}")


def decode_one(level: int, word: int) -> Tuple[bool, str, Dict[str, Any]]:
    """Return (ok, detail, fields). ok=False means semantic REJECT."""
    u = word & 0xFFFFFFFF
    cls = u & 0x3
    if level == 1:
        if cls == 0b00:
            return False, "L1 0b00 Fault: no mapping", {"class": "fault"}
        if cls == 0b01:
            base = u & 0xFFFFFC00
            domain = (u >> 5) & 0xF
            return True, (
                f"L1 0b01 page-table pointer base=0x{base:08X} domain={domain} "
                "(no memory type at L1)"
            ), {"class": "pagetable", "base": f"0x{base:08X}", "domain": domain}
        if cls == 0b11:
            return False, (
                "L1 0b11 PXN-section-or-reserved: frozen Linux never emits it; "
                "REJECT (never ACCEPT as section)"
            ), {"class": "reserved-11"}
        # cls == 0b10 section / supersection
        bit18 = (u >> 18) & 1
        if bit18 == 1:
            return False, (
                "L1 supersection (bit18=1, 16MB): outside M07 taught scope; REJECT"
            ), {"class": "supersection"}
        base = u & 0xFFF00000
        tex = (u >> 12) & 0x7
        ap = (u >> 10) & 0x3
        apx = (u >> 15) & 0x1
        ap3 = (apx << 2) | ap
        domain = (u >> 5) & 0xF
        xn = (u >> 4) & 0x1
        c = (u >> 3) & 0x1
        b = (u >> 2) & 0x1
        s = (u >> 16) & 0x1
        ng = (u >> 17) & 0x1
        ns = (u >> 19) & 0x1
        tex0 = tex & 0x1
        n = (tex0 << 2) | (c << 1) | b
        fields: Dict[str, Any] = {
            "class": "section", "base": f"0x{base:08X}", "size": "1MB",
            "TEX": f"{tex:03b}", "AP": f"{ap3:03b}", "C": c, "B": b,
            "n": f"{n:03b}", "S": s, "nG": ng, "XN": xn, "NS": ns,
            "domain": domain,
        }
        if ap3 == 0b100:
            return False, (
                f"L1 section AP=100 Reserved (Table B3-8); {AP_MEANING[ap3]}; REJECT"
            ), fields
        if ap3 == 0b000:
            return False, "L1 section AP=000 no access (fault); REJECT", fields
        if n == 0b110:
            return False, (
                f"L1 section n=110 IMPLEMENTATION-DEFINED (TEX0={tex0},C={c},B={b}); REJECT"
            ), fields
        if n not in N_MAP:
            return False, (
                f"L1 section n={n:03b} reserved under frozen PRRR/NMRR; REJECT"
            ), fields
        cat, desc = N_MAP[n]
        fields["memtype"] = cat
        fields["memtype_detail"] = desc
        detail = (
            f"L1 section base={fields['base']} AP={ap3:03b} ({AP_MEANING[ap3]}) "
            f"TEX={tex:03b} C={c} B={b} n={n:03b} -> {desc} "
            f"S={s} XN={xn} nG={ng} domain={domain}"
        )
        return True, detail, fields
    else:
        if cls == 0b00:
            return False, "L2 0b00 Fault: no mapping", {"class": "fault"}
        if cls == 0b01:
            return False, (
                "L2 0b01 large page: frozen Linux never emits it; "
                "outside M07 small-page scope; REJECT"
            ), {"class": "large-page"}
        # 0b10 / 0b11 small page; bit0 IS XN
        xn = u & 0x1
        base = u & 0xFFFFF000
        tex = (u >> 6) & 0x7
        ap = (u >> 4) & 0x3
        apx = (u >> 9) & 0x1
        ap3 = (apx << 2) | ap
        c = (u >> 3) & 0x1
        b = (u >> 2) & 0x1
        s = (u >> 10) & 0x1
        ng = (u >> 11) & 0x1
        tex0 = tex & 0x1
        n = (tex0 << 2) | (c << 1) | b
        fields = {
            "class": "small-page", "base": f"0x{base:08X}", "size": "4KB",
            "TEX": f"{tex:03b}", "AP": f"{ap3:03b}", "C": c, "B": b,
            "n": f"{n:03b}", "S": s, "nG": ng, "XN": xn,
        }
        if ap3 == 0b100:
            return False, (
                f"L2 small page AP=100 Reserved (Table B3-8); REJECT"
            ), fields
        if ap3 == 0b000:
            return False, "L2 small page AP=000 no access (fault); REJECT", fields
        if n == 0b110:
            return False, (
                f"L2 small page n=110 IMPLEMENTATION-DEFINED (TEX0={tex0},C={c},B={b}); REJECT"
            ), fields
        if n not in N_MAP:
            return False, (
                f"L2 small page n={n:03b} reserved under frozen PRRR/NMRR; REJECT"
            ), fields
        cat, desc = N_MAP[n]
        fields["memtype"] = cat
        fields["memtype_detail"] = desc
        detail = (
            f"L2 small page base={fields['base']} XN={xn} AP={ap3:03b} "
            f"({AP_MEANING[ap3]}) TEX={tex:03b} C={c} B={b} n={n:03b} -> {desc} "
            f"S={s} nG={ng}"
        )
        return True, detail, fields


def collect_entries(obj: Any) -> List[Dict[str, Any]]:
    if isinstance(obj, dict):
        if "descriptors" in obj and isinstance(obj["descriptors"], list):
            return obj["descriptors"]
        if "entries" in obj and isinstance(obj["entries"], list):
            return obj["entries"]
        if "word" in obj or "raw" in obj:
            return [obj]
        raise ValueError("JSON has no 'word'/'raw', 'entries', or 'descriptors' list")
    raise ValueError("top-level JSON must be an object")


def entry_word(entry: Dict[str, Any]) -> str:
    for key in ("word", "raw", "descriptor", "value"):
        if key in entry and entry[key] is not None:
            return str(entry[key])
    raise ValueError(f"entry has no word/raw field: {entry!r}")


def entry_level(entry: Dict[str, Any], default: Optional[int]) -> int:
    for key in ("level", "Level", "LEVEL"):
        if key in entry:
            return norm_level(entry[key])
    if default is not None:
        return default
    raise ValueError(f"entry has no level field: {entry!r}")


def entry_expect(entry: Dict[str, Any]) -> Optional[str]:
    for key in ("expect", "expected", "claimed", "claimed_memtype",
                "memory_type", "memtype", "expected_memtype"):
        if key in entry and entry[key] not in (None, ""):
            try:
                return norm_expect(entry[key])
            except ValueError:
                # Free-form memory_type strings like "Normal, Write-Back..."
                # still carry a Normal/Device/SO category.
                s = str(entry[key]).lower()
                if "normal" in s:
                    return "Normal"
                if "device" in s:
                    return "Device"
                if "strongly" in s or s.strip() == "so":
                    return "SO"
                continue
    for key in ("expected_verdict", "expectedVerdict"):
        if key in entry and entry[key] not in (None, ""):
            s = str(entry[key]).lower()
            if "reject" in s:
                return "EXPECT-REJECT"
            if "accept" in s or "pass" in s:
                return "ANY-VALID"
    return None


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="P3-M07 short-descriptor decoder")
    parser.add_argument("file", nargs="?", help="descriptor JSON file")
    parser.add_argument("--level", help="descriptor level (1 or 2)")
    parser.add_argument("--word", help="descriptor word (hex, e.g. 0x4001140E)")
    parser.add_argument("--expect", help="expected category: Normal|Device|SO")
    parser.add_argument("--json", action="store_true", help="emit JSON report")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    global_expect: Optional[str] = None
    if args.expect:
        try:
            global_expect = norm_expect(args.expect)
        except ValueError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return EXIT_ERROR

    items: List[Tuple[int, str, Optional[str], str]] = []

    if args.word is not None or args.level is not None:
        if args.word is None or args.level is None:
            print("ERROR: --level and --word must be given together", file=sys.stderr)
            return EXIT_ERROR
        try:
            level = norm_level(args.level)
        except ValueError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return EXIT_ERROR
        items.append((level, args.word, global_expect, "cli"))
    elif args.file:
        path = args.file
        if not os.path.isfile(path):
            print(f"ERROR: descriptor file not found: {path}", file=sys.stderr)
            return EXIT_ERROR
        try:
            with open(path, "r", encoding="utf-8") as handle:
                text = handle.read()
            if not text.strip():
                print(f"ERROR: descriptor file is empty: {path}", file=sys.stderr)
                return EXIT_ERROR
            obj = json.loads(text)
        except json.JSONDecodeError as exc:
            print(f"ERROR: descriptor file is not valid JSON: {exc}", file=sys.stderr)
            return EXIT_ERROR
        except OSError as exc:
            print(f"ERROR: cannot read descriptor file: {exc}", file=sys.stderr)
            return EXIT_ERROR
        try:
            entries = collect_entries(obj)
        except ValueError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return EXIT_ERROR
        if not entries:
            print("ERROR: descriptor file contains no entries", file=sys.stderr)
            return EXIT_ERROR
        for index, entry in enumerate(entries):
            if not isinstance(entry, dict):
                print(f"ERROR: entry {index} is not an object", file=sys.stderr)
                return EXIT_ERROR
            # Entries explicitly marked EXPECTED-REJECT in the taught fixture
            # are teaching negatives, not goldens. When a whole fixture file
            # is passed without a per-entry expect override, skip them for the
            # PASS/REJECT verdict but still report them.
            try:
                word_text = entry_word(entry)
            except ValueError as exc:
                print(f"ERROR: {exc}", file=sys.stderr)
                return EXIT_ERROR
            try:
                level = entry_level(entry, None if args.level is None else norm_level(args.level))
            except ValueError as exc:
                print(f"ERROR: {exc}", file=sys.stderr)
                return EXIT_ERROR
            expect = entry_expect(entry)
            if global_expect is not None and expect in (None, "ANY-VALID"):
                expect = global_expect
            label = str(entry.get("id", f"entry{index}"))
            items.append((level, word_text, expect, label))
    else:
        print("ERROR: give --level/--word or a descriptor JSON file", file=sys.stderr)
        return EXIT_ERROR

    results = []
    saw_reject = False
    for level, word_text, expect, label in items:
        try:
            word = parse_word(word_text)
        except ValueError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return EXIT_ERROR
        if word < 0 or word > 0xFFFFFFFF:
            print(f"ERROR: descriptor word out of 32-bit range: {word_text!r}",
                  file=sys.stderr)
            return EXIT_ERROR
        ok, detail, fields = decode_one(level, word)
        verdict = "PASS" if ok else "REJECT"
        # Apply expected-category check. EXPECTED-REJECT entries are reported
        # but do not fail a whole-fixture PASS on their own: the caller selects
        # goldens explicitly. Here a file containing ONLY reject-marked entries
        # still yields REJECT (it is non-canonical), which is what the
        # learner-safe starter check relies on.
        note = ""
        if expect == "EXPECT-REJECT":
            note = " (fixture marks this entry EXPECTED-REJECT)"
            # ok stays as decoded; a decoded REJECT matches the marking.
            if ok:
                # A marking that claims REJECT but decodes valid is itself a
                # mismatch: treat as REJECT so the inconsistency is visible.
                ok = False
                verdict = "REJECT"
                detail += "; fixture marks EXPECTED-REJECT and decode agrees" \
                    if False else "; fixture marks EXPECTED-REJECT but decode is valid: REJECT"
            else:
                detail += "; matches fixture EXPECTED-REJECT marking"
        elif expect in ("Normal", "Device", "SO"):
            if not ok:
                pass  # already REJECT; keep reason
            elif fields.get("memtype") != expect:
                ok = False
                verdict = "REJECT"
                detail += (f"; Normal-vs-Device mismatch: actual "
                           f"{fields.get('memtype')} vs expected {expect}: REJECT")
            else:
                detail += f"; matches expected {expect}"
        results.append({
            "label": label, "level": level,
            "word": f"0x{word:08X}", "ok": ok,
            "verdict": "PASS" if ok else "REJECT",
            "detail": detail, "fields": fields,
        })
        if not ok:
            saw_reject = True

    if args.json:
        print(json.dumps({
            "assumption_stamp": ASSUMPTION_STAMP,
            "results": results,
            "verdict": "REJECT" if saw_reject else "PASS",
        }, indent=2, sort_keys=True))
    elif not args.quiet:
        print("=" * 66)
        print("=== P3-M07 short-descriptor decode ===")
        print(f"=== assumption_stamp: {ASSUMPTION_STAMP}")
        for item in results:
            tag = "PASS" if item["ok"] else "FAIL"
            print(f"[{tag}] {item['label']}: L{item['level']} {item['word']} -- {item['detail']}")
    else:
        # --quiet still emits the stamp so callers can assert its presence.
        print(f"assumption_stamp: {ASSUMPTION_STAMP}")

    # Always ensure the stamp is present even in verbose mode.
    if not args.json and not args.quiet:
        print(f"assumption_stamp: {ASSUMPTION_STAMP}")

    if saw_reject:
        if not args.json and not args.quiet:
            print("=== SHORT-DESC CONTRACT: REJECT ===", file=sys.stderr)
        return EXIT_REJECT
    if not args.json and not args.quiet:
        print("=== SHORT-DESC CONTRACT: PASS ===")
    return EXIT_PASS


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
