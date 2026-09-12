#!/usr/bin/env bash
# Adversarial transfer-mutation suite for the P3-M08 binder + audit (REVIEWER-ONLY).
#
# Builds one synthetic-but-complete valid bundle (manifest + run + log + image
# materialised from overlay/), proves the binder reports VERIFIED-consistency,
# then applies each negative mutation and asserts the INTENDED outcome class:
#   0 VERIFIED / 1 REJECT (semantic) / 2 ERROR (missing dependency).
# A crash or unrelated environment failure never counts as an intended REJECT.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJ_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$PROJ_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

OVERLAY="overlay"
WORK="build/reviewer-m08-mutations"
rm -rf "$WORK"
mkdir -p "$WORK/bundle" "$WORK/mut"

TOTAL=0
PASSED=0

B="$WORK/bundle"
KERNEL="$B/zImage"
ROOTFS="$B/rootfs.cpio.gz"
MANIFEST="$B/appliance.manifest.json"
RUN="$B/appliance.run.json"
LOG="$B/appliance.log"
B_ABS="$PROJ_ROOT/$WORK/bundle"
KERNEL_ABS="$B_ABS/zImage"
ROOTFS_ABS="$B_ABS/rootfs.cpio.gz"
DTB_ABS="$B_ABS/qemu-virt.dtb"

echo "=== materialising synthetic valid bundle (NOT real boot evidence) ==="

# --- fake kernel + dtb bytes --------------------------------------------------
printf 'M08-fake-zImage-6.18.50\n' > "$KERNEL"
printf 'M08-fake-dtb-virt\n' > "$B/qemu-virt.dtb"

# --- pack overlay + guest extras into a newc cpio.gz ---------------------------
"$PY" - "$OVERLAY" "$ROOTFS" <<'PY'
import gzip, os, sys
overlay, out = sys.argv[1], sys.argv[2]
files = {}
for dirpath, dirnames, filenames in os.walk(overlay):
    dirnames[:] = [d for d in dirnames if d not in (".git",)]
    for name in filenames:
        full = os.path.join(dirpath, name)
        rel = os.path.relpath(full, overlay).replace(os.sep, "/")
        with open(full, "rb") as fh:
            files[rel] = fh.read()
files["usr/bin/appliance-diag"] = b"ELF-placeholder\n"
files["sbin/init"] = b"#!/bin/sh\nmount -t proc none /proc\nmount -t sysfs none /sys\nexec /sbin/init\n"
files["etc/init.d/rcS"] = b"#!/bin/sh\nmount -t proc none /proc\nmount -t sysfs none /sys\n"
def entry(name, body):
    n = name.encode() + b"\x00"
    header = "070701%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x" % (
        1, 0o100644, 0, 0, 1, 0, len(body), 0, 0, 0, 0, len(n), 0)
    chunk = header.encode() + n
    chunk += b"\x00" * ((-len(chunk)) % 4)
    chunk += body
    chunk += b"\x00" * ((-len(body)) % 4)
    return chunk
blob = b"".join(entry(k, v) for k, v in sorted(files.items()))
blob += ("070701%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x" % (
    0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, len(b"TRAILER!!!\x00"), 0)).encode()
blob += b"TRAILER!!!\x00"
blob += b"\x00" * ((-len(b"TRAILER!!!\x00") - 110) % 4)
# Self-check the newc field order before writing: c_rdevminor (field index 10)
# must be 0 and c_namesize (index 11) must be len(name)+1, otherwise the reader
# misaligns and dies with "unexpected cpio magic" (BUG #1).
first = blob[:110]
f = [int(first[6 + i * 8:14 + i * 8], 16) for i in range(13)]
assert f[10] == 0, "newc c_rdevminor must be 0 (namesize misplaced)"
assert f[11] == len(sorted(files)[0].encode()) + 1, "newc c_namesize must be len(name)+1"
with gzip.open(out, "wb") as fh:
    fh.write(blob)
print(f"packed {len(files)} file(s)")
PY

