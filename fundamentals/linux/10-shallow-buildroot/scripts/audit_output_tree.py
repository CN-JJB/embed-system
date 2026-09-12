#!/usr/bin/env python3
"""Buildroot output-tree provenance audit and rootfs-overlay propagation check.

This is the tool behind Labs 6.4 and 6.5 and behind the Module Gate's
"build success is not deployable success" requirement.

It answers, from real files on disk:

* what class of artifact each part of ``output/`` contains
  (``build/`` package work area, ``target/`` staging view, ``images/`` final
  deployable artifacts);
* whether every file contributed by the root filesystem overlay actually
  reached **both** ``output/target/`` and the **final image**;
* whether the final image is *stale* -- i.e. ``output/target/`` already carries
  a customization that the packaged image does not.

The last point is the whole reason this tool exists.  ``output/target/`` is a
staging view, not the deliverable: a build that updates the staging tree without
re-packaging the image produces a target tree that *lies* about the artifact you
are about to boot.  Any audit that stops at ``output/target/`` can therefore
report success for an image that does not contain the change.

Supported final-image formats
-----------------------------
* ``rootfs.cpio`` and ``rootfs.cpio.gz`` (newc / crc cpio archives) -- verified
  byte-for-byte against the overlay source;
* ``rootfs.ext2`` / ``rootfs.ext4`` -- structural check only (superblock magic
  and size), because a full ext4 walk is out of scope here.  The module
  therefore uses the cpio image as the *validated* artifact and documents the
  block image as the alternative launch path.

Exit status
-----------
0  PASS   -- audit complete and every required relationship holds
1  REJECT -- audit complete and a required relationship is violated
2  ERROR  -- a required input is missing or unreadable

Usage
-----
    python3 scripts/audit_output_tree.py --output DIR --overlay DIR
    python3 scripts/audit_output_tree.py --output DIR --overlay DIR --json
"""

from __future__ import annotations

import argparse
import gzip
import io
import json
import os
import stat
import struct
import sys
from typing import Dict, Iterator, List, Optional, Tuple

EXIT_PASS = 0
EXIT_REJECT = 1
EXIT_ERROR = 2

CPIO_MAGIC_NEWC = b"070701"
CPIO_MAGIC_CRC = b"070702"
EXT_MAGIC = 0xEF53


# ---------------------------------------------------------------------------
# cpio reader (newc / crc), enough to walk a Buildroot rootfs image
# ---------------------------------------------------------------------------


class CpioError(Exception):
    pass


def _read_cpio_stream(data: bytes) -> Iterator[Tuple[str, int, int, bytes]]:
    """Yield ``(name, mode, mtime, content)`` for each regular file entry."""
    pos = 0
    while True:
        if pos + 110 > len(data):
            raise CpioError("cpio archive ends inside a header")
        magic = data[pos:pos + 6]
        if magic not in (CPIO_MAGIC_NEWC, CPIO_MAGIC_CRC):
            raise CpioError(f"unexpected cpio magic {magic!r} at offset {pos}")
        fields = []
        for index in range(13):
            start = pos + 6 + index * 8
            try:
                fields.append(int(data[start:start + 8], 16))
            except ValueError as exc:
                raise CpioError(f"malformed cpio header field at offset {start}") from exc
        mode = fields[1]
        mtime = fields[5]
        filesize = fields[6]
        namesize = fields[11]
        pos += 110
        if pos + namesize > len(data):
            raise CpioError("cpio name extends past end of archive")
        raw_name = data[pos:pos + namesize]
        name = raw_name.split(b"\x00", 1)[0].decode("utf-8", errors="replace")
        pos += namesize
        pos = (pos + 3) & ~3
        if pos + filesize > len(data):
            raise CpioError(f"cpio entry {name!r} extends past end of archive")
        content = data[pos:pos + filesize]
        pos += filesize
        pos = (pos + 3) & ~3
        if name == "TRAILER!!!":
            return
        if stat.S_ISREG(mode):
            yield name.lstrip("./"), mode, mtime, content


def read_cpio(path: str) -> Dict[str, Tuple[int, int, bytes]]:
    with open(path, "rb") as handle:
        raw = handle.read()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    out: Dict[str, Tuple[int, int, bytes]] = {}
    for name, mode, mtime, content in _read_cpio_stream(raw):
        out[name] = (mode, mtime, content)
    return out


def ext_superblock_info(path: str) -> Dict[str, object]:
    """Minimal structural probe of an ext2/3/4 image."""
    with open(path, "rb") as handle:
        handle.seek(1024)
        sb = handle.read(264)
    if len(sb) < 264:
        raise CpioError("ext image is too small to contain a superblock")
    magic = struct.unpack_from("<H", sb, 56)[0]
    if magic != EXT_MAGIC:
        raise CpioError(f"bad ext superblock magic 0x{magic:04x}")
    blocks_count = struct.unpack_from("<I", sb, 4)[0]
    log_block_size = struct.unpack_from("<I", sb, 24)[0]
    return {
        "blocks_count": blocks_count,
        "block_size": 1024 << log_block_size,
        "inodes_count": struct.unpack_from("<I", sb, 0)[0],
    }


