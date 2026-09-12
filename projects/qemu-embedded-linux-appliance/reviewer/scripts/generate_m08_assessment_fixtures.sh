#!/usr/bin/env bash
# P3-M08 REVIEWER-ONLY assessment fixture generator (deterministic).
#
# Materialises the opaque provenance/run-record candidate bundles the semantic
# oracle grades, plus the hidden seed mapping. Byte-stable by construction:
#   * fixed artifact bytes (kernel / dtb / rootfs contents),
#   * fixed created_utc + repo.commit (no wall-clock),
#   * sorted JSON keys + fixed indent,
#   * gzip.compress(mtime=0) so the cpio.gz header carries no timestamp.
# Re-running this script must reproduce byte-identical output; the caller
# (run_m08_reviewer_check.sh) hashes the tree, re-runs, and requires equality.
#
# Outputs (all gitignored under build/ except the seed, which is reviewer-only):
#   build/reviewer-m08-oracle/repaired/           canonical ACCEPT candidate (qemu-generated DT)
#   build/reviewer-m08-oracle/repaired-explicit/  canonical ACCEPT candidate (explicit DTB)
#   build/reviewer-m08-oracle/seeded/             opaque DEFECTIVE candidate (REJECT)
#   reviewer/reference/m08_seed.json              hidden seed mapping (committed, reviewer-only)
#
# Never called from a learner workflow. Never fabricates real QEMU/boot evidence:
# every candidate here is a labelled synthetic authoring fixture.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJ_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
cd "$PROJ_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python
if ! command -v "$PY" >/dev/null 2>&1; then
    echo "FATAL: no python interpreter found (missing tool: tried python3/python)" >&2
    exit 2
fi

OUT_BASE="build/reviewer-m08-oracle"
OVERLAY="overlay"
SEED_OUT="reviewer/reference/m08_seed.json"

echo "=== P3-M08 assessment fixture generation (deterministic, REVIEWER-ONLY) ==="

"$PY" - "$OUT_BASE" "$OVERLAY" "$SEED_OUT" <<'PY'
import gzip
import hashlib
import json
import os
import shlex
import sys

out_base, overlay, seed_out = sys.argv[1], sys.argv[2], sys.argv[3]
# The overlay path is embedded in the manifest and resolved by
# scripts/manifest.py --check-files against the manifest's directory, which
# depends on where the candidate happens to live. Use an absolute path so the
# oracle can grade a candidate at any depth without churning the fixture.
overlay_abs = os.path.abspath(overlay)

# --- fixed, byte-stable identities ------------------------------------------
KERNEL = b"M08-oracle-fake-zImage-6.18.50\n"
DTB = b"M08-oracle-fake-dtb-virt\n"
CREATED_UTC = "2026-09-12T00:00:00Z"
REPO_COMMIT = "test-oracle-bundle"
REPO_BRANCH = "phase-3/m07-m08-arch-appliance"

FROZEN_BOOTARGS = ("console=ttyAMA0,115200 earlycon=pl011,0x09000000 "
                   "rdinit=/sbin/init panic=1")
SEEDED_BOOTARGS = ("console=ttyAMA0,115200 earlycon=pl011,0x09000000 "
                   "rdinit=/sbin/badinit-hidden-transfer panic=1")

def sha(data):
    return hashlib.sha256(data).hexdigest()

# --- newc cpio.gz packer (correct field layout; gzip mtime=0 => byte-stable) ---
def newc_header(namesize, filesize, mode, ino, nlink=1, mtime=0):
    # 13 x 8-hex fields: c_ino, c_mode, c_uid, c_gid, c_nlink, c_mtime,
    # c_filesize, c_devmajor, c_devminor, c_rdevmajor, c_rdevminor,
    # c_namesize, c_check.  c_rdevminor (index 10) must stay 0.
    fields = (ino, mode, 0, 0, nlink, mtime, filesize, 0, 0, 0, 0, namesize, 0)
    return ("070701" + "%08x" * 13 % fields).encode("ascii")

def newc_entry(name, body, ino):
    n = name.encode("utf-8") + b"\x00"
    chunk = newc_header(len(n), len(body), 0o100644, ino) + n
    chunk += b"\x00" * (-len(chunk) % 4)
    chunk += body + b"\x00" * (-len(body) % 4)
    return chunk

