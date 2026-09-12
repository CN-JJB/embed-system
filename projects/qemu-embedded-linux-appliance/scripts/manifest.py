#!/usr/bin/env python3
"""P3-M08 appliance input manifest write + validate (m08-manifest-v1).

Writes a pinned manifest with SHA256-bound artifact identities, or validates
an existing manifest against manifest.schema.json semantics.

Manifest top-level fields (exact, see manifest.schema.json):
  linux / qemu_canonical / busybox / buildroot / dtc / dtspec /
  toolchain / kernel_config / dt / rootfs / repo / created_utc

DT dual-mode:
  dt.source == "qemu-generated" -> no -dtb flag, no path/sha256 keys.
  dt.source == "explicit"       -> path + sha256 required, bound to -dtb.

Exit status: 0 PASS / 1 REJECT (schema or semantic mismatch) /
             2 ERROR (missing input, unreadable file, missing dependency).
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import re
import sys
from typing import Any, Dict, List, Optional

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ_ROOT = os.path.dirname(HERE)
DEFAULT_SCHEMA = os.path.join(PROJ_ROOT, "manifest.schema.json")

EXIT_PASS = 0
EXIT_REJECT = 1
EXIT_ERROR = 2

# Frozen canonical pins (Phase 3 platform contract, do not fork).
PIN_LINUX = {"version": "6.18.50", "tag": "v6.18.50",
             "commit": "7cfc41f8e80f11ffa8382ed1a505154ceffb79c7"}
PIN_QEMU = {"version": "11.1.1", "tag": "v11.1.1",
            "commit": "c3d48b7d1e89604920e5b81b91140c2ad39a1943",
            "machine": "virt,highmem=off,gic-version=2",
            "cpu": "cortex-a7", "mem": "512M", "smp": 1}
PIN_BUSYBOX = {"version": "1.36.1",
               "commit": "1a64f6a20aaf6ea4dbba68bbfa8cc1ab7e5c57c4"}
PIN_BUILDROOT = {"version": "2026.05.2", "tag": "2026.05.2",
                 "commit": "72d9d4fa636a371ef9eb99c92a735ce9f6d829d5"}
PIN_DTC = {"version": "v1.7.0",
           "commit": "039a99414e778332d8f9c04cbd3072e1dcc62798"}
PIN_DTSPEC = {"version": "v0.4",
              "commit": "112f53cc57e5931f1503dfcaa1644caf15362c30"}
PIN_TOOLCHAIN = {
    "name": "Arm GNU Toolchain 13.3.rel1",
    "triple": "arm-none-linux-gnueabihf",
    "package": "arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-linux-gnueabihf.tar.xz",
    "sha256": "560267bdecf966b7a48467d0af6c81a85b906ef7b0a9b9dd91f506184b940281",
}
PIN_DEFCONFIG = "multi_v7_defconfig"
PIN_FRAGMENT = {
    "CONFIG_ARCH_VIRT": "y",
    "CONFIG_ARM_LPAE": "n",
    "CONFIG_VMSPLIT_3G": "y",
    "CONFIG_SERIAL_AMBA_PL011": "y",
    "CONFIG_DEVTMPFS": "y",
    "CONFIG_DEVTMPFS_MOUNT": "y",
    "CONFIG_VIRTIO_MMIO": "y",
    "CONFIG_VIRTIO_BLK": "y",
    "CONFIG_EXT4_FS": "y",
}

SHA_RE = re.compile(r"^[0-9a-f]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
UTC_RE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")
REQUIRED_TOP = ("schema", "linux", "qemu_canonical", "busybox", "buildroot",
                "dtc", "dtspec", "toolchain", "kernel_config", "dt",
                "rootfs", "repo", "created_utc")


def sha256_file(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _fail(errors: List[str], msg: str) -> None:
    errors.append(msg)


def validate_manifest(data: Dict[str, Any]) -> List[str]:
    """Return a list of REJECT reasons (empty means schema/semantics hold)."""
    errors: List[str] = []
    if not isinstance(data, dict):
        return ["manifest root is not a JSON object"]
    for key in REQUIRED_TOP:
        if key not in data:
            _fail(errors, f"missing required manifest field {key!r}")
    if errors:
        return errors
    if data.get("schema") != "m08-manifest-v1":
        _fail(errors, "schema must be 'm08-manifest-v1'")
    # linux
    linux = data.get("linux", {})
    for k in ("version", "tag", "commit", "source", "image"):
        if k not in linux:
            _fail(errors, f"linux.{k} missing")
    if linux.get("version") != PIN_LINUX["version"]:
        _fail(errors, f"linux.version must be {PIN_LINUX['version']!r}")
    if linux.get("tag") != PIN_LINUX["tag"]:
        _fail(errors, "linux.tag must be 'v6.18.50'")
    if linux.get("commit") != PIN_LINUX["commit"]:
        _fail(errors, "linux.commit pin mismatch (expected 6.18.50 peeled commit)")
    img = linux.get("image", {})
    if not isinstance(img, dict) or not img.get("path") or not SHA_RE.match(img.get("sha256", "")):
        _fail(errors, "linux.image requires path + 64-hex sha256")
    # qemu_canonical
    qemu = data.get("qemu_canonical", {})
    for k in ("version", "tag", "commit", "machine", "cpu", "mem", "smp"):
        if k not in qemu:
            _fail(errors, f"qemu_canonical.{k} missing")
    if qemu.get("version") != PIN_QEMU["version"]:
        _fail(errors, "qemu_canonical.version must be '11.1.1'")
    if qemu.get("tag") != PIN_QEMU["tag"]:
        _fail(errors, "qemu_canonical.tag must be 'v11.1.1'")
    if qemu.get("commit") != PIN_QEMU["commit"]:
        _fail(errors, "qemu_canonical.commit pin mismatch (expected QEMU 11.1.1 peeled commit)")
    if qemu.get("machine") != PIN_QEMU["machine"]:
        _fail(errors, "qemu_canonical.machine must be 'virt,highmem=off,gic-version=2'")
    if qemu.get("cpu") != PIN_QEMU["cpu"]:
        _fail(errors, "qemu_canonical.cpu must be 'cortex-a7'")
    if qemu.get("mem") != PIN_QEMU["mem"]:
        _fail(errors, "qemu_canonical.mem must be '512M'")
    if qemu.get("smp") != PIN_QEMU["smp"]:
        _fail(errors, "qemu_canonical.smp must be 1")
    # busybox / buildroot / dtc / dtspec
    busybox = data.get("busybox", {})
    if busybox.get("version") != PIN_BUSYBOX["version"] or busybox.get("commit") != PIN_BUSYBOX["commit"]:
        _fail(errors, "busybox pin mismatch (expected 1.36.1 / 1a64f6a...)")
    buildroot = data.get("buildroot", {})
    if (buildroot.get("version") != PIN_BUILDROOT["version"]
            or buildroot.get("tag") != PIN_BUILDROOT["tag"]
            or buildroot.get("commit") != PIN_BUILDROOT["commit"]):
        _fail(errors, "buildroot pin mismatch (expected 2026.05.2)")
    dtc = data.get("dtc", {})
    if dtc.get("version") != PIN_DTC["version"] or dtc.get("commit") != PIN_DTC["commit"]:
        _fail(errors, "dtc pin mismatch (expected v1.7.0)")
    dtspec = data.get("dtspec", {})
    if dtspec.get("version") != PIN_DTSPEC["version"] or dtspec.get("commit") != PIN_DTSPEC["commit"]:
        _fail(errors, "dtspec pin mismatch (expected v0.4)")
    # toolchain
    toolchain = data.get("toolchain", {})
    for k in ("name", "triple", "package", "sha256"):
        if k not in toolchain:
            _fail(errors, f"toolchain.{k} missing")
    if toolchain.get("package") != PIN_TOOLCHAIN["package"]:
        _fail(errors, "toolchain.package pin mismatch (expected 13.3.rel1 tarball)")
    if toolchain.get("sha256") != PIN_TOOLCHAIN["sha256"]:
        _fail(errors, "toolchain.package SHA256 pin mismatch")
    if toolchain.get("triple") != PIN_TOOLCHAIN["triple"]:
        _fail(errors, "toolchain.triple must be 'arm-none-linux-gnueabihf'")
    # kernel_config
    kernel_config = data.get("kernel_config", {})
    if kernel_config.get("defconfig") != PIN_DEFCONFIG:
        _fail(errors, "kernel_config.defconfig must be 'multi_v7_defconfig'")
    fragment = kernel_config.get("fragment", {})
    if not isinstance(fragment, dict):
        _fail(errors, "kernel_config.fragment must be an object")
    else:
        for k, v in PIN_FRAGMENT.items():
            if fragment.get(k) != v:
                _fail(errors, f"kernel_config.fragment.{k} must be {v!r}")
    # dt dual-mode
    dt = data.get("dt", {})
    source = dt.get("source")
    if source not in ("qemu-generated", "explicit"):
        _fail(errors, "dt.source must be 'qemu-generated' or 'explicit'")
    elif source == "explicit":
        if not dt.get("path") or not SHA_RE.match(dt.get("sha256", "")):
            _fail(errors, "dt.source=explicit requires path + 64-hex sha256")
    else:
        if "path" in dt or "sha256" in dt:
            _fail(errors, "dt.source=qemu-generated must not carry path/sha256 (no -dtb)")
    # rootfs
    rootfs = data.get("rootfs", {})
    if rootfs.get("kind") != "initrd":
        _fail(errors, "rootfs.kind must be 'initrd' (Contract-A -initrd rootfs.cpio.gz)")
    if not rootfs.get("path") or not SHA_RE.match(rootfs.get("sha256", "")):
        _fail(errors, "rootfs requires path + 64-hex sha256")
    if not rootfs.get("overlay"):
        _fail(errors, "rootfs.overlay missing (overlay source tree)")
    # repo / created_utc
    if "branch" not in data.get("repo", {}):
        _fail(errors, "repo.branch missing")
    if not UTC_RE.match(data.get("created_utc", "")):
        _fail(errors, "created_utc must be UTC '%Y-%m-%dT%H:%M:%SZ'")
    return errors


def check_bound_files(data: Dict[str, Any], base: str) -> tuple[List[str], List[str]]:
    """Check declared artifact files exist and hashes match.

    Returns (rejects, errors): rejects = hash mismatch (REJECT),
    errors = missing/unreadable file (ERROR).
    """
    rejects: List[str] = []
    errors: List[str] = []

    def resolve(p: str) -> str:
        return p if os.path.isabs(p) else os.path.join(base, p)

    jobs = [
        ("linux.image", data["linux"]["image"]["path"], data["linux"]["image"]["sha256"]),
        ("rootfs", data["rootfs"]["path"], data["rootfs"]["sha256"]),
    ]
    if data["dt"].get("source") == "explicit":
        jobs.append(("dt", data["dt"]["path"], data["dt"]["sha256"]))
    for ident, rel, expect in jobs:
        full = resolve(rel)
        if not os.path.isfile(full):
            errors.append(f"bound artifact missing: {ident} -> {rel}")
            continue
        try:
            actual = sha256_file(full)
        except OSError as exc:
            errors.append(f"cannot hash {ident} ({rel}): {exc}")
            continue
        if actual != expect:
            rejects.append(
                f"hash mismatch: {ident} manifest {expect[:12]}... vs file {actual[:12]}...")
    overlay = data["rootfs"].get("overlay", "")
    if overlay:
        full = resolve(overlay)
        if not os.path.isdir(full):
            errors.append(f"overlay source tree missing: {overlay}")
    return rejects, errors


def build_manifest(kernel: str, rootfs: str, overlay: str, dtb: Optional[str],
                   qemu_generated: bool, branch: str, commit: str) -> Dict[str, Any]:
    # Store ABSOLUTE artifact paths. run_appliance.sh and --check-files resolve
    # relative paths against the manifest's own directory, so a CWD-relative path
    # written from the project root (e.g. "build/br-output/images/zImage" into
    # "build/appliance.manifest.json") would otherwise double up into
    # "build/build/...". Absolute paths are unambiguous and match the absolute
    # paths run_appliance.sh records in the run provenance.
    kernel = os.path.abspath(kernel)
    rootfs = os.path.abspath(rootfs)
    overlay = os.path.abspath(overlay)
    if dtb:
        dtb = os.path.abspath(dtb)
    if not os.path.isfile(kernel):
        print(f"ERROR: kernel image not found: {kernel}", file=sys.stderr)
        raise SystemExit(EXIT_ERROR)
    if not os.path.isfile(rootfs):
        print(f"ERROR: rootfs image not found: {rootfs}", file=sys.stderr)
        raise SystemExit(EXIT_ERROR)
    if not os.path.isdir(overlay):
        print(f"ERROR: overlay tree not found: {overlay}", file=sys.stderr)
        raise SystemExit(EXIT_ERROR)
    dt: Dict[str, Any]
    if qemu_generated:
        dt = {"source": "qemu-generated"}
    else:
        if not dtb or not os.path.isfile(dtb):
            print(f"ERROR: explicit DTB required but not found: {dtb}", file=sys.stderr)
            raise SystemExit(EXIT_ERROR)
        dt = {"source": "explicit", "path": dtb, "sha256": sha256_file(dtb)}
    return {
        "schema": "m08-manifest-v1",
        "linux": {
            "version": PIN_LINUX["version"], "tag": PIN_LINUX["tag"],
            "commit": PIN_LINUX["commit"],
            "source": "git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git",
            "image": {"path": kernel, "sha256": sha256_file(kernel)},
        },
        "qemu_canonical": dict(PIN_QEMU),
        "busybox": dict(PIN_BUSYBOX),
        "buildroot": dict(PIN_BUILDROOT),
        "dtc": dict(PIN_DTC),
        "dtspec": dict(PIN_DTSPEC),
        "toolchain": dict(PIN_TOOLCHAIN),
        "kernel_config": {"defconfig": PIN_DEFCONFIG, "fragment": dict(PIN_FRAGMENT)},
        "dt": dt,
        "rootfs": {"kind": "initrd", "path": rootfs,
                   "sha256": sha256_file(rootfs), "overlay": overlay},
        "repo": {"branch": branch, "commit": commit},
        "created_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="P3-M08 manifest write+validate")
    parser.add_argument("--validate", metavar="MANIFEST",
                        help="validate an existing manifest file")
    parser.add_argument("--check-files", action="store_true",
                        help="with --validate, also bind declared hashes to files on disk")
    parser.add_argument("--write", action="store_true",
                        help="write a new manifest with SHA256-bound artifacts")
    parser.add_argument("--kernel", default="", help="kernel zImage path (for --write)")
    parser.add_argument("--rootfs", default="", help="rootfs.cpio.gz path (for --write)")
    parser.add_argument("--overlay", default="overlay", help="overlay tree (for --write)")
    parser.add_argument("--dtb", default="", help="explicit DTB path (for --write)")
    parser.add_argument("--qemu-generated-dt", action="store_true",
                        help="DT dual-mode: use QEMU-generated DT (no -dtb)")
    parser.add_argument("--out", default="", help="output manifest path (for --write)")
    parser.add_argument("--branch", default="phase-3/m07-m08-arch-appliance")
    parser.add_argument("--commit", default="67343a1")
    args = parser.parse_args(argv)

    if args.validate:
        path = args.validate
        if not os.path.isfile(path):
            print(f"ERROR: manifest not found: {path}", file=sys.stderr)
            return EXIT_ERROR
        try:
            with open(path, "r", encoding="utf-8") as handle:
                data = json.load(handle)
        except (OSError, json.JSONDecodeError) as exc:
            print(f"ERROR: cannot read manifest {path}: {exc}", file=sys.stderr)
            return EXIT_ERROR
        rejects = validate_manifest(data)
        if rejects:
            print(f"REJECT: manifest {path} is not canonical:", file=sys.stderr)
            for r in rejects:
                print(f"  - {r}", file=sys.stderr)
            return EXIT_REJECT
        if args.check_files:
            base = os.path.dirname(os.path.abspath(path))
            hash_rejects, file_errors = check_bound_files(data, base)
            if file_errors:
                for e in file_errors:
                    print(f"ERROR: {e}", file=sys.stderr)
                return EXIT_ERROR
            if hash_rejects:
                for r in hash_rejects:
                    print(f"REJECT: {r}", file=sys.stderr)
                return EXIT_REJECT
        print(f"[PASS] manifest {path} validates (m08-manifest-v1, pins + hashes present)")
        return EXIT_PASS

    if args.write:
        if not args.out:
            print("ERROR: --write requires --out MANIFEST", file=sys.stderr)
            return EXIT_ERROR
        if not args.qemu_generated_dt and not args.dtb:
            print("ERROR: DT dual-mode requires --qemu-generated-dt or --dtb PATH",
                  file=sys.stderr)
            return EXIT_ERROR
        data = build_manifest(args.kernel, args.rootfs, args.overlay,
                              args.dtb or None, args.qemu_generated_dt,
                              args.branch, args.commit)
        rejects = validate_manifest(data)
        if rejects:  # pragma: no cover - internal guard
            print("REJECT: freshly built manifest failed self-validation:", file=sys.stderr)
            for r in rejects:
                print(f"  - {r}", file=sys.stderr)
            return EXIT_REJECT
        with open(args.out, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(data, handle, indent=2)
            handle.write("\n")
        print(f"[PASS] manifest written to {args.out} (hashes bound)")
        return EXIT_PASS

    parser.print_help(sys.stderr)
    return EXIT_ERROR


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