# ---------------------------------------------------------------------------
# overlay / image comparison
# ---------------------------------------------------------------------------


def walk_overlay(root: str) -> Dict[str, bytes]:
    out: Dict[str, bytes] = {}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in (".git", ".svn", ".hg")]
        for name in filenames:
            if name.endswith("~") or name == ".empty":
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            with open(full, "rb") as handle:
                out[rel] = handle.read()
    return out


def find_images(images_dir: str) -> Dict[str, List[str]]:
    found: Dict[str, List[str]] = {"cpio": [], "ext": [], "kernel": [], "dtb": [], "other": []}
    if not os.path.isdir(images_dir):
        return found
    for name in sorted(os.listdir(images_dir)):
        full = os.path.join(images_dir, name)
        if not os.path.isfile(full):
            continue
        if name.startswith("rootfs") and (name.endswith(".cpio") or name.endswith(".cpio.gz")):
            found["cpio"].append(full)
        elif name.startswith("rootfs") and (name.endswith(".ext2") or name.endswith(".ext4")):
            found["ext"].append(full)
        elif name.endswith(".dtb"):
            found["dtb"].append(full)
        elif name.startswith("zImage") or name.endswith("Image") or name == "vmlinux":
            found["kernel"].append(full)
        else:
            found["other"].append(full)
    return found


def classify_output(output_dir: str, require_kernel: bool = True
                    ) -> List[Tuple[str, bool, str]]:
    results: List[Tuple[str, bool, str]] = []
    build_dir = os.path.join(output_dir, "build")
    target_dir = os.path.join(output_dir, "target")
    images_dir = os.path.join(output_dir, "images")

    for ident, path in (("output.build", build_dir),
                        ("output.target", target_dir),
                        ("output.images", images_dir)):
        results.append((ident, os.path.isdir(path),
                        f"{path} {'present' if os.path.isdir(path) else 'MISSING'}"))

    if os.path.isdir(build_dir):
        packages = [d for d in sorted(os.listdir(build_dir))
                    if os.path.isdir(os.path.join(build_dir, d))
                    and d not in ("buildroot-config", "host", "toolchain")]
        stamped = 0
        for pkg in packages:
            pkg_dir = os.path.join(build_dir, pkg)
            if any(f.startswith(".stamp_") for f in os.listdir(pkg_dir)):
                stamped += 1
        results.append(("output.build.packages", bool(packages),
                        f"{len(packages)} package build director(ies), "
                        f"{stamped} carrying .stamp_* state files"))

    if os.path.isdir(images_dir):
        images = find_images(images_dir)
        results.append(("output.images.rootfs", bool(images["cpio"] or images["ext"]),
                        f"rootfs image(s): cpio={[os.path.basename(p) for p in images['cpio']]} "
                        f"ext={[os.path.basename(p) for p in images['ext']]}"))
        kernel_names = [os.path.basename(p) for p in images["kernel"]]
        if require_kernel:
            results.append(("output.images.kernel", bool(images["kernel"]),
                            f"kernel image(s): {kernel_names}"))
        else:
            results.append(("output.images.kernel", True,
                            f"kernel image(s): {kernel_names} "
                            "(not required for this audit invocation)"))
    return results


