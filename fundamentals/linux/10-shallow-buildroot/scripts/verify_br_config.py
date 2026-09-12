#!/usr/bin/env python3
"""Semantic validator for a Buildroot 2026.05.2 configuration fragment (P3-M06).

The candidate is a **data-only** configuration fragment: the same
``KEY=value`` / ``# KEY is not set`` syntax Buildroot itself uses for
defconfigs.  Nothing else is accepted, so a fragment cannot smuggle a shell
command into the build the way a "run this script" submission could.

The validator is *semantic*: it evaluates Kconfig-style relationships
(implications, mutual exclusion, forbidden symbols) and compares values against
a contract profile.  It never searches for substrings, so a fragment that
merely *mentions* the right symbol in a comment does not pass.

Optionally the fragment is checked against a symbol table extracted from the
real Buildroot 2026.05.2 source tree, which is how the module enforces
"verify exact 2026.05.2 symbols; do not rely on option names from memory".

Exit status
-----------
0  PASS   -- every invariant in the requested profile holds
1  REJECT -- well-formed fragment that violates the contract
2  ERROR  -- the fragment could not be read/parsed, or the profile is unusable

Usage
-----
    python3 scripts/verify_br_config.py --profile <profile.json> CANDIDATE.conf
    python3 scripts/verify_br_config.py --profile <p> --symbol-table <s.json> CANDIDATE.conf
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from typing import Any, Dict, List, Optional, Set, Tuple

EXIT_PASS = 0
EXIT_REJECT = 1
EXIT_ERROR = 2

DEFAULT_PROFILE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "fixtures", "profiles", "buildroot-2026.05.2-taught.json")

SYMBOL_RE = re.compile(r"^BR2_[A-Za-z0-9_]+$")
SET_RE = re.compile(r"^(BR2_[A-Za-z0-9_]+)=(.*)$")
UNSET_RE = re.compile(r"^#\s*(BR2_[A-Za-z0-9_]+)\s+is not set\s*$")

#: The only ``$(...)`` expansion the canonical configuration is allowed to use:
#: the path variable Buildroot itself defines for a BR2_EXTERNAL tree, optionally
#: followed by a relative path inside that tree.
EXTERNAL_PATH_RE = re.compile(
    r"^\$\(BR2_EXTERNAL_[A-Z0-9_]+_PATH\)(/[A-Za-z0-9._/-]*)?$")

#: Characters that have no meaning in a Kconfig value and only appear when
#: someone is trying to smuggle shell content into the build.
FORBIDDEN_VALUE_CHARS = set(";|&`<>")


class ConfigError(Exception):
    """The fragment is not a well-formed Buildroot configuration fragment."""


class Config:
    def __init__(self) -> None:
        self.values: Dict[str, str] = {}
        self.explicitly_unset: Set[str] = set()
        self.order: List[str] = []

    def is_set(self, symbol: str) -> bool:
        return self.values.get(symbol) == "y"

    def get(self, symbol: str) -> Optional[str]:
        return self.values.get(symbol)

    def is_unset(self, symbol: str) -> bool:
        return symbol in self.explicitly_unset or self.values.get(symbol) == "n"


def _validate_value(symbol: str, value: str, line_no: int) -> None:
    if value == "":
        raise ConfigError(f"line {line_no}: '{symbol}' has an empty value")
    if any(ch in FORBIDDEN_VALUE_CHARS for ch in value):
        raise ConfigError(
            f"line {line_no}: value of '{symbol}' contains a shell metacharacter "
            f"({value!r}); a configuration fragment is data, not a script")
    if "$(" in value:
        # Only the canonical external-tree path expansion is declarative.
        stripped = value.strip('"')
        if not EXTERNAL_PATH_RE.match(stripped):
            raise ConfigError(
                f"line {line_no}: value of '{symbol}' uses a command substitution "
                f"({value!r}); only $(BR2_EXTERNAL_<NAME>_PATH) is allowed")
    if "`" in value:
        raise ConfigError(f"line {line_no}: value of '{symbol}' contains a backtick")


def parse_fragment(path: str) -> Config:
    if not os.path.isfile(path):
        raise FileNotFoundError(f"configuration fragment not found: {path}")
    cfg = Config()
    with open(path, "r", encoding="utf-8") as handle:
        for line_no, raw in enumerate(handle, start=1):
            line = raw.rstrip("\n").rstrip("\r")
            if not line.strip():
                continue
            if line.lstrip().startswith("#"):
                unset = UNSET_RE.match(line.strip())
                if unset:
                    symbol = unset.group(1)
                    cfg.explicitly_unset.add(symbol)
                continue
            match = SET_RE.match(line.strip())
            if not match:
                raise ConfigError(
                    f"line {line_no}: not a configuration declaration: {line!r} "
                    "(expected KEY=value or '# KEY is not set')")
            symbol, value = match.group(1), match.group(2)
            if not SYMBOL_RE.match(symbol):
                raise ConfigError(f"line {line_no}: invalid Kconfig symbol name {symbol!r}")
            _validate_value(symbol, value, line_no)
            if symbol in cfg.values and cfg.values[symbol] != value:
                raise ConfigError(
                    f"line {line_no}: '{symbol}' is defined twice with conflicting "
                    f"values ({cfg.values[symbol]!r} then {value!r})")
            if symbol not in cfg.values:
                cfg.order.append(symbol)
            cfg.values[symbol] = value
    return cfg


def load_json(path: str) -> Dict[str, Any]:
    if not os.path.isfile(path):
        raise FileNotFoundError(f"not found: {path}")
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def validate(cfg: Config, profile: Dict[str, Any],
             symbol_table: Optional[Dict[str, Any]]) -> List[Tuple[str, bool, str]]:
    results: List[Tuple[str, bool, str]] = []

    def record(ident: str, ok: bool, detail: str) -> None:
        results.append((ident, ok, detail))

    # --- symbol existence ----------------------------------------------------
    if symbol_table and profile.get("reject_unknown_symbols"):
        known = set(symbol_table.get("symbols", {}))
        known |= set(symbol_table.get("external_symbols", {}))
        unknown = sorted(s for s in list(cfg.values) + list(cfg.explicitly_unset)
                         if s not in known)
        record("symbols.known", not unknown,
               f"{len(cfg.values)} symbol(s) declared, all present in the real "
               f"Buildroot {profile.get('buildroot_release')} source tree"
               if not unknown else
               f"symbol(s) that do not exist in the real Buildroot "
               f"{profile.get('buildroot_release')} source tree: {unknown[:8]}")

    # --- required values -----------------------------------------------------
    for symbol, expected in sorted(profile.get("required_values", {}).items()):
        actual = cfg.get(symbol)
        record(f"required.{symbol}", actual == expected,
               f"{symbol}={actual!r} expected {expected!r}")

    # --- required present and non-empty -------------------------------------
    for symbol in profile.get("required_present_nonempty", []):
        actual = cfg.get(symbol)
        ok = actual is not None and actual.strip().strip('"') != ""
        record(f"present.{symbol}", ok,
               f"{symbol}={actual!r} must be present and non-empty")

    # --- required exact value ------------------------------------------------
    for symbol, expected in sorted(profile.get("required_exact", {}).items()):
        actual = cfg.get(symbol)
        record(f"exact.{symbol}", actual == expected,
               f"{symbol}={actual!r} expected {expected!r}")

    # --- forbidden symbols ---------------------------------------------------
    for symbol in profile.get("forbidden_set", []):
        record(f"forbidden.{symbol}", not cfg.is_set(symbol),
               f"{symbol} must not be enabled in the canonical configuration")

    # --- implications --------------------------------------------------------
    for rule in profile.get("implications", []):
        trigger = rule["if_set"]
        if not cfg.is_set(trigger):
            continue
        missing = [s for s in rule["requires_set"] if not cfg.is_set(s)]
        record(f"implies.{trigger}", not missing,
               f"{trigger} requires {rule['requires_set']}; missing {missing}")

    # --- mutual exclusion ----------------------------------------------------
    for group in profile.get("mutually_exclusive", []):
        active = [s for s in group if cfg.is_set(s)]
        record(f"exclusive.{'+'.join(group)}", len(active) <= 1,
               f"mutually exclusive symbols enabled together: {active}"
               if len(active) > 1 else
               f"at most one of {group} is enabled")

    return results


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="P3-M06 Buildroot config validator")
    parser.add_argument("fragment", help="configuration fragment under test")
    parser.add_argument("--profile", default=DEFAULT_PROFILE)
    parser.add_argument("--symbol-table",
                        help="JSON symbol table extracted from the real Buildroot source tree")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)

    try:
        profile = load_json(args.profile)
    except (OSError, ValueError) as exc:
        print(f"ERROR: cannot load profile: {exc}", file=sys.stderr)
        return EXIT_ERROR

    symbol_table = None
    if args.symbol_table:
        try:
            symbol_table = load_json(args.symbol_table)
        except (OSError, ValueError) as exc:
            print(f"ERROR: cannot load symbol table: {exc}", file=sys.stderr)
            return EXIT_ERROR

    try:
        cfg = parse_fragment(args.fragment)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return EXIT_ERROR
    except ConfigError as exc:
        print(f"REJECT: {exc}", file=sys.stderr)
        return EXIT_REJECT

    results = validate(cfg, profile, symbol_table)

    if args.json:
        print(json.dumps({
            "fragment": args.fragment,
            "profile": profile.get("profile"),
            "results": [{"id": i, "ok": o, "detail": d} for i, o, d in results],
            "verdict": "PASS" if all(o for _, o, _ in results) else "REJECT",
        }, indent=2))
        return EXIT_PASS if all(o for _, o, _ in results) else EXIT_REJECT

    if not args.quiet:
        print("=" * 66)
        print(f"=== P3-M06 Buildroot configuration contract: {profile.get('profile')}")
        print(f"=== Fragment: {args.fragment}")
        print("=" * 66)
        for ident, ok, detail in results:
            print(f"[{'PASS' if ok else 'FAIL'}] {ident}" + (f" -- {detail}" if detail else ""))

    failed = [i for i, ok, _ in results if not ok]
    if failed:
        print(f"=== BUILDROOT CONFIG CONTRACT: REJECT ({len(failed)} invariant(s) violated) ===",
              file=sys.stderr)
        for ident in failed:
            print(f"    - {ident}", file=sys.stderr)
        return EXIT_REJECT

    if not args.quiet:
        print(f"=== BUILDROOT CONFIG CONTRACT: PASS ({len(results)} invariants) ===")
    return EXIT_PASS


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
