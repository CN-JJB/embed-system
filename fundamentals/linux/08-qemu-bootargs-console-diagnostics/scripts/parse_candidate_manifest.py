#!/usr/bin/env python3
"""
P3-M04 Candidate Launch Manifest parser / normalizer (SINGLE SOURCE OF TRUTH).

The candidate submission is a DATA-ONLY manifest (declarative KEY=value
lines). It is never arbitrary shell: there is no command, no substitution,
no environment expansion, and no way for the candidate to smuggle an
invocation that disagrees with its declarations.

This parser is the only place where candidate launch configuration is
interpreted:

  parse -> validate (schema, duplicates, conflicts, canonical values)
        -> build the QEMU argv from those exact values
        -> emit normalized argv + provenance (fingerprint)

The trusted runner (scripts/run_candidate_manifest.sh), the learner-safe
self-check (scripts/verify_boot_contract.sh) and the reviewer grading oracle
all consume THIS script, so declarations and the executed invocation cannot
diverge.

Manifest schema (exactly these keys, exactly once each):

    MACHINE=virt,highmem=off,gic-version=2
    CPU=cortex-a7
    MEM=512M
    SMP=1
    NOGRAPHIC=true
    BOOTARGS=earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init

Unknown keys, duplicate keys, missing keys, malformed values, and
non-canonical values are all REJECTED, so a candidate cannot carry a
correct-looking declaration that the runner then ignores.

Exit codes: 0 = accepted, 2 = REJECT (semantic), 1 = usage/internal error.
"""

import argparse
import hashlib
import os
import re
import shlex
import sys

MANIFEST_SCHEMA = ("MACHINE", "CPU", "MEM", "SMP", "NOGRAPHIC", "BOOTARGS")

# Canonical P3 Phase 3 platform contract (pinned: QEMU virt / Cortex-A7).
CANONICAL_MACHINE = "virt,highmem=off,gic-version=2"
CANONICAL_CPU = "cortex-a7"
CANONICAL_MEM = "512M"
CANONICAL_SMP = "1"
CANONICAL_BOOTARGS = "earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init"

# Tokens whose presence in BOOTARGS is required, exactly once each.
REQUIRED_BOOTARG_TOKENS = (
    "earlycon=pl011,0x09000000",
    "console=ttyAMA0,115200",
    "rdinit=/init",
)

KEY_RE = re.compile(r"^[A-Z][A-Z0-9_]*$")
BOOTARG_TOKEN_RE = re.compile(r"^[A-Za-z0-9_.@,:=/+_-]+$")
SHELL_METACHAR_RE = re.compile(r"[`$\\\"'<>|&;*?(){}\[\]!~]")
ASSIGN_RE = re.compile(r"^[A-Z][A-Z0-9_]*=.*$")

REJECTIONS = []


def reject(msg):
    REJECTIONS.append(msg)


def strip_value(raw):
    """Normalize an unquoted/quoted manifest value; no expansion allowed."""
    val = raw.strip()
    if len(val) >= 2 and val[0] == val[-1] and val[0] in ("'", '"'):
        val = val[1:-1]
    return val