def newc_trailer():
    n = b"TRAILER!!!\x00"
    chunk = newc_header(len(n), 0, 0, 0) + n
    chunk += b"\x00" * (-len(chunk) % 4)
    return chunk

def pack_image(overlay_dir):
    files = {}
    for dirpath, dirnames, filenames in os.walk(overlay_dir):
        dirnames[:] = [d for d in dirnames if d not in (".git", ".svn", ".hg")]
        for name in filenames:
            if name.endswith("~") or name == ".empty":
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, overlay_dir).replace(os.sep, "/")
            with open(full, "rb") as handle:
                files[rel] = handle.read()
    files.setdefault("usr/bin/appliance-diag", b"ELF-placeholder\n")
    files.setdefault("etc/init.d/rcS",
                     b"#!/bin/sh\nmount -t proc none /proc\nmount -t sysfs none /sys\n")
    blob = b""
    ino = 1
    for rel in sorted(files):
        blob += newc_entry(rel, files[rel], ino)
        ino += 1
    blob += newc_trailer()
    return gzip.compress(blob, mtime=0)

with open(os.path.join(overlay, "etc", "appliance-release"), "rb") as handle:
    release = handle.read().decode("utf-8").strip()

# --- manifest / run record builders -----------------------------------------
def build_manifest(kernel_sha, rootfs_sha, dt_node, overlay_rel=None):
    if overlay_rel is None:
        overlay_rel = overlay_abs
    return {
        "schema": "m08-manifest-v1",
        "linux": {
            "version": "6.18.50", "tag": "v6.18.50",
            "commit": "7cfc41f8e80f11ffa8382ed1a505154ceffb79c7",
            "source": "git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git",
            "image": {"path": "zImage", "sha256": kernel_sha},
        },
        "qemu_canonical": {
            "version": "11.1.1", "tag": "v11.1.1",
            "commit": "c3d48b7d1e89604920e5b81b91140c2ad39a1943",
            "machine": "virt,highmem=off,gic-version=2", "cpu": "cortex-a7",
            "mem": "512M", "smp": 1,
        },
        "busybox": {"version": "1.36.1",
                    "commit": "1a64f6a20aaf6ea4dbba68bbfa8cc1ab7e5c57c4"},
        "buildroot": {"version": "2026.05.2", "tag": "2026.05.2",
                      "commit": "72d9d4fa636a371ef9eb99c92a735ce9f6d829d5"},
        "dtc": {"version": "v1.7.0",
                "commit": "039a99414e778332d8f9c04cbd3072e1dcc62798"},
        "dtspec": {"version": "v0.4",
                   "commit": "112f53cc57e5931f1503dfcaa1644caf15362c30"},
        "toolchain": {
            "name": "Arm GNU Toolchain 13.3.rel1",
            "triple": "arm-none-linux-gnueabihf",
            "package": "arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-linux-gnueabihf.tar.xz",
            "sha256": "560267bdecf966b7a48467d0af6c81a85b906ef7b0a9b9dd91f506184b940281",
        },
        "kernel_config": {
            "defconfig": "multi_v7_defconfig",
            "fragment": {
                "CONFIG_ARCH_VIRT": "y", "CONFIG_ARM_LPAE": "n",
                "CONFIG_VMSPLIT_3G": "y", "CONFIG_SERIAL_AMBA_PL011": "y",
                "CONFIG_DEVTMPFS": "y", "CONFIG_DEVTMPFS_MOUNT": "y",
                "CONFIG_VIRTIO_MMIO": "y", "CONFIG_VIRTIO_BLK": "y",
                "CONFIG_EXT4_FS": "y",
            },
        },
        "dt": dt_node,
        "rootfs": {"kind": "initrd", "path": "rootfs.cpio.gz",
                   "sha256": rootfs_sha, "overlay": overlay_rel},
        "repo": {"branch": REPO_BRANCH, "commit": REPO_COMMIT},
        "created_utc": CREATED_UTC,
    }

def fingerprint(argv):
    return hashlib.sha256(
        "\n".join(shlex.quote(a) for a in argv).encode("utf-8")).hexdigest()