# --- manifest (qemu-generated DT) + explicit-DTB twin --------------------------
"$PY" scripts/manifest.py --write --kernel "$KERNEL_ABS" --rootfs "$ROOTFS_ABS" \
    --overlay "$PROJ_ROOT/$OVERLAY" --qemu-generated-dt --out "$MANIFEST" --commit test-bundle
"$PY" scripts/manifest.py --validate "$MANIFEST" --check-files

# --- run record + valid 60+ line log -------------------------------------------
RELEASE=$(cat overlay/etc/appliance-release)
"$PY" - "$MANIFEST" "$RUN" "$LOG" "$RELEASE" <<'PY'
import hashlib, json, shlex, sys
manifest_path, run_path, log_path, release = sys.argv[1:5]
m = json.load(open(manifest_path, encoding="utf-8"))
kernel = m["linux"]["image"]
rootfs = m["rootfs"]
machine, cpu, mem, smp = (m["qemu_canonical"][k] for k in ("machine", "cpu", "mem", "smp"))
bootargs = "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/sbin/init panic=1"
argv = ["qemu-system-arm", "-machine", machine, "-cpu", cpu, "-m", mem,
        "-smp", str(smp), "-nographic", "-kernel", kernel["path"],
        "-initrd", rootfs["path"], "-append", bootargs]
run = {
    "schema": "m08-run-v1", "argv": argv,
    "argv_fingerprint": hashlib.sha256("\n".join(shlex.quote(a) for a in argv).encode()).hexdigest(),
    "qemu": {"machine": machine, "cpu": cpu, "mem": mem, "smp": smp,
              "version_actual": "QEMU emulator version 11.1.0",
              "version_canonical": "11.1.1", "canonical_claim": False},
    "kernel": {"path": kernel["path"], "sha256": kernel["sha256"]},
    "dt": {"source": "qemu-generated"},
    "rootfs": {"path": rootfs["path"], "sha256": rootfs["sha256"]},
    "bootargs": bootargs, "timeout_sec": 120,
    "qemu_exit_code": 0, "timed_out": False, "console_log": log_path,
    "repo": {"branch": "phase-3/m07-m08-arch-appliance"},
}
json.dump(run, open(run_path, "w", encoding="utf-8"), indent=2)
open(run_path, "a").write("\n")
lines = []
lines.append("[    0.000000] Booting Linux on physical CPU 0x0")
lines.append("[    0.000000] Linux version 6.18.50 (test-bundle) #1 SMP PREEMPT")
lines.append("[    0.000000] bootconsole [pl11] enabled")
lines.append("[    0.000000] Kernel command line: " + bootargs)
lines.append("[    0.000000] Memory: 400000K/524288K available")
lines.append("[    0.000100] printk: console [ttyAMA0] enabled")
lines.append("[    0.000200] bootconsole [pl11] disabled")
lines.append("[    0.100000] Trying to unpack rootfs image as initramfs...")
lines.append("[    0.200000] Freeing unused kernel image (initmem) memory: 1024K")
lines.append("[    0.300000] Run /sbin/init as init process")
lines.append("[    0.310000] SMP: Total of 1 processors activated (lamp).")
for i in range(30):
    lines.append(f"[    0.31{i:04d}] virtio-mmio probe {i}: registered")
lines.append("APPLIANCE-OVERLAY-BOOT-MARKER")
lines.append("APPLIANCE-DIAG-BEGIN")
lines.append("SOURCE-REV=1.0")
lines.append("KERNEL-RELEASE=6.18.50")
lines.append(f"APPLIANCE-RELEASE={release}")
lines.append("DT-MODEL=QEMU virt")
lines.append("UPTIME-SEC=42")
lines.append("MEM-AVAILABLE-KB=412000")
lines.append("APPLIANCE-DIAG-END")
for i in range(12):
    lines.append(f"[    0.9{i:04d}] random: crng init done (filler {i})")