def parse_manifest(path):
    """Return (ordered dict, list-of-errors). Data-only; nothing is executed."""
    entries = {}
    errors = []
    try:
        with open(path, "r", encoding="utf-8") as fp:
            lines = fp.readlines()
    except OSError as exc:
        return {}, [f"cannot read candidate manifest '{path}': {exc}"]

    for lineno, raw in enumerate(lines, 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if not ASSIGN_RE.match(line):
            errors.append(
                f"line {lineno}: non-declarative content is not permitted in a "
                f"data-only candidate manifest (expected 'KEY=value'): {line!r}")
            continue
        key, _, raw_val = line.partition("=")
        key = key.strip()
        if not KEY_RE.match(key):
            errors.append(f"line {lineno}: malformed manifest key {key!r}")
            continue
        if key not in MANIFEST_SCHEMA:
            errors.append(
                f"line {lineno}: unknown manifest key {key!r} "
                f"(allowed: {', '.join(MANIFEST_SCHEMA)})")
            continue
        if key in entries:
            errors.append(
                f"line {lineno}: duplicate definition of {key} "
                f"(exactly one definition per key is required)")
            continue
        val = strip_value(raw_val)
        if not val:
            errors.append(f"line {lineno}: {key} has an empty value")
            continue
        if SHELL_METACHAR_RE.search(val):
            errors.append(
                f"line {lineno}: {key} contains shell metacharacters "
                f"(data-only manifest: no command substitution/quoting tricks)")
            continue
        entries[key] = val

    for key in MANIFEST_SCHEMA:
        if key not in entries:
            errors.append(f"missing required manifest key {key}")
    return entries, errors


def validate_bootargs(bootargs):
    """Semantic canonical bootargs contract: exact three-token set, no extras.

    The scored M04 candidate manifest must carry exactly the canonical
    semantic token set (order-insensitive):
      earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init
    No additional kernel command-line tokens are permitted in the scored
    manifest. Optional debug args belong in a separate non-scored
    diagnostic profile, never silently in the canonical Gate manifest.
    """
    for meta in SHELL_METACHAR_RE.findall(bootargs):
        reject(f"BOOTARGS contains shell metacharacter {meta!r}")
    tokens = bootargs.split()
    if not tokens:
        reject("BOOTARGS is empty")
        return
    for tok in tokens:
        if not BOOTARG_TOKEN_RE.match(tok):
            reject(f"BOOTARGS token {tok!r} is not a well-formed kernel parameter")

    consoles = [t for t in tokens if t.startswith("console=")]
    if not consoles:
        reject("BOOTARGS is missing a 'console=' parameter")
    elif len(consoles) != 1:
        reject(
            "BOOTARGS carries %d 'console=' tokens; the canonical Phase 3 "
            "contract requires exactly one ('console=ttyAMA0,115200'). Real "
            "Linux binds repeated same-type consoles first-of-type, not "
            "last-wins, so duplicates/conflicts are not canonical."
            % len(consoles))
    elif consoles[0] != "console=ttyAMA0,115200":
        reject("BOOTARGS console token is %r, expected 'console=ttyAMA0,115200'"
               % consoles[0])

    for tok in REQUIRED_BOOTARG_TOKENS:
        hits = [t for t in tokens if t == tok]
        if not hits:
            reject(f"BOOTARGS missing required canonical token {tok!r}")
        elif len(hits) > 1:
            reject(f"BOOTARGS repeats token {tok!r} ({len(hits)} occurrences)")

    if len(tokens) != len(set(tokens)):
        dupes = sorted({t for t in tokens if tokens.count(t) > 1})
        reject(f"BOOTARGS contains duplicate tokens: {dupes}")

    # Exact canonical semantic token set, actively enforced via
    # CANONICAL_BOOTARGS (order-insensitive set comparison, no extras).
    canonical_set = set(CANONICAL_BOOTARGS.split())
    token_set = set(tokens)
    if token_set != canonical_set:
        extras = sorted(token_set - canonical_set)
        if extras:
            reject(
                "BOOTARGS carries extra non-canonical token(s) %r; scored "
                "canonical manifest requires exactly '%s' (no additional "
                "kernel args)" % (extras, CANONICAL_BOOTARGS))
    if len(tokens) != len(canonical_set):
        if len(tokens) > len(canonical_set):
            reject(
                "BOOTARGS carries %d tokens; scored canonical manifest "
                "requires exactly %d ('%s')" % (
                    len(tokens), len(canonical_set), CANONICAL_BOOTARGS))


def validate_machine(value):
    if value != CANONICAL_MACHINE:
        reject(
            "MACHINE is %r, expected canonical %r "
            "(virt + highmem=off + gic-version=2)" % (value, CANONICAL_MACHINE))
        return
    for part in ("virt", "highmem=off", "gic-version=2"):
        if part not in value.split(","):
            reject(f"MACHINE missing canonical component {part!r}")


def validate_cpu(value):
    if value != CANONICAL_CPU:
        reject("CPU is %r, expected canonical %r" % (value, CANONICAL_CPU))


def validate_mem(value):
    if value != CANONICAL_MEM:
        reject("MEM is %r, expected canonical %r" % (value, CANONICAL_MEM))


def validate_smp(value):
    if value != CANONICAL_SMP:
        reject("SMP is %r, expected canonical %r" % (value, CANONICAL_SMP))


def validate_nographic(value):
    if value.lower() not in ("true", "yes", "1"):
        reject("NOGRAPHIC is %r; canonical headless serial launch requires "
               "NOGRAPHIC=true" % value)


def build_argv(entries, kernel, initrd, qemu_bin):
    """Construct the real QEMU argv from the candidate's own values."""
    return [
        qemu_bin,
        "-machine", entries["MACHINE"],
        "-cpu", entries["CPU"],
        "-m", entries["MEM"],
        "-smp", entries["SMP"],
        "-nographic",
        "-kernel", kernel,
        "-initrd", initrd,
        "-append", entries["BOOTARGS"],
    ]


def provenance_of(argv):
    return "\n".join(shlex.quote(a) for a in argv)


def fingerprint(argv):
    return hashlib.sha256(provenance_of(argv).encode("utf-8")).hexdigest()


def emit_kv(**kw):
    for key, val in kw.items():
        print("%s=%s" % (key, val))


def main(argv):
    ap = argparse.ArgumentParser(
        description="P3-M04 data-only candidate launch manifest parser")
    ap.add_argument("--manifest", "-m", required=True,
                    help="candidate manifest path (data-only KEY=value)")
    ap.add_argument("--kernel", default="", help="kernel zImage path")
    ap.add_argument("--initrd", default="", help="initramfs archive path")
    ap.add_argument("--qemu-bin", default="qemu-system-arm")
    ap.add_argument("--require-executables", action="store_true",
                    help="also require kernel/initrd files to exist")
    args = ap.parse_args(argv)

    if not os.path.isfile(args.manifest):
        print("REJECT: candidate manifest not found: %s" % args.manifest,
              file=sys.stderr)
        return 2

    entries, errors = parse_manifest(args.manifest)
    for err in errors:
        reject(err)

    if not errors:
        validate_machine(entries["MACHINE"])
        validate_cpu(entries["CPU"])
        validate_mem(entries["MEM"])
        validate_smp(entries["SMP"])
        validate_nographic(entries["NOGRAPHIC"])
        validate_bootargs(entries["BOOTARGS"])

    if REJECTIONS:
        print("REJECT: candidate launch manifest '%s' is not canonical:"
              % args.manifest, file=sys.stderr)
        for r in REJECTIONS:
            print("  - %s" % r, file=sys.stderr)
        return 2

    kernel = args.kernel
    initrd = args.initrd
    if args.require_executables:
        missing = [p for p in (kernel, initrd) if not p or not os.path.isfile(p)]
        if missing:
            print("ERROR: required runtime input missing: %s"
                  % ", ".join(repr(m) for m in missing), file=sys.stderr)
            return 1
    if not kernel:
        kernel = "$KERNEL"
    if not initrd:
        initrd = "$INITRD"

    qemu_argv = build_argv(entries, kernel, initrd, args.qemu_bin)

    emit_kv(
        MACHINE=entries["MACHINE"],
        CPU=entries["CPU"],
        MEM=entries["MEM"],
        SMP=entries["SMP"],
        NOGRAPHIC="true",
        BOOTARGS=entries["BOOTARGS"],
        KERNEL=kernel,
        INITRD=initrd,
        QEMU_BIN=args.qemu_bin,
        ARGV_FINGERPRINT=fingerprint(qemu_argv),
    )
    print("ARGV_BEGIN")
    print(provenance_of(qemu_argv))
    print("ARGV_END")

    if REJECTIONS:
        return 2
    print("[PASS] Candidate manifest parsed and normalized: declarations and "
          "the constructed QEMU argv are the same source of truth.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
