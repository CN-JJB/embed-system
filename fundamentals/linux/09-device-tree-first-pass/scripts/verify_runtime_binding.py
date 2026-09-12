#!/usr/bin/env python3
"""Bind a guest runtime device-tree capture to a candidate DTB (P3-M05, Lab 5.4).

A guest log proves nothing on its own: text can be typed.  This verifier
therefore refuses to accept a runtime capture unless *all* of the following
hold simultaneously:

1. the executed-argv provenance exists and records the canonical QEMU machine
   contract (``virt,highmem=off,gic-version=2``, ``cortex-a7``, ``512M``, SMP 1);
2. the console log contains the kernel command line that the provenance says
   was passed, so the log belongs to that execution;
3. the log carries the bounded ``DT-PROBE`` markers emitted by the read-only
   probe in ``scripts/run_qemu_dtb_boot.sh``;
4. the guest-observed ``/sys/firmware/devicetree/base/model`` value equals the
   candidate DTB's root ``model`` property;
5. the guest-observed property listing of the probed node equals the candidate
   DTB node's property names;
6. the DTB recorded in the provenance is *the same tree* as the candidate
   artifact -- byte-identical is the strong case, semantically identical
   (modulo QEMU's randomised ``chosen`` seeds) is the weak case.

Point 6 is what rejects the "runtime evidence captured from a different DTB"
defect class: a correct-looking capture from another tree cannot be pasted in
to support this candidate.

Exit status
-----------
0  VERIFIED  -- runtime evidence bound to the candidate DTB
1  REJECT    -- well-formed but the evidence does not bind
2  ERROR     -- a required input is missing or unreadable

Usage
-----
    python3 scripts/verify_runtime_binding.py CANDIDATE.dtb PROVENANCE LOG
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from typing import Dict, List, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fdtlib_min import (  # noqa: E402
    FdtFormatError,
    FdtSemanticError,
    parse_file,
    semantic_diff,
)

EXIT_VERIFIED = 0
EXIT_REJECT = 1
EXIT_ERROR = 2

CANONICAL_MACHINE = "virt,highmem=off,gic-version=2"
CANONICAL_CPU = "cortex-a7"
CANONICAL_MEM = "512M"
CANONICAL_SMP = "1"

PROBE_MODEL = re.compile(r"^DT-PROBE model=(.*)$", re.MULTILINE)
PROBE_NODE = re.compile(r"^DT-PROBE-NODE (\S+)$", re.MULTILINE)
PROBE_NODE_LIST = re.compile(r"^DT-PROBE-NODE (\S+)\n(.*)$", re.MULTILINE)
PROBE_END = "DT-PROBE-END"
# The kernel prints this line with a leading "[    0.000000] " timestamp, so the
# pattern must not be anchored to the start of the line.
CMDLINE = re.compile(r"Kernel command line:\s*(.*)$", re.MULTILINE)


def read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        return handle.read()


def parse_provenance(text: str) -> Dict[str, str]:
    out: Dict[str, str] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("argv:"):
            out.setdefault("argv", "")
            out["argv"] += line[len("argv:"):].strip() + " "
            continue
        if ":" in line:
            key, value = line.split(":", 1)
            out[key.strip()] = value.strip()
    return out


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="P3-M05 runtime DT evidence binder")
    parser.add_argument("candidate", help="candidate DTB")
    parser.add_argument("provenance", help="executed-argv provenance file")
    parser.add_argument("log", help="captured guest console log")
    args = parser.parse_args(argv)

    for path in (args.candidate, args.provenance, args.log):
        if not os.path.isfile(path):
            print(f"ERROR: missing required input: {path}", file=sys.stderr)
            return EXIT_ERROR

    try:
        candidate = parse_file(args.candidate)
    except (FdtFormatError, FdtSemanticError) as exc:
        print(f"ERROR: cannot parse candidate DTB: {exc}", file=sys.stderr)
        return EXIT_ERROR

    prov = parse_provenance(read_text(args.provenance))
    log = read_text(args.log)

    print("=" * 66)
    print("=== P3-M05 runtime device-tree evidence binding")
    print(f"=== candidate : {args.candidate}")
    print(f"=== provenance: {args.provenance}")
    print(f"=== log       : {args.log}")
    print("=" * 66)

    failures: List[str] = []

    def need(condition: bool, ident: str, detail: str) -> None:
        print(f"[{'PASS' if condition else 'FAIL'}] {ident} -- {detail}")
        if not condition:
            failures.append(ident)

    # 1. canonical machine contract in the executed argv
    need(prov.get("machine") == CANONICAL_MACHINE, "argv.machine",
         f"machine={prov.get('machine')!r} expected {CANONICAL_MACHINE!r}")
    need(prov.get("cpu") == CANONICAL_CPU, "argv.cpu",
         f"cpu={prov.get('cpu')!r} expected {CANONICAL_CPU!r}")
    need(prov.get("memory") == CANONICAL_MEM, "argv.memory",
         f"memory={prov.get('memory')!r} expected {CANONICAL_MEM!r}")
    need(prov.get("smp") == CANONICAL_SMP, "argv.smp",
         f"smp={prov.get('smp')!r} expected {CANONICAL_SMP!r}")

    # 2. the log belongs to that execution
    cmdlines = CMDLINE.findall(log)
    if not cmdlines:
        need(False, "log.kernel-command-line", "the log contains no 'Kernel command line:' line")
    else:
        expected_args = prov.get("bootargs", "").split()
        matched = any(all(tok in cl.split() for tok in expected_args) for cl in cmdlines)
        need(matched, "log.kernel-command-line",
             f"logged command line(s) {cmdlines[:2]} must contain every provenance bootarg "
             f"{expected_args}")

    # 3. the read-only probe ran
    need(PROBE_END in log, "log.probe-complete",
         "the log contains the DT-PROBE-END marker (the guest probe ran to completion)")

    # 4/5. guest-observed values must match the candidate tree
    assert candidate.root is not None
    model_match = PROBE_MODEL.search(log)
    if model_match is None:
        need(False, "guest.model", "the guest did not report /sys/firmware/devicetree/base/model")
    else:
        observed = model_match.group(1).strip()
        try:
            expected_model = candidate.root.prop_str("model")
        except FdtSemanticError:
            expected_model = None
        need(observed == expected_model, "guest.model",
             f"guest model={observed!r} candidate root model={expected_model!r}")

    node_match = PROBE_NODE_LIST.search(log)
    if node_match is None:
        need(False, "guest.node-properties", "the guest did not report any DT-PROBE-NODE listing")
    else:
        path = node_match.group(1).strip()
        observed_props = sorted(p for p in node_match.group(2).split() if p)
        node = None
        for cand in candidate.root.walk():
            if cand.path == path:
                node = cand
                break
        if node is None:
            need(False, "guest.node-properties",
                 f"the guest probed {path} but the candidate tree has no such node")
        else:
            expected_props = sorted(node.props)
            need(observed_props == expected_props, "guest.node-properties",
                 f"guest saw {observed_props} at {path}; candidate tree declares "
                 f"{expected_props}")

    # 6. the booted DTB must be the candidate tree
    booted_sha = prov.get("dtb_sha256", "")
    cand_sha = __import__("hashlib").sha256(open(args.candidate, "rb").read()).hexdigest()
    if booted_sha and booted_sha == cand_sha:
        need(True, "binding.dtb-identity",
             f"booted DTB is byte-identical to the candidate (sha256 {cand_sha[:16]}...)")
    else:
        # Fall back to semantic identity: QEMU randomises chosen seeds, so a
        # freshly generated DTB for the same machine is not byte-identical.
        raw = read_text(args.provenance)
        recorded = prov.get("dtb_path") or ""
        booted_dtb = None
        for line in raw.splitlines():
            if line.startswith("argv:") and line.strip().endswith(".dtb"):
                booted_dtb = line.strip()[len("argv:"):].strip()
        if booted_dtb and os.path.isfile(booted_dtb):
            try:
                other = parse_file(booted_dtb)
                diff = semantic_diff(candidate, other, skip_props=("rng-seed", "kaslr-seed"))
            except (FdtFormatError, FdtSemanticError) as exc:
                diff = [f"cannot parse booted DTB: {exc}"]
            need(not diff, "binding.dtb-identity",
                 f"booted DTB sha256 {booted_sha[:16] if booted_sha else '<unrecorded>'}... "
                 f"differs byte-wise from the candidate; semantic comparison: "
                 f"{'identical' if not diff else f'{len(diff)} difference(s)'}")
            if diff:
                for line in diff[:20]:
                    print("        " + line)
        else:
            need(False, "binding.dtb-identity",
                 "the provenance does not record a dtb_sha256 equal to the candidate and the "
                 "booted DTB path is not available for a semantic comparison")

    print("-" * 66)
    print("NOTE: this binder establishes internal consistency and artifact")
    print("      identity.  It does not prove the capture came from a real")
    print("      execution; authenticity requires the reviewer to re-execute")
    print("      the recorded argv through a trusted runner.")
    if failures:
        print(f"REJECT: runtime evidence is not bound to the candidate "
              f"({len(failures)} failed check(s)): {failures}", file=sys.stderr)
        return EXIT_REJECT
    print("=== RUNTIME DT EVIDENCE: VERIFIED (bound to the candidate DTB) ===")
    return EXIT_VERIFIED


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
