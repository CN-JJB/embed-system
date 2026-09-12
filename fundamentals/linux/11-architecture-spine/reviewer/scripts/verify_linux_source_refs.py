#!/usr/bin/env python3
"""Cross-validate recorded Linux source references against a real source tree.

REVIEWER-ONLY authoring tool for P3-M07.

For every entry in the reference table this checks three things independently:

  1. the file exists in the supplied tree;
  2. the recorded regex matches exactly the recorded number of occurrences;
  3. the recorded line number really is one of those occurrences.

Exit codes follow the repository convention used by the semantic oracles:

  0  every recorded reference resolved exactly (or: the negative self-test
     correctly rejected its mutated table)
  1  a recorded reference is absent, ambiguous, or has drifted
  2  ERROR -- bad invocation, unreadable table, or a malformed table entry.
     Never reported as intended drift.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys


def load_table(path: str) -> dict:
    try:
        with open(path, encoding="utf-8") as handle:
            table = json.load(handle)
    except FileNotFoundError:
        print(f"ERROR: reference table not found: {path}", file=sys.stderr)
        sys.exit(2)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: reference table unreadable/malformed: {exc}", file=sys.stderr)
        sys.exit(2)

    if not isinstance(table, dict) or not isinstance(table.get("entries"), list):
        print("ERROR: reference table has no 'entries' list", file=sys.stderr)
        sys.exit(2)
    for index, entry in enumerate(table["entries"]):
        if not isinstance(entry, dict):
            print(f"ERROR: entry {index} is not an object", file=sys.stderr)
            sys.exit(2)
        for key in ("file", "symbol", "line", "regex"):
            if key not in entry:
                print(f"ERROR: entry {index} ({entry.get('symbol', '?')}) lacks '{key}'",
                      file=sys.stderr)
                sys.exit(2)
        try:
            re.compile(entry["regex"])
        except re.error as exc:
            print(f"ERROR: entry {index} ({entry['symbol']}) has an invalid regex: {exc}",
                  file=sys.stderr)
            sys.exit(2)
    return table


def check(tree: str, table: dict) -> list[str]:
    """Return a list of human-readable problems; empty means fully resolved."""
    problems: list[str] = []
    for entry in table["entries"]:
        path = os.path.join(tree, entry["file"])
        if not os.path.isfile(path):
            problems.append(f'{entry["file"]}: file missing from the supplied tree')
            continue
        pattern = re.compile(entry["regex"])
        hits: list[int] = []
        try:
            with open(path, encoding="utf-8", errors="replace") as handle:
                for index, line in enumerate(handle, start=1):
                    if pattern.search(line):
                        hits.append(index)
        except OSError as exc:
            problems.append(f'{entry["file"]}: unreadable ({exc})')
            continue
        expected = entry.get("occurrences", 1)
        if not hits:
            problems.append(f'{entry["file"]}:{entry["symbol"]}: regex matched nothing')
            continue
        if len(hits) != expected:
            problems.append(
                f'{entry["file"]}:{entry["symbol"]}: expected {expected} occurrence(s), '
                f'found {len(hits)} at {hits[:8]}'
            )
            continue
        if entry["line"] not in hits:
            problems.append(
                f'{entry["file"]}:{entry["symbol"]}: recorded line {entry["line"]} '
                f'not among matches {hits}'
            )
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--tree", required=True, help="root of the Linux source tree")
    parser.add_argument("--table", required=True, help="reference table JSON")
    parser.add_argument("--selftest", action="store_true",
                        help="after the positive check, prove the checker rejects a "
                             "deliberately corrupted table (fail-closed evidence)")
    args = parser.parse_args()

    if not os.path.isdir(args.tree):
        print(f"ERROR: source tree not found: {args.tree}", file=sys.stderr)
        return 2

    table = load_table(args.table)

    problems = check(args.tree, table)
    if problems:
        print("[FAIL] recorded source references did not resolve exactly:", file=sys.stderr)
        for item in problems:
            print(f"       {item}", file=sys.stderr)
        return 1
    print(f"[PASS] all {len(table['entries'])} recorded source references resolved "
          f"exactly at their recorded line numbers (occurrence counts verified)")

    if not args.selftest:
        return 0

    # --- negative self-test: the checker must not be fail-open ---------------
    if not table["entries"]:
        print("[FAIL] negative self-test impossible: table is empty", file=sys.stderr)
        return 2
    first = table["entries"][0]
    for mutation, label in (
        (lambda e: e.__setitem__("line", e["line"] + 1), "shifted line number"),
        (lambda e: e.__setitem__("regex", r"^THIS_PATTERN_MATCHES_NOTHING_AT_ALL$"),
         "unmatchable regex"),
        (lambda e: e.__setitem__("occurrences", e.get("occurrences", 1) + 1),
         "wrong occurrence count"),
        (lambda e: e.__setitem__("file", "arch/arm/kernel/this-file-does-not-exist.S"),
         "phantom file"),
    ):
        mutated = json.loads(json.dumps(table))
        mutation(mutated["entries"][0])
        if not check(args.tree, mutated):
            print(f"[FAIL] negative self-test did not reject a {label} "
                  f"({first['file']}:{first['symbol']})", file=sys.stderr)
            return 1
    print("[PASS] negative self-test: all 4 deliberate corruptions were rejected, "
          "and each rejection is a semantic REJECT (exit 1), not an environment ERROR")
    return 0


if __name__ == "__main__":
    sys.exit(main())