def check_overlay_propagation(output_dir: str, overlay_dir: str
                              ) -> Tuple[List[Tuple[str, bool, str]], List[str]]:
    results: List[Tuple[str, bool, str]] = []
    errors: List[str] = []

    if not os.path.isdir(overlay_dir):
        return results, [f"overlay directory not found: {overlay_dir}"]

    overlay = walk_overlay(overlay_dir)
    results.append(("overlay.source", bool(overlay),
                    f"{len(overlay)} file(s) in the overlay source tree"))

    target_dir = os.path.join(output_dir, "target")
    if not os.path.isdir(target_dir):
        return results, [f"output/target not found: {target_dir}"]

    # --- staging view -------------------------------------------------------
    missing_target: List[str] = []
    differing_target: List[str] = []
    for rel, content in sorted(overlay.items()):
        full = os.path.join(target_dir, rel)
        if not os.path.isfile(full):
            missing_target.append(rel)
            continue
        with open(full, "rb") as handle:
            if handle.read() != content:
                differing_target.append(rel)
    results.append(("overlay.in-target", not missing_target and not differing_target,
                    f"all {len(overlay)} overlay file(s) present and identical in output/target"
                    if not missing_target and not differing_target else
                    f"missing from output/target: {missing_target[:4]}; "
                    f"content differs: {differing_target[:4]}"))

    # --- final image --------------------------------------------------------
    images_dir = os.path.join(output_dir, "images")
    images = find_images(images_dir)
    if not images["cpio"]:
        results.append(("overlay.in-image", False,
                        "no cpio rootfs image found in output/images; the final image content "
                        "cannot be verified from output/target alone"))
        return results, errors

    image_path = images["cpio"][0]
    try:
        entries = read_cpio(image_path)
    except (CpioError, OSError, EOFError) as exc:
        return results, [f"cannot read the final image {image_path}: {exc}"]

    missing_image: List[str] = []
    differing_image: List[str] = []
    for rel, content in sorted(overlay.items()):
        if rel not in entries:
            missing_image.append(rel)
            continue
        if entries[rel][2] != content:
            differing_image.append(rel)
    results.append(("overlay.in-image",
                    not missing_image and not differing_image,
                    f"all {len(overlay)} overlay file(s) present and byte-identical inside "
                    f"{os.path.basename(image_path)}"
                    if not missing_image and not differing_image else
                    f"absent from the final image: {missing_image[:4]}; "
                    f"content differs in the final image: {differing_image[:4]}"))

    # --- staleness ----------------------------------------------------------
    # A customization present in output/target but absent from the packaged
    # image is the defining symptom of a stale image.
    stale = [rel for rel in overlay
             if os.path.isfile(os.path.join(target_dir, rel)) and rel not in entries]
    results.append(("overlay.not-stale", not stale,
                    "no overlay file is present in output/target but missing from the image"
                    if not stale else
                    f"STALE IMAGE: {stale[:4]} exist in output/target but not in "
                    f"{os.path.basename(image_path)}"))

    # --- decoy detection ----------------------------------------------------
    # A marker string inside the image is not the same as the required file
    # being present with the required semantics.
    decoys: List[str] = []
    for rel, content in sorted(overlay.items()):
        if rel in entries:
            continue
        needle = content.strip()
        if not needle:
            continue
        for name, (_mode, _mtime, body) in entries.items():
            if needle in body:
                decoys.append(f"{rel} (string found inside {name})")
                break
    results.append(("overlay.no-decoy", not decoys,
                    "no overlay file is represented only by a decoy string elsewhere in the image"
                    if not decoys else
                    f"decoy-only representation: {decoys[:4]}"))

    results.append(("image.entries", True,
                    f"{len(entries)} regular file(s) inside {os.path.basename(image_path)}"))
    return results, errors


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="P3-M06 Buildroot output-tree audit")
    parser.add_argument("--output", required=True, help="Buildroot output directory")
    parser.add_argument("--overlay", required=True, help="root filesystem overlay source tree")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--require-kernel", action="store_true",
                        help="fail the audit when output/images carries no kernel image")
    args = parser.parse_args(argv)

    if not os.path.isdir(args.output):
        print(f"ERROR: output directory not found: {args.output}", file=sys.stderr)
        return EXIT_ERROR

    results = classify_output(args.output, require_kernel=args.require_kernel)
    overlay_results, errors = check_overlay_propagation(args.output, args.overlay)
    results.extend(overlay_results)

    # Structural probe of any block image present.
    images = find_images(os.path.join(args.output, "images"))
    for path in images["ext"]:
        try:
            info = ext_superblock_info(path)
            results.append((f"image.ext.structure[{os.path.basename(path)}]", True,
                            f"ext superblock ok: {info}"))
        except (CpioError, OSError) as exc:
            errors.append(f"{path}: {exc}")

    if args.json:
        print(json.dumps({
            "output": args.output,
            "overlay": args.overlay,
            "errors": errors,
            "results": [{"id": i, "ok": o, "detail": d} for i, o, d in results],
            "verdict": "ERROR" if errors else
                       ("PASS" if all(o for _, o, _ in results) else "REJECT"),
        }, indent=2))
        if errors:
            return EXIT_ERROR
        return EXIT_PASS if all(o for _, o, _ in results) else EXIT_REJECT

    if not args.quiet:
        print("=" * 66)
        print("=== P3-M06 Buildroot output-tree audit")
        print(f"=== output : {args.output}")
        print(f"=== overlay: {args.overlay}")
        print("=" * 66)
        for ident, ok, detail in results:
            print(f"[{'PASS' if ok else 'FAIL'}] {ident}" + (f" -- {detail}" if detail else ""))

    if errors:
        for err in errors:
            print(f"ERROR: {err}", file=sys.stderr)
        print("=== OUTPUT-TREE AUDIT: ERROR ===", file=sys.stderr)
        return EXIT_ERROR

    failed = [i for i, ok, _ in results if not ok]
    if failed:
        print(f"=== OUTPUT-TREE AUDIT: REJECT ({len(failed)} relationship(s) violated) ===",
              file=sys.stderr)
        for ident in failed:
            print(f"    - {ident}", file=sys.stderr)
        return EXIT_REJECT

    if not args.quiet:
        print(f"=== OUTPUT-TREE AUDIT: PASS ({len(results)} checks) ===")
    return EXIT_PASS


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
