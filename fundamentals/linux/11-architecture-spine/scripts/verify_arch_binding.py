#!/usr/bin/env python3
"""User/kernel split reasoning checker for P3-M07 (learner-safe, generic).

Checks a candidate VA-classification artifact against the frozen effective
configuration -- no answer key, no hardcoded VAs:

  frozen: CONFIG_ARM_LPAE=n, CONFIG_VMSPLIT_3G=y,
          PAGE_OFFSET 0xC0000000, TASK_SIZE 0xBF000000.

Rule: user addresses satisfy ``addr < TASK_SIZE`` (0xBF000000);
kernel addresses satisfy ``addr >= PAGE_OFFSET`` (0xC0000000).
The 16 MiB gap [TASK_SIZE, PAGE_OFFSET) is neither (module space); a claim
of user/kernel there is REJECT.

A comment-only claim is REJECT: the effective config FILE must contain the
frozen assignments as effective Kconfig lines (``CONFIG_ARM_LPAE=n`` /
``# CONFIG_ARM_LPAE is not set`` for ``n``, ``CONFIG_VMSPLIT_3G=y`` for ``y``).
A diagnosis that merely mentions "3G/1G" in prose without the effective file
does not pass.

Artifact shapes (generic):
  JSON: {"vas": [{"addr": "0x...", "class": "user"|"kernel"}, ...]}
        or {"addresses": [...]}, or a bare list [...]
  text: one ``<addr> <user|kernel>`` pair per line ("#" comments allowed).

Exit status: 0 PASS, 1 REJECT (semantic), 2 ERROR (malformed/tool).
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

PAGE_OFFSET = 0xC0000000
TASK_SIZE = 0xBF000000


def load_config(path: str) -> Tuple[Optional[Dict[str, str]], Optional[str]]:
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            lines = handle.read().splitlines()
    except OSError as exc:
        return None, f"cannot read effective config: {exc}"
    values: Dict[str, str] = {}
    not_set = set()
    for line in lines:
        stripped = line.strip()
        unset = re.match(r"^#\s*(CONFIG_[A-Za-z0-9_]+)\s+is not set\s*$", stripped)
        if unset:
            not_set.add(unset.group(1))
            continue
        if not stripped or stripped.startswith("#"):
            continue
        match = re.match(r"^(CONFIG_[A-Za-z0-9_]+)=(.*)$", stripped)
        if match:
            values[match.group(1)] = match.group(2).strip()
    return {"values": values, "not_set": not_set, "lines": lines}, ""


def check_frozen(cfg: Dict) -> List[Tuple[str, bool, str]]:
    values = cfg["values"]
    not_set = cfg["not_set"]
    out = []
    # CONFIG_ARM_LPAE=n : either "CONFIG_ARM_LPAE=n" or "# CONFIG_ARM_LPAE is not set".
    lpae_ok = (values.get("CONFIG_ARM_LPAE") == "n") or ("CONFIG_ARM_LPAE" in not_set)
    out.append(("frozen.CONFIG_ARM_LPAE=n", lpae_ok,
                "effective CONFIG_ARM_LPAE=n (or '# CONFIG_ARM_LPAE is not set')"
                if lpae_ok else
                "effective config does not set CONFIG_ARM_LPAE=n (comment mention is not enough)"))
    vmsplit_ok = (values.get("CONFIG_VMSPLIT_3G") == "y")
    out.append(("frozen.CONFIG_VMSPLIT_3G=y", vmsplit_ok,
                "effective CONFIG_VMSPLIT_3G=y"
                if vmsplit_ok else
                "effective config does not set CONFIG_VMSPLIT_3G=y"))
    page_ok = (values.get("CONFIG_PAGE_OFFSET", "") in ("0xC0000000", "0XC0000000"))
    # PAGE_OFFSET/TASK_SIZE are consequences of VMSPLIT_3G; accept them either as
    # explicit assignments or as documented derivations when VMSPLIT_3G is set.
    # To keep the check generic (no answer key), require at least that the file
    # *states* the frozen hex values somewhere effective (not in a comment).
    text_effective = "\n".join(l for l in cfg["lines"]
                               if l.strip() and not l.strip().startswith("#"))
    if not page_ok and "0xC0000000" in text_effective:
        page_ok = True
    out.append(("frozen.PAGE_OFFSET=0xC0000000", page_ok,
                "effective PAGE_OFFSET 0xC0000000"
                if page_ok else
                "effective config carries no PAGE_OFFSET 0xC0000000 assignment"))
    task_ok = ("0xBF000000" in text_effective)
    out.append(("frozen.TASK_SIZE=0xBF000000", task_ok,
                "effective TASK_SIZE 0xBF000000"
                if task_ok else
                "effective config carries no TASK_SIZE 0xBF000000 assignment"))
    return out


def parse_artifact(path: str):
    if not os.path.isfile(path):
        return None, f"artifact not found: {path}"
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            text = handle.read()
    except OSError as exc:
        return None, f"cannot read artifact: {exc}"
    if not text.strip():
        return None, "artifact is empty"
    stripped = text.strip()
    if stripped.startswith("{") or stripped.startswith("["):
        try:
            obj = json.loads(text)
        except ValueError as exc:
            return None, f"artifact is not valid JSON: {exc}"
        items = []
        if isinstance(obj, dict):
            seq = obj.get("vas", obj.get("addresses", obj.get("entries", [])))
            if isinstance(seq, dict):
                seq = [seq]
            if not isinstance(seq, list):
                return None, "JSON artifact has no vas/addresses list"
            for entry in seq:
                if isinstance(entry, dict):
                    addr = entry.get("addr", entry.get("address", entry.get("va")))
                    cls = entry.get("class", entry.get("claimed", entry.get("region", "")))
                    if addr is None:
                        return None, f"JSON entry has no addr: {entry!r}"
                    items.append((str(addr), str(cls or "")))
                else:
                    items.append((str(entry), ""))
        elif isinstance(obj, list):
            for entry in obj:
                if isinstance(entry, dict):
                    addr = entry.get("addr", entry.get("address"))
                    cls = entry.get("class", entry.get("claimed", ""))
                    items.append((str(addr), str(cls or "")))
                else:
                    items.append((str(entry), ""))
        else:
            return None, "unsupported JSON top level"
        return items, ""
    # Text shape.
    items = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        parts = s.split()
        if len(parts) == 1:
            items.append((parts[0], ""))
        elif len(parts) == 2:
            items.append((parts[0], parts[1]))
        else:
            return None, f"line {lineno}: expected '<addr> <user|kernel>': {line!r}"
    if not items:
        return None, "artifact contains no addresses"
    return items, ""


def norm_class(text: str) -> str:
    s = text.strip().lower()
    if s in ("user", "userspace", "u", "pl0", "low"):
        return "user"
    if s in ("kernel", "kern", "k", "pl1", "high", "priv"):
        return "kernel"
    return ""


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="P3-M07 arch split binding checker")
    parser.add_argument("artifact", help="candidate VA classification artifact")
    parser.add_argument("--config", required=True,
                        help="effective kernel config file (frozen assignments)")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    if not os.path.isfile(args.config):
        print(f"ERROR: effective config not found: {args.config}", file=sys.stderr)
        return EXIT_ERROR
    cfg, error = load_config(args.config)
    if cfg is None:
        print(f"ERROR: {error}", file=sys.stderr)
        return EXIT_ERROR

    frozen = check_frozen(cfg)
    frozen_bad = [ident for ident, ok, _ in frozen if not ok]

    items, error = parse_artifact(args.artifact)
    if items is None:
        print(f"ERROR: {error}", file=sys.stderr)
        return EXIT_ERROR

    results = []
    for ident, ok, detail in frozen:
        results.append({"id": ident, "ok": ok, "detail": detail})

    saw_reject = bool(frozen_bad)
    for addr_text, claimed_text in items:
        try:
            addr = int(addr_text.strip(), 0)
        except ValueError:
            print(f"ERROR: malformed address: {addr_text!r}", file=sys.stderr)
            return EXIT_ERROR
        if not (0 <= addr <= 0xFFFFFFFF):
            print(f"ERROR: address out of 32-bit range: {addr_text!r}", file=sys.stderr)
            return EXIT_ERROR
        if addr < TASK_SIZE:
            actual = "user"
        elif addr >= PAGE_OFFSET:
            actual = "kernel"
        else:
            results.append({
                "id": f"va.0x{addr:08X}", "ok": False,
                "detail": f"0x{addr:08X} lies in the 16MiB module-space gap "
                          f"[0x{TASK_SIZE:08X}, 0x{PAGE_OFFSET:08X}): neither user nor kernel: REJECT",
            })
            saw_reject = True
            continue
        claimed = norm_class(claimed_text)
        if not claimed:
            # Unlabelled address: classification alone still proves the split
            # only if the config is frozen; record the derived class.
            results.append({
                "id": f"va.0x{addr:08X}", "ok": True,
                "detail": f"0x{addr:08X} derives as {actual} "
                          f"(<0x{TASK_SIZE:08X} user / >=0x{PAGE_OFFSET:08X} kernel)",
            })
            continue
        ok = (claimed == actual)
        if not ok:
            saw_reject = True
        results.append({
            "id": f"va.0x{addr:08X}", "ok": ok,
            "detail": f"0x{addr:08X} claimed {claimed} vs derived {actual}: "
                      + ("matches" if ok else "MISMATCH: REJECT"),
        })

    if args.json:
        print(json.dumps({"artifact": args.artifact, "config": args.config,
                          "results": results,
                          "verdict": "REJECT" if saw_reject else "PASS"},
                         indent=2, sort_keys=True))
    elif not args.quiet:
        print("=" * 66)
        print("=== P3-M07 user/kernel split binding ===")
        print(f"=== config: {args.config}  artifact: {args.artifact}")
        print(f"=== frozen: TASK_SIZE=0x{TASK_SIZE:08X} PAGE_OFFSET=0x{PAGE_OFFSET:08X}")
        for item in results:
            print(f"[{'PASS' if item['ok'] else 'FAIL'}] {item['id']} -- {item['detail']}")

    if saw_reject:
        if not args.json and not args.quiet:
            print("=== ARCH BINDING CONTRACT: REJECT ===", file=sys.stderr)
        return EXIT_REJECT
    if not args.json and not args.quiet:
        print("=== ARCH BINDING CONTRACT: PASS ===")
    return EXIT_PASS


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