def build_run(machine, cpu, mem, smp, kernel_sha, rootfs_sha, dt_node, bootargs,
              qemu_exit_code=0, timed_out=False):
    argv = ["qemu-system-arm", "-machine", machine, "-cpu", cpu, "-m", mem,
            "-smp", str(smp), "-nographic", "-kernel", "zImage"]
    if dt_node.get("source") == "explicit":
        argv += ["-dtb", "qemu-virt.dtb"]
    argv += ["-initrd", "rootfs.cpio.gz", "-append", bootargs]
    return {
        "schema": "m08-run-v1",
        "argv": argv,
        "argv_fingerprint": fingerprint(argv),
        "qemu": {
            "machine": machine, "cpu": cpu, "mem": mem, "smp": smp,
            "version_actual": "QEMU emulator version 11.1.0",
            "version_canonical": "11.1.1", "canonical_claim": False,
        },
        "kernel": {"path": "zImage", "sha256": kernel_sha},
        "dt": dt_node,
        "rootfs": {"path": "rootfs.cpio.gz", "sha256": rootfs_sha},
        "bootargs": bootargs,
        "timeout_sec": 120,
        "qemu_exit_code": qemu_exit_code,
        "timed_out": timed_out,
        "console_log": "console.log",
        "repo": {"branch": REPO_BRANCH, "commit": REPO_COMMIT},
    }

def build_log(bootargs, dt_model):
    lines = []
    lines.append("[    0.000000] Booting Linux on physical CPU 0x0")
    lines.append("[    0.000000] Linux version 6.18.50 (oracle-fixture) #1 SMP PREEMPT")
    lines.append("[    0.000000] bootconsole [pl11] enabled")
    lines.append("[    0.000000] Kernel command line: " + bootargs)
    lines.append("[    0.000000] Memory: 400000K/524288K available")
    lines.append("[    0.000100] printk: console [ttyAMA0] enabled")
    lines.append("[    0.000200] bootconsole [pl11] disabled")
    lines.append("[    0.100000] Trying to unpack rootfs image as initramfs...")
    lines.append("[    0.200000] Freeing unused kernel image (initmem) memory: 1024K")
    lines.append("[    0.300000] Run /sbin/init as init process")
    lines.append("[    0.310000] SMP: Total of 1 processors activated (oracle).")
    for i in range(30):
        lines.append("[    0.31%04d] virtio-mmio probe %d: registered" % (i, i))
    lines.append("APPLIANCE-OVERLAY-BOOT-MARKER")
    lines.append("APPLIANCE-DIAG-BEGIN")
    lines.append("SOURCE-REV=1.0")
    lines.append("KERNEL-RELEASE=6.18.50")
    lines.append("APPLIANCE-RELEASE=" + release)
    lines.append("DT-MODEL=" + dt_model)
    lines.append("UPTIME-SEC=42")
    lines.append("MEM-AVAILABLE-KB=412000")
    lines.append("APPLIANCE-DIAG-END")
    for i in range(12):
        lines.append("[    0.9%04d] random: crng init done (filler %d)" % (i, i))
    return "\n".join(lines) + "\n"

def write_json(path, obj):
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(obj, handle, indent=2, sort_keys=True)
        handle.write("\n")

def write_candidate(directory, manifest_obj, run_obj, log_text, dtb=None):
    os.makedirs(directory, exist_ok=True)
    with open(os.path.join(directory, "zImage"), "wb") as handle:
        handle.write(KERNEL)
    with open(os.path.join(directory, "rootfs.cpio.gz"), "wb") as handle:
        handle.write(pack_image(overlay))
    if dtb is not None:
        with open(os.path.join(directory, "qemu-virt.dtb"), "wb") as handle:
            handle.write(dtb)
    write_json(os.path.join(directory, "appliance.manifest.json"), manifest_obj)
    write_json(os.path.join(directory, "appliance.run.json"), run_obj)
    with open(os.path.join(directory, "console.log"), "w", encoding="utf-8", newline="\n") as handle:
        handle.write(log_text)

