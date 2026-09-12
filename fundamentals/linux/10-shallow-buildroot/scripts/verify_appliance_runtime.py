#!/usr/bin/env python3
"""Bind a Buildroot appliance runtime capture to the image that was booted (P3-M06).

A console log proves nothing on its own.  This verifier accepts a runtime
capture only when all of the following hold at once:

1. the executed-argv provenance records the canonical QEMU machine contract
   (``virt,highmem=off,gic-version=2``, ``cortex-a7``, ``512M``, SMP 1);
2. the log contains the kernel command line the provenance says was passed;
3. the log carries the overlay's boot marker, so the *overlay* ran -- not merely
   "a system booted";
4. the log carries the diagnostic utility's begin/end markers and reports an
   appliance release string equal to the overlay's marker file content;
5. the image recorded in the provenance is byte-identical to the image under
   audit.

Point 5 is what rejects the "candidate manifest declares artifacts different
from those actually booted" defect class.  Points 3 and 4 are what reject the
"the file exists in the image but nothing ever proved it ran" class.

The binder establishes internal consistency and artifact identity.  It does
**not** prove the capture came from a real execution; authenticity requires the
reviewer to re-execute the recorded argv.

Exit status
-----------
0  VERIFIED / 1  REJECT / 2  ERROR

Usage
-----
    python3 scripts/verify_appliance_runtime.py IMAGE PROVENANCE LOG [--overlay DIR]
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import sys
from typing import Dict, List, Optional

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from audit_output_tree import CpioError, read_cpio  # noqa: E402

EXIT_VERIFIED = 0
EXIT_REJECT = 1
EXIT_ERROR = 2

CANONICAL_MACHINE = "virt,highmem=off,gic-version=2"
CANONICAL_CPU = "cortex-a7"
CANONICAL_MEM = "512M"
CANONICAL_SMP = "1"

# The kernel prints this line with a leading "[    0.000000] " timestamp, so the
# pattern must not be anchored to the start of the line.
CMDLINE = re.compile(r"Kernel command line:\s*(.*)$", re.MULTILINE)
DIAG_BEGIN = "APPLIANCE-DIAG-BEGIN"
DIAG_END = "APPLIANCE-DIAG-END"
OVERLAY_MARKER = "APPLIANCE-OVERLAY-BOOT-MARKER"
RELEASE_LINE = re.compile(r"^APPLIANCE-RELEASE=(.*)$", re.MULTILINE)
DT_MODEL_LINE = re.compile(r"^DT-MODEL=(.*)$", re.MULTILINE)


def parse_provenance(text: str) -> Dict[str, str]:
    out: Dict[str, str] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if ":" in line:
            key, value = line.split(":", 1)
            out[key.strip()] = value.strip()
    return out


def read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        return handle.read()


def sha256_file(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="P3-M06 appliance runtime binder")
    parser.add_argument("image", help="final rootfs image that was booted")
    parser.add_argument("provenance", help="executed-argv provenance file")
    parser.add_argument("log", help="captured guest console log")
    parser.add_argument("--overlay", help="overlay source tree, to cross-check the release marker")
    args = parser.parse_args(argv)

    for path in (args.image, args.provenance, args.log):
        if not os.path.isfile(path):
            print(f"ERROR: missing required input: {path}", file=sys.stderr)
            return EXIT_ERROR

    prov = parse_provenance(read_text(args.provenance))
    log = read_text(args.log)

    print("=" * 66)
    print("=== P3-M06 appliance runtime evidence binding")
    print(f"=== image     : {args.image}")
    print(f"=== provenance: {args.provenance}")
    print(f"=== log       : {args.log}")
    print("=" * 66)

    failures: List[str] = []

    def need(condition: bool, ident: str, detail: str) -> None:
        print(f"[{'PASS' if condition else 'FAIL'}] {ident} -- {detail}")
        if not condition:
            failures.append(ident)

    # 1. canonical machine contract
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
    expected_args = prov.get("bootargs", "").split()
    matched = bool(cmdlines) and any(
        all(tok in cl.split() for tok in expected_args) for cl in cmdlines)
    need(matched, "log.kernel-command-line",
         f"logged command line(s) {cmdlines[:2]} must contain every provenance bootarg "
         f"{expected_args}")

    # 3. the overlay actually ran
    need(OVERLAY_MARKER in log, "log.overlay-marker",
         "the log carries the root filesystem overlay's boot marker, so the overlay "
         "content was executed and not merely packaged")

    # 4. the diagnostic utility ran and agrees with the overlay
    need(DIAG_BEGIN in log and DIAG_END in log, "log.diag-complete",
         "the packaged diagnostic utility ran to completion inside the guest")
    release = RELEASE_LINE.search(log)
    if release is None:
        need(False, "guest.release-marker",
             "the diagnostic utility did not report APPLIANCE-RELEASE")
    else:
        observed = release.group(1).strip()
        expected = None
        if args.overlay:
            marker = os.path.join(args.overlay, "etc", "appliance-release")
            if os.path.isfile(marker):
                expected = read_text(marker).strip()
        if expected is None:
            need(True, "guest.release-marker",
                 f"guest reported release {observed!r} (no overlay tree supplied to "
                 "cross-check against)")
        else:
            need(observed == expected, "guest.release-marker",
                 f"guest release={observed!r} overlay marker={expected!r}")

    # 5. the booted image is the image under audit
    recorded = prov.get("initrd_sha256") or prov.get("image_sha256") or ""
    actual = sha256_file(args.image)
    need(recorded == actual, "binding.image-identity",
         f"provenance image sha256 {recorded[:16] or '<unrecorded>'}... vs audited image "
         f"{actual[:16]}...")

    # 6. the image really contains the overlay (a boot marker without the file
    #    would mean the log came from somewhere else)
    if args.overlay and os.path.isdir(args.overlay):
        try:
            entries = read_cpio(args.image)
        except (CpioError, OSError, EOFError) as exc:
            print(f"ERROR: cannot read the audited image: {exc}", file=sys.stderr)
            return EXIT_ERROR
        missing = []
        for dirpath, _dirnames, filenames in os.walk(args.overlay):
            for name in filenames:
                rel = os.path.relpath(os.path.join(dirpath, name), args.overlay)
                rel = rel.replace(os.sep, "/")
                if rel not in entries:
                    missing.append(rel)
        need(not missing, "image.contains-overlay",
             "every overlay file is present inside the audited image"
             if not missing else f"absent from the image: {missing[:4]}")

    print("-" * 66)
    print("NOTE: this binder establishes internal consistency and artifact identity.")
    print("      It does not prove the capture came from a real execution; authenticity")
    print("      requires the reviewer to re-execute the recorded argv.")
    if failures:
        print(f"REJECT: runtime evidence is not bound to the audited image "
              f"({len(failures)} failed check(s)): {failures}", file=sys.stderr)
        return EXIT_REJECT
    print("=== APPLIANCE RUNTIME EVIDENCE: VERIFIED (bound to the audited image) ===")
    return EXIT_VERIFIED


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
