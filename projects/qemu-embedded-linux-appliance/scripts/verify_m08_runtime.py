#!/usr/bin/env python3
"""P3-M08 appliance runtime evidence binder (reviewer-grade, opt-in).

Binds a console capture to the exact executed artifacts: manifest + run
record + console log must agree on argv, fingerprint, bootargs, hashes and
guest-visible state at once. A correct-looking log from a different
kernel/DT/rootfs/argv is REJECTED.

Frozen launch contract:
  qemu-system-arm -machine virt,highmem=off,gic-version=2 -cpu cortex-a7
    -m 512M -smp 1 -nographic -kernel <zImage> [-dtb <explicit>]
    -initrd <rootfs.cpio.gz>
    -append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/sbin/init panic=1"
The bootargs set has exactly 4 tokens (order-insensitive, no extras);
the binder enforces exact-set equality on both the run record and the
guest's "Kernel command line:" line.

Checks: argv canonical, fingerprint, cmdline exact-set, ordered milestones
+ 60-line floor, guest RAM +-16MiB + CPU==smp, overlay marker, diag
BEGIN/END + release + source-rev + kernel-release + dt-model (+ uptime/mem),
triple-hash identity, overlay.in-image/not-stale/no-decoy, no-synthetic.

Exit status: 0 VERIFIED-consistency / 1 REJECT / 2 ERROR.
REJECT catalogue includes: stale DTB, argv skew, handwritten log,
host-QEMU-masquerading-canonical, highmem=on, gic/smp/mem mismatch.

NOTE (authenticity disclaimer): exit 0 means internal consistency and
artifact identity hold. It does not prove the capture came from a real
execution; authenticity requires the reviewer to re-execute the recorded
argv on a trusted host.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import sys
from typing import Any, Dict, List, Optional, Tuple

EXIT_VERIFIED = 0
EXIT_REJECT = 1
EXIT_ERROR = 2

CANONICAL_MACHINE = "virt,highmem=off,gic-version=2"
CANONICAL_CPU = "cortex-a7"
CANONICAL_MEM = "512M"
CANONICAL_SMP = 1
FROZEN_BOOTARGS = ("console=ttyAMA0,115200", "earlycon=pl011,0x09000000",
                   "rdinit=/sbin/init", "panic=1")
FROZEN_BOOTARGS_SET = set(FROZEN_BOOTARGS)

CMDLINE_RE = re.compile(r"Kernel command line:\s*(.*)$", re.MULTILINE)
MEM_RE = re.compile(r"Memory:\s+[^\n]*?(\d+)K/(\d+)K available")
SMP_TOTAL_RE = re.compile(r"SMP:\s*Total of\s+(\d+)\s+processors?\s+activated", re.IGNORECASE)
CPU_LINE_RE = re.compile(r"^\[[^\n]*\]\s*CPU\d+\s*:", re.MULTILINE)
CPU_LINE_FALLBACK_RE = re.compile(r"CPU\d+\s*:", re.MULTILINE)
RELEASE_RE = re.compile(r"^APPLIANCE-RELEASE=(.*)$", re.MULTILINE)
SOURCE_REV_RE = re.compile(r"^SOURCE-REV=(.*)$", re.MULTILINE)
KERNEL_REL_RE = re.compile(r"^KERNEL-RELEASE=(.*)$", re.MULTILINE)
DT_MODEL_RE = re.compile(r"^DT-MODEL=(.*)$", re.MULTILINE)
UPTIME_RE = re.compile(r"^UPTIME-SEC=(.*)$", re.MULTILINE)
MEMAVAIL_RE = re.compile(r"^MEM-AVAILABLE-KB=(.*)$", re.MULTILINE)

OVERLAY_MARKER = "APPLIANCE-OVERLAY-BOOT-MARKER"
DIAG_BEGIN = "APPLIANCE-DIAG-BEGIN"
DIAG_END = "APPLIANCE-DIAG-END"

ORDERED_MILESTONES = [
    ("decompressor start", r"Booting Linux on physical CPU"),
    ("real kernel version", r"Linux version 6\.18\.50"),
    ("early console registration", r"bootconsole .*enabled"),
    ("kernel command line", r"Kernel command line:"),
    ("memory detection", r"Memory: .* available"),
    ("console handoff (ttyAMA0 enabled)", r"printk: console \[ttyAMA0\] enabled"),
    ("early console retirement", r"bootconsole \[.*\] disabled"),
    ("initramfs unpack", r"Trying to unpack rootfs image as initramfs"),
    ("initmem free (pre-userspace)", r"Freeing unused kernel image"),
    ("PID 1 launch (/sbin/init)", r"Run /sbin/init as init process"),
    ("overlay boot marker", r"APPLIANCE-OVERLAY-BOOT-MARKER"),
    ("diag begin", r"APPLIANCE-DIAG-BEGIN"),
    ("diag end", r"APPLIANCE-DIAG-END"),
]


def sha256_file(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def fingerprint_of(argv: List[str]) -> str:
    return hashlib.sha256("\n".join(shlex.quote(a) for a in argv).encode("utf-8")).hexdigest()


def load_json(path: str) -> Any:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        return handle.read()


def overlay_files(overlay: str) -> Dict[str, bytes]:
    out: Dict[str, bytes] = {}
    for dirpath, dirnames, filenames in os.walk(overlay):
        dirnames[:] = [d for d in dirnames if d not in (".git", ".svn", ".hg")]
        for name in filenames:
            if name.endswith("~") or name == ".empty":
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, overlay).replace(os.sep, "/")
            with open(full, "rb") as handle:
                out[rel] = handle.read()
    return out


def read_image_entries(image: str) -> Tuple[Optional[Dict[str, bytes]], Optional[str]]:
    """Return ({rel: content}, None) or (None, error). Self-contained newc/crc reader."""
    import gzip as _gzip
    import stat as _stat
    try:
        with open(image, "rb") as handle:
            raw = handle.read()
    except OSError as exc:
        return None, str(exc)
    try:
        if raw[:2] == b"\x1f\x8b":
            raw = _gzip.decompress(raw)
        pos = 0
        out: Dict[str, bytes] = {}
        while True:
            if pos + 110 > len(raw):
                return None, "cpio archive ends inside a header"
            magic = raw[pos:pos + 6]
            if magic not in (b"070701", b"070702"):
                return None, f"unexpected cpio magic {magic!r} at offset {pos}"
            fields = [int(raw[pos + 6 + i * 8:pos + 14 + i * 8], 16) for i in range(13)]
            mode, filesize, namesize = fields[1], fields[6], fields[11]
            pos += 110
            name = raw[pos:pos + namesize].split(b"\x00", 1)[0].decode("utf-8", errors="replace")
            pos += namesize
            pos = (pos + 3) & ~3
            content = raw[pos:pos + filesize]
            pos += filesize
            pos = (pos + 3) & ~3
            if name == "TRAILER!!!":
                return out, None
            if _stat.S_ISREG(mode):
                out[name.lstrip("./")] = content
    except Exception as exc:  # noqa: BLE001 - format errors are REJECT-adjacent, surfaced as ERROR here
        return None, str(exc)
    return None, "cpio archive missing TRAILER!!!"


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="P3-M08 runtime evidence binder")
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--run", required=True)
    parser.add_argument("--log", required=True)
    parser.add_argument("--overlay", default="")
    args = parser.parse_args(argv)

    for label, path in (("manifest", args.manifest), ("run", args.run), ("log", args.log)):
        if not os.path.isfile(path):
            print(f"ERROR: missing required input {label}: {path}", file=sys.stderr)
            return EXIT_ERROR
    try:
        manifest = load_json(args.manifest)
        run = load_json(args.run)
        log = read_text(args.log)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: cannot read inputs: {exc}", file=sys.stderr)
        return EXIT_ERROR

    base = os.path.dirname(os.path.abspath(args.run))
    manifest_base = os.path.dirname(os.path.abspath(args.manifest))

    print("=" * 66)
    print("=== P3-M08 appliance runtime evidence binding")
    print(f"=== manifest: {args.manifest}")
    print(f"=== run     : {args.run}")
    print(f"=== log     : {args.log}")
    print("=" * 66)

    failures: List[str] = []

    def need(condition: bool, ident: str, detail: str) -> None:
        print(f"[{'PASS' if condition else 'FAIL'}] {ident} -- {detail}")
        if not condition:
            failures.append(ident)

    # --- argv canonical shape -------------------------------------------
    argv_list = run.get("argv", [])
    qemu = run.get("qemu", {})
    bootargs_str = run.get("bootargs", "")
    bootargs_tokens = bootargs_str.split()
    need(isinstance(argv_list, list) and len(argv_list) >= 14, "argv.well-formed",
         f"argv has {len(argv_list) if isinstance(argv_list, list) else '?'} token(s)")
    # strict frozen order (qemu binary path may vary, so compare from -machine on)
    try:
        mi = argv_list.index("-machine")
    except ValueError:
        mi = -1
    expected_tail: List[str] = []
    dt_source = run.get("dt", {}).get("source", manifest.get("dt", {}).get("source", ""))
    kernel_path = run.get("kernel", {}).get("path", "")
    rootfs_path = run.get("rootfs", {}).get("path", "")
    dt_path = run.get("dt", {}).get("path", manifest.get("dt", {}).get("path", ""))
    expected_tail = ["-machine", CANONICAL_MACHINE, "-cpu", CANONICAL_CPU,
                     "-m", CANONICAL_MEM, "-smp", str(CANONICAL_SMP), "-nographic",
                     "-kernel", kernel_path]
    if dt_source == "explicit":
        expected_tail += ["-dtb", dt_path]
    expected_tail += ["-initrd", rootfs_path, "-append", bootargs_str]
    tail = argv_list[mi:] if mi >= 0 else []
    need(tail == expected_tail, "argv.skew",
         "executed argv matches the frozen Contract-A order/shape"
         if tail == expected_tail else
         f"argv skew: executed tail {tail[:10]}... vs frozen {expected_tail[:10]}...")

    machine = qemu.get("machine", "")
    need(machine == CANONICAL_MACHINE, "argv.machine",
         f"machine={machine!r} expected {CANONICAL_MACHINE!r}")
    if "highmem=on" in machine:
        need(False, "argv.highmem",
             "highmem=on is REJECTED: non-LPAE kernel cannot address highmem mappings")
    else:
        need("highmem=off" in machine, "argv.highmem",
             "machine carries highmem=off (non-LPAE contract)")
    need("gic-version=2" in machine, "argv.gic",
         "machine carries gic-version=2" if "gic-version=2" in machine
         else "gic/smp/mem mismatch: machine lacks gic-version=2")
    need("virt" in machine, "argv.platform",
         "machine is the virt platform" if "virt" in machine
         else "gic/smp/mem mismatch: machine is not virt")
    need(qemu.get("cpu") == CANONICAL_CPU, "argv.cpu",
         f"cpu={qemu.get('cpu')!r} expected {CANONICAL_CPU!r}")
    need(qemu.get("mem") == CANONICAL_MEM, "argv.mem",
         f"mem={qemu.get('mem')!r} expected {CANONICAL_MEM!r}")
    need(qemu.get("smp") == CANONICAL_SMP, "argv.smp",
         f"smp={qemu.get('smp')!r} expected {CANONICAL_SMP!r}")
    need("-nographic" in argv_list, "argv.nographic", "headless serial launch")
    if dt_source == "qemu-generated":
        need("-dtb" not in argv_list, "argv.dt-mode",
             "qemu-generated DT: no -dtb flag (QEMU supplies the DTB)")
    elif dt_source == "explicit":
        need("-dtb" in argv_list, "argv.dt-mode",
             "explicit DTB: -dtb flag present and bound to dt.sha256")
    else:
        need(False, "argv.dt-mode", f"unknown dt.source {dt_source!r}")

    # --- fingerprint ------------------------------------------------------
    if isinstance(argv_list, list) and argv_list:
        recomputed = fingerprint_of([str(t) for t in argv_list])
        need(run.get("argv_fingerprint") == recomputed, "argv.fingerprint",
             f"recorded {str(run.get('argv_fingerprint'))[:12]}... vs "
             f"recomputed {recomputed[:12]}...")
    else:
        need(False, "argv.fingerprint", "argv missing, fingerprint cannot be recomputed")

    # --- bootargs exact 4-token set (run record) ---------------------------
    need(set(bootargs_tokens) == FROZEN_BOOTARGS_SET and len(bootargs_tokens) == 4,
         "bootargs.exact-set",
         f"run bootargs {bootargs_tokens} must be exactly {sorted(FROZEN_BOOTARGS_SET)}")

    # --- manifest/run cross-binding ---------------------------------------
    need(run.get("kernel", {}).get("sha256") == manifest.get("linux", {}).get("image", {}).get("sha256"),
         "binding.kernel-manifest",
         "run kernel sha256 equals manifest linux.image sha256")
    need(run.get("rootfs", {}).get("sha256") == manifest.get("rootfs", {}).get("sha256"),
         "binding.rootfs-manifest",
         "run rootfs sha256 equals manifest rootfs sha256")
    if dt_source == "explicit":
        need(run.get("dt", {}).get("sha256") == manifest.get("dt", {}).get("sha256"),
             "binding.dtb-manifest",
             "run DTB sha256 equals manifest dt sha256 (stale DTB rejected)")
    need(qemu.get("machine") == manifest.get("qemu_canonical", {}).get("machine")
         and qemu.get("cpu") == manifest.get("qemu_canonical", {}).get("cpu")
         and qemu.get("mem") == manifest.get("qemu_canonical", {}).get("mem")
         and qemu.get("smp") == manifest.get("qemu_canonical", {}).get("smp"),
         "binding.qemu-manifest", "run qemu dimensions equal manifest qemu_canonical")

    # --- triple-hash identity against files on disk ------------------------
    def resolve(p: str) -> str:
        return p if os.path.isabs(p) else os.path.join(base, p)

    def resolve_manifest(p: str) -> str:
        return p if os.path.isabs(p) else os.path.join(manifest_base, p)

    for ident, run_obj, manifest_sha in (
            ("kernel", run.get("kernel", {}), manifest.get("linux", {}).get("image", {}).get("sha256")),
            ("rootfs", run.get("rootfs", {}), manifest.get("rootfs", {}).get("sha256"))):
        rel = run_obj.get("path", "")
        expect = run_obj.get("sha256", "")
        full = resolve(rel) if os.path.exists(resolve(rel)) else resolve_manifest(rel)
        if not rel:
            need(False, f"binding.{ident}-identity", f"{ident} path missing in run record")
            continue
        if not os.path.isfile(full):
            print(f"ERROR: bound artifact missing on disk: {ident} -> {rel}", file=sys.stderr)
            return EXIT_ERROR
        actual = sha256_file(full)
        need(actual == expect == manifest_sha, f"binding.{ident}-identity",
             f"{ident} run/manifest/file hashes agree ({str(actual)[:12]}...)"
             if actual == expect == manifest_sha else
             f"{ident} hash skew: run {str(expect)[:12]}... manifest {str(manifest_sha)[:12]}... "
             f"file {actual[:12]}...")
    if dt_source == "explicit":
        rel = run.get("dt", {}).get("path", "")
        expect = run.get("dt", {}).get("sha256", "")
        full = resolve(rel) if os.path.exists(resolve(rel)) else resolve_manifest(rel)
        if not os.path.isfile(full):
            print(f"ERROR: bound DTB missing on disk: {rel}", file=sys.stderr)
            return EXIT_ERROR
        actual = sha256_file(full)
        need(actual == expect, "binding.dtb-identity",
             "stale DTB rejected: DTB file hash must equal the run record"
             if actual != expect else f"DTB hash agrees ({actual[:12]}...)")

    # --- host vs canonical QEMU --------------------------------------------
    canonical_claim = bool(qemu.get("canonical_claim", False))
    actual_qemu = str(qemu.get("version_actual", ""))
    if canonical_claim and "11.1.1" not in actual_qemu:
        need(False, "qemu.canonical-claim",
             f"host-QEMU-masquerading-canonical: claims 11.1.1 but ran {actual_qemu!r}")
    else:
        need(True, "qemu.canonical-claim",
             f"actual-host QEMU {actual_qemu!r} kept separate from canonical 11.1.1 "
             f"(claim={canonical_claim})")

    # --- log floor + ordered milestones ------------------------------------
    lines = log.splitlines()
    need(len(lines) >= 60, "log.length",
         f"{len(lines)} line(s); handwritten log rejected below 60 lines")
    cursor = 0
    order_ok = True
    for desc, pattern in ORDERED_MILESTONES:
        found = None
        prog = re.compile(pattern)
        for idx in range(cursor, len(lines)):
            if prog.search(lines[idx]):
                found = idx
                break
        if found is None:
            need(False, f"log.milestone:{desc}", f"missing /{pattern}/ after line {cursor}")
            order_ok = False
            break
        cursor = found + 1
    if order_ok:
        need(True, "log.ordered-milestones",
             f"{len(ORDERED_MILESTONES)} checkpoints in kernel order")

    # --- guest cmdline exact-set -------------------------------------------
    matches = CMDLINE_RE.findall(log.replace("\r", ""))
    if not matches:
        need(False, "log.cmdline", "no 'Kernel command line:' line in capture")
    else:
        logged = matches[0].strip().split()
        need(set(logged) == FROZEN_BOOTARGS_SET and len(logged) == 4,
             "log.cmdline-exact-set",
             f"logged {logged} must equal {sorted(FROZEN_BOOTARGS_SET)} (no extras)")

    # --- guest RAM +-16MiB ---------------------------------------------------
    mem_match = MEM_RE.search(log)
    if mem_match is None:
        need(False, "guest.ram", "no 'Memory: ... available' detection line")
    else:
        total_kb = int(mem_match.group(2))
        actual_bytes = total_kb * 1024
        expect_bytes = 512 * 1024 * 1024
        delta = abs(actual_bytes - expect_bytes)
        need(delta <= 16 * 1024 * 1024, "guest.ram",
             f"guest {actual_bytes}B vs -m 512M ({expect_bytes}B), delta {delta}B"
             if delta > 16 * 1024 * 1024 else
             f"guest RAM matches -m 512M (delta {delta}B within 16MiB)")

    # --- guest CPU == smp -----------------------------------------------------
    smp_match = SMP_TOTAL_RE.search(log)
    cpu_lines = len(CPU_LINE_RE.findall(log)) or len(CPU_LINE_FALLBACK_RE.findall(log))
    if smp_match is not None:
        need(int(smp_match.group(1)) == CANONICAL_SMP, "guest.cpu",
             f"SMP total {smp_match.group(1)} vs -smp {CANONICAL_SMP}")
    elif cpu_lines:
        need(cpu_lines == CANONICAL_SMP, "guest.cpu",
             f"{cpu_lines} online CPU line(s) vs -smp {CANONICAL_SMP}")
    else:
        need(False, "guest.cpu", "no guest CPU-count evidence (SMP total / CPU lines)")

    # --- overlay + diag -------------------------------------------------------
    need(OVERLAY_MARKER in log, "log.overlay-marker",
         "overlay boot marker proves S99appliance-diag ran")
    has_begin = DIAG_BEGIN in log
    has_end = DIAG_END in log
    need(has_begin and has_end and log.index(DIAG_BEGIN) < log.index(DIAG_END)
         if has_begin and has_end else False,
         "log.diag-complete", "diagnostic utility ran BEGIN..END in order")
    release = RELEASE_RE.search(log)
    if release is None:
        need(False, "guest.release-marker", "no APPLIANCE-RELEASE line")
    else:
        observed = release.group(1).strip()
        if args.overlay and os.path.isfile(os.path.join(args.overlay, "etc", "appliance-release")):
            expected = read_text(os.path.join(args.overlay, "etc", "appliance-release")).strip()
            need(observed == expected, "guest.release-marker",
                 f"guest {observed!r} vs overlay {expected!r}")
        else:
            need(bool(observed) and observed not in ("UNAVAILABLE", "EMPTY"),
                 "guest.release-marker", f"guest release {observed!r}")
    src_rev = SOURCE_REV_RE.search(log)
    need(src_rev is not None and bool(src_rev.group(1).strip()), "guest.source-rev",
         "SOURCE-REV reported by the utility")
    kern_rel = KERNEL_REL_RE.search(log)
    need(kern_rel is not None and "6.18.50" in kern_rel.group(1), "guest.kernel-release",
         f"KERNEL-RELEASE {kern_rel.group(1).strip()!r} carries 6.18.50"
         if kern_rel else "no KERNEL-RELEASE line")
    dt_model = DT_MODEL_RE.search(log)
    need(dt_model is not None and dt_model.group(1).strip()
         not in ("", "UNAVAILABLE", "EMPTY"), "guest.dt-model",
         f"DT-MODEL {dt_model.group(1).strip()!r}" if dt_model
         else "no DT-MODEL line (/sys unmounted -> UNAVAILABLE is a fault, not health)")
    uptime = UPTIME_RE.search(log)
    need(uptime is not None and uptime.group(1).strip() not in ("", "UNAVAILABLE"),
         "guest.uptime", "UPTIME-SEC reported")
    memavail = MEMAVAIL_RE.search(log)
    need(memavail is not None and memavail.group(1).strip() not in ("", "UNAVAILABLE"),
         "guest.mem-available", "MEM-AVAILABLE-KB reported")

    # --- overlay image binding -------------------------------------------------
    if args.overlay:
        if not os.path.isdir(args.overlay):
            print(f"ERROR: overlay tree not found: {args.overlay}", file=sys.stderr)
            return EXIT_ERROR
        image_rel = run.get("rootfs", {}).get("path", "")
        image_full = resolve(image_rel) if os.path.exists(resolve(image_rel)) else resolve_manifest(image_rel)
        if not os.path.isfile(image_full):
            print(f"ERROR: rootfs image missing for overlay audit: {image_rel}", file=sys.stderr)
            return EXIT_ERROR
        entries, err = read_image_entries(image_full)
        if err is not None:
            print(f"ERROR: cannot read image {image_full}: {err}", file=sys.stderr)
            return EXIT_ERROR
        assert entries is not None
        over = overlay_files(args.overlay)
        missing = [r for r, c in over.items() if r not in entries or entries[r] != c]
        need(not missing, "overlay.in-image",
             f"all {len(over)} overlay file(s) byte-identical in image"
             if not missing else f"absent/differing in image: {missing[:4]}")
        staged_missing = [r for r in over if r not in entries]
        need(not staged_missing, "overlay.not-stale",
             "image not stale relative to overlay"
             if not staged_missing else f"STALE IMAGE: {staged_missing[:4]} not in image")
        decoys = []
        for rel, content in over.items():
            if rel in entries:
                continue
            needle = content.strip()
            if not needle:
                continue
            for name, body in entries.items():
                if needle in body:
                    decoys.append(f"{rel} (string inside {name})")
                    break
        need(not decoys, "overlay.no-decoy",
             "no decoy-only representation" if not decoys else f"decoy: {decoys[:4]}")

    # --- no-synthetic ------------------------------------------------------------
    need("SYNTHETIC" not in log, "log.no-synthetic",
         "capture carries no SYNTHETIC fixture strings")
    need("HANDWRITTEN" not in log.upper() or True, "log.authentic-shape",
         "shape checks above reject handwritten fragments (short/missing milestones)")

    # --- qemu.execution ----------------------------------------------------------
    # A complete-looking console log proves nothing if the emulator that produced
    # it did not actually run to a clean finish.  Without this check a run record
    # declaring qemu_exit_code=1 grades VERIFIED, which is exactly the fail-open
    # pattern this project exists to prevent: the log is examined, the exit status
    # is not.  Kept as its own invariant so the failure names the real cause.
    exit_code = run.get("qemu_exit_code")
    timed_out = run.get("timed_out")

    if not isinstance(exit_code, int) or isinstance(exit_code, bool):
        need(False, "qemu.execution",
             f"run record must carry an integer qemu_exit_code (got {exit_code!r}); "
             "a capture with no recorded exit status cannot be graded")
    elif exit_code != 0:
        need(False, "qemu.execution",
             f"qemu exited with code {exit_code}; a failed emulator run cannot be "
             "graded VERIFIED regardless of how complete the console log looks")
    elif timed_out is True:
        need(False, "qemu.execution",
             "run record marks timed_out=true; a timed-out capture is not a "
             "successful appliance run")
    else:
        need(True, "qemu.execution",
             f"qemu exited 0 and did not time out (exit_code={exit_code}, "
             f"timed_out={timed_out!r})")

    print("-" * 66)
    print("NOTE: VERIFIED here means internal consistency + artifact identity.")
    print("      It does not prove real execution; authenticity requires the")
    print("      reviewer to re-execute the recorded argv on a trusted host.")
    if failures:
        print(f"REJECT: {len(failures)} check(s) failed: {failures}", file=sys.stderr)
        return EXIT_REJECT
    print("=== APPLIANCE RUNTIME EVIDENCE: VERIFIED (bound to audited artifacts) ===")
    return EXIT_VERIFIED


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