kernel_sha = sha(KERNEL)
rootfs_bytes = pack_image(overlay)
rootfs_sha = sha(rootfs_bytes)
dtb_sha = sha(DTB)

MACHINE = "virt,highmem=off,gic-version=2"
CPU = "cortex-a7"
MEM = "512M"
SMP = 1

# 1. canonical repaired candidate (qemu-generated DT) -> ACCEPT
dt_gen = {"source": "qemu-generated"}
write_candidate(
    os.path.join(out_base, "repaired"),
    build_manifest(kernel_sha, rootfs_sha, dt_gen),
    build_run(MACHINE, CPU, MEM, SMP, kernel_sha, rootfs_sha, dt_gen, FROZEN_BOOTARGS),
    build_log(FROZEN_BOOTARGS, "QEMU virt"),
)

# 2. canonical repaired candidate (explicit DTB) -> ACCEPT (used for stale-DTB tests)
dt_exp = {"source": "explicit", "path": "qemu-virt.dtb", "sha256": dtb_sha}
write_candidate(
    os.path.join(out_base, "repaired-explicit"),
    build_manifest(kernel_sha, rootfs_sha, dt_exp),
    build_run(MACHINE, CPU, MEM, SMP, kernel_sha, rootfs_sha, dt_exp, FROZEN_BOOTARGS),
    build_log(FROZEN_BOOTARGS, "QEMU virt"),
    dtb=DTB,
)

# 3. opaque seeded (defective) candidate -> REJECT
write_candidate(
    os.path.join(out_base, "seeded"),
    build_manifest(kernel_sha, rootfs_sha, dt_gen),
    build_run(MACHINE, CPU, MEM, SMP, kernel_sha, rootfs_sha, dt_gen, SEEDED_BOOTARGS),
    build_log(SEEDED_BOOTARGS, "TRANSFER-HIDDEN-UNAVAILABLE"),
)

# 4. hidden seed mapping (committed, reviewer-only).
seed = {
    "schema": "m08-seed-v1",
    "assessment": "gate",
    "note": "REVIEWER-ONLY hidden seed mapping. Never import from learner paths; the isolation audit scans for the hidden signatures below.",
    "fault_family": "transfer: hidden bootarg decoy + hidden DT-MODEL marker (unfamiliar from tutorial fault-a/b)",
    "variant": "well-formed provenance/run record whose bootargs rdinit token and captured DT-MODEL carry hidden-transfer decoy values; different from tutorial fault-a (rdinit=/init) and fault-b (DT-MODEL=UNAVAILABLE)",
    "seeded_edits": [
        {"op": "replace-token", "field": "bootargs", "from": "rdinit=/sbin/init",
         "to": "rdinit=/sbin/badinit-hidden-transfer",
         "note": "hidden bootarg decoy breaks the exact 4-token bootargs set in both run record and guest cmdline"},
        {"op": "replace-marker", "field": "log.DT-MODEL", "from": "QEMU virt",
         "to": "TRANSFER-HIDDEN-UNAVAILABLE",
         "note": "hidden sysfs variant: a sentinel the runtime binder passes but only the oracle rejects"},
    ],
    "expected_repair": "restore the exact 4-token bootargs set (rdinit=/sbin/init) in run + guest cmdline, and a non-hidden DT-MODEL",
    "taught_profile_detects": False,
    "taught_profile_note": "the runtime binder rejects the bootarg decoy but treats TRANSFER-HIDDEN-UNAVAILABLE as a non-empty DT-MODEL; only this oracle knows the hidden sentinel",
    "oracle_invariants": ["bootargs.exact-set", "log.cmdline-exact-set", "guest.dt-model"],
    "hidden_signatures": ["badinit-hidden-transfer", "TRANSFER-HIDDEN-UNAVAILABLE"],
}
os.makedirs(os.path.dirname(seed_out), exist_ok=True)
write_json(seed_out, seed)

print("[OK] repaired candidate       : %s/repaired" % out_base)
print("[OK] repaired-explicit candidate: %s/repaired-explicit" % out_base)
print("[OK] seeded (defective) candidate: %s/seeded" % out_base)
print("[OK] hidden seed mapping      : %s" % seed_out)
PY

echo "=== Assessment fixtures materialised ==="