open(log_path, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
print(f"valid log: {len(lines)} lines")
PY

cp "$MANIFEST" "$WORK/manifest.explicit-src.json"
"$PY" scripts/manifest.py --write --kernel "$KERNEL_ABS" --rootfs "$ROOTFS_ABS" \
    --overlay "$PROJ_ROOT/$OVERLAY" --dtb "$DTB_ABS" --out "$WORK/manifest.explicit.json" --commit test-explicit

bind() { "$PY" scripts/verify_m08_runtime.py --manifest "$1" --run "$2" --log "$3" --overlay "$OVERLAY"; }

assert_verified() {
    local name="$1"; TOTAL=$((TOTAL + 1)); echo -n "[TEST $TOTAL] VERIFIED expected: $name ... "
    set +e; out=$(bind "$2" "$3" "$4" 2>&1); rc=$?; set -e
    if [ "$rc" -eq 0 ]; then echo "PASS"; PASSED=$((PASSED + 1));
    else echo "FAIL (rc=$rc)"; echo "$out"; exit 1; fi
}
assert_reject() {
    local name="$1"; TOTAL=$((TOTAL + 1)); echo -n "[TEST $TOTAL] REJECT expected: $name ... "
    set +e; out=$(bind "$2" "$3" "$4" 2>&1); rc=$?; set -e
    if [ "$rc" -eq 1 ]; then echo "PASS"; PASSED=$((PASSED + 1));
    else echo "FAIL (rc=$rc, expected 1)"; echo "$out"; exit 1; fi
}
assert_error() {
    local name="$1"; TOTAL=$((TOTAL + 1)); echo -n "[TEST $TOTAL] ERROR expected: $name ... "
    set +e; out=$(bind "$2" "$3" "$4" 2>&1); rc=$?; set -e
    if [ "$rc" -eq 2 ]; then echo "PASS"; PASSED=$((PASSED + 1));
    else echo "FAIL (rc=$rc, expected 2)"; echo "$out"; exit 1; fi
}
mut_json() { "$PY" - "$1" "$2" "$3" <<'PY'
import json, sys
src, dst, expr = sys.argv[1], sys.argv[2], sys.argv[3]
doc = json.load(open(src, encoding="utf-8"))
exec(expr, {"doc": doc})
json.dump(doc, open(dst, "w", encoding="utf-8"), indent=2)
open(dst, "a").write("\n")
PY
}

# --- 1. positive ---------------------------------------------------------------
assert_verified "healthy synthetic bundle" "$MANIFEST" "$RUN" "$LOG"

# --- 2. hash mismatch (kernel bytes differ, filenames correct) ------------------
cp "$KERNEL" "$WORK/mut/zImage"
printf 'CORRUPTED\n' >> "$WORK/mut/zImage"
"$PY" - "$RUN" "$WORK/mut/run.hash.json" "$WORK/mut/zImage" <<'PY'
import hashlib, json, os, shlex, sys
src, dst, new_kernel = sys.argv[1], sys.argv[2], os.path.abspath(sys.argv[3])
doc = json.load(open(src, encoding="utf-8"))
doc["kernel"]["path"] = new_kernel
ki = doc["argv"].index("-kernel")
doc["argv"][ki + 1] = new_kernel
doc["argv_fingerprint"] = hashlib.sha256(
    "\n".join(shlex.quote(a) for a in doc["argv"]).encode()).hexdigest()
json.dump(doc, open(dst, "w", encoding="utf-8"), indent=2)
open(dst, "a").write("\n")
PY
assert_reject "hash mismatch (correct filenames, different bytes)" \
    "$MANIFEST" "$WORK/mut/run.hash.json" "$LOG"

# --- 3. stale DTB (explicit mode, file hash != record) ---------------------------
"$PY" - "$WORK/manifest.explicit.json" "$WORK/mut/run.explicit.json" "$LOG" <<'PY'
import hashlib, json, shlex, sys
m = json.load(open(sys.argv[1], encoding="utf-8"))
bootargs = "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/sbin/init panic=1"
argv = ["qemu-system-arm", "-machine", m["qemu_canonical"]["machine"],
        "-cpu", m["qemu_canonical"]["cpu"], "-m", m["qemu_canonical"]["mem"],
        "-smp", str(m["qemu_canonical"]["smp"]), "-nographic",
        "-kernel", m["linux"]["image"]["path"], "-dtb", m["dt"]["path"],
        "-initrd", m["rootfs"]["path"], "-append", bootargs]
run = {"schema": "m08-run-v1", "argv": argv,
    "argv_fingerprint": hashlib.sha256("\n".join(shlex.quote(a) for a in argv).encode()).hexdigest(),
    "qemu": {"machine": m["qemu_canonical"]["machine"], "cpu": m["qemu_canonical"]["cpu"],
              "mem": m["qemu_canonical"]["mem"], "smp": m["qemu_canonical"]["smp"],
              "version_actual": "QEMU emulator version 11.1.0",
              "version_canonical": "11.1.1", "canonical_claim": False},
    "kernel": m["linux"]["image"], "dt": m["dt"], "rootfs": m["rootfs"],
    "bootargs": bootargs, "timeout_sec": 120, "qemu_exit_code": 0,
    "timed_out": False, "console_log": sys.argv[3],
    "repo": {"branch": "phase-3/m07-m08-arch-appliance"}}
json.dump(run, open(sys.argv[2], "w"), indent=2)
PY
printf 'STALE-DTB\n' >> "$B/qemu-virt.dtb"
assert_reject "stale DTB paired with current kernel/rootfs" \
    "$WORK/manifest.explicit.json" "$WORK/mut/run.explicit.json" "$LOG"
truncate -s -10 "$B/qemu-virt.dtb" 2>/dev/null || "$PY" - "$B/qemu-virt.dtb" <<'PY'
import sys
p = sys.argv[1]
data = open(p, "rb").read()
open(p, "wb").write(data[:-10])
PY

# --- 4. argv skew (-m 256M executed, fingerprint recomputed to hide it) ----------
mut_json "$RUN" "$WORK/mut/run.skew.json" "
doc['argv'][6] = '256M'
doc['qemu']['mem'] = '256M'
import hashlib, shlex
doc['argv_fingerprint'] = hashlib.sha256(chr(10).join(shlex.quote(a) for a in doc['argv']).encode()).hexdigest()
"
assert_reject "argv skew (gic/smp/mem mismatch: -m 256M)" \
    "$MANIFEST" "$WORK/mut/run.skew.json" "$LOG"

# --- 5. handwritten log (short fragment) -----------------------------------------
head -n 10 "$LOG" > "$WORK/mut/short.log" 2>/dev/null || "$PY" - "$LOG" "$WORK/mut/short.log" <<'PY'
import sys
lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
open(sys.argv[2], "w", encoding="utf-8").write("\n".join(lines[:10]) + "\n")
PY
assert_reject "handwritten log (short fragment, missing milestones)" \
    "$MANIFEST" "$RUN" "$WORK/mut/short.log"

# --- 6. missing dependency -> ERROR ----------------------------------------------
mut_json "$RUN" "$WORK/mut/run.missing.json" "doc['kernel']['path'] = '$WORK/does-not-exist-zImage'"
assert_error "missing dependency is ERROR, not REJECT" \
    "$MANIFEST" "$WORK/mut/run.missing.json" "$LOG"

# --- 7. highmem=on ---------------------------------------------------------------
mut_json "$RUN" "$WORK/mut/run.highmem.json" "
doc['argv'][2] = 'virt,highmem=on,gic-version=2'
doc['qemu']['machine'] = 'virt,highmem=on,gic-version=2'
import hashlib, shlex
doc['argv_fingerprint'] = hashlib.sha256(chr(10).join(shlex.quote(a) for a in doc['argv']).encode()).hexdigest()
"
assert_reject "highmem=on rejected (non-LPAE contract)" \
    "$MANIFEST" "$WORK/mut/run.highmem.json" "$LOG"

# --- 8. host-QEMU-masquerading-canonical ------------------------------------------
mut_json "$RUN" "$WORK/mut/run.masq.json" "
doc['qemu']['canonical_claim'] = True
doc['qemu']['version_actual'] = 'QEMU emulator version 11.1.0'
"
assert_reject "host-QEMU-masquerading-canonical" \
    "$MANIFEST" "$WORK/mut/run.masq.json" "$LOG"

# --- 9. decoy overlay (marker string elsewhere, file absent) -----------------------
"$PY" - "$OVERLAY" "$WORK/mut/decoy.cpio.gz" <<'PY'
import gzip, os, sys
overlay, out = sys.argv[1], sys.argv[2]
files = {}
for dirpath, dirnames, filenames in os.walk(overlay):
    dirnames[:] = [d for d in dirnames if d not in (".git",)]
    for name in filenames:
        full = os.path.join(dirpath, name)
        rel = os.path.relpath(full, overlay).replace(os.sep, "/")
        if rel == "etc/appliance-release":
            continue
        with open(full, "rb") as fh:
            files[rel] = fh.read()
with open(os.path.join(overlay, "etc", "appliance-release"), "rb") as fh:
    marker = fh.read().strip()
files["tmp/decoy.txt"] = b"decoy container: " + marker + b"\n"
def entry(name, body):
    n = name.encode() + b"\x00"
    header = "070701%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x" % (
        1, 0o100644, 0, 0, 1, 0, len(body), 0, 0, 0, 0, len(n), 0)
    chunk = header.encode() + n
    chunk += b"\x00" * ((-len(chunk)) % 4)
    chunk += body
    chunk += b"\x00" * ((-len(body)) % 4)
    return chunk
blob = b"".join(entry(k, v) for k, v in sorted(files.items()))
blob += ("070701%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x" % (
    0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, len(b"TRAILER!!!\x00"), 0)).encode()
blob += b"TRAILER!!!\x00"
blob += b"\x00" * ((-len(b"TRAILER!!!\x00") - 110) % 4)
# Self-check the newc field order before writing: c_rdevminor (field index 10)
# must be 0 and c_namesize (index 11) must be len(name)+1, otherwise the reader
# misaligns and dies with "unexpected cpio magic" (BUG #1).
first = blob[:110]
f = [int(first[6 + i * 8:14 + i * 8], 16) for i in range(13)]
assert f[10] == 0, "newc c_rdevminor must be 0 (namesize misplaced)"
assert f[11] == len(sorted(files)[0].encode()) + 1, "newc c_namesize must be len(name)+1"
with gzip.open(out, "wb") as fh:
    fh.write(blob)
PY
mut_json "$MANIFEST" "$WORK/mut/manifest.decoy.json" "pass"
"$PY" - "$WORK/mut/manifest.decoy.json" "$RUN" "$WORK/mut/run.decoy.json" "$WORK/mut/decoy.cpio.gz" <<'PY'
import hashlib, json, os, shlex, sys
m_path, run_src, run_out, image = sys.argv[1], sys.argv[2], sys.argv[3], os.path.abspath(sys.argv[4])
m = json.load(open(m_path, encoding="utf-8"))
run = json.load(open(run_src, encoding="utf-8"))
h = hashlib.sha256(open(image, "rb").read()).hexdigest()
run["rootfs"] = {"path": image, "sha256": h}
ii = run["argv"].index("-initrd")
run["argv"][ii + 1] = image
run["argv_fingerprint"] = hashlib.sha256(
    "\n".join(shlex.quote(a) for a in run["argv"]).encode()).hexdigest()
m["rootfs"] = {"kind": "initrd", "path": image, "sha256": h, "overlay": "overlay"}
json.dump(m, open(m_path, "w"), indent=2)
open(m_path, "a").write("\n")
json.dump(run, open(run_out, "w"), indent=2)
open(run_out, "a").write("\n")
PY
assert_reject "decoy overlay (string elsewhere, file absent)" \
    "$WORK/mut/manifest.decoy.json" "$WORK/mut/run.decoy.json" "$LOG"

# --- 10. synthetic masquerade ------------------------------------------------------
cp "$LOG" "$WORK/mut/synth.log"
printf 'SYNTHETIC fixture line\n' >> "$WORK/mut/synth.log"
assert_reject "synthetic strings in capture" "$MANIFEST" "$RUN" "$WORK/mut/synth.log"

echo "------------------------------------------------------------------"
echo "=== M08 TRANSFER MUTATIONS: $PASSED/$TOTAL intended outcomes hold ==="
