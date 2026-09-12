# Lab 6.3 — Kernel / Rootfs / Image Integration and Boot

**Time:** ~50 min. **Prerequisite:** Labs 6.1–6.2, P3-M02/M04.

---

## 1. What the pipeline produces

```text
Buildroot .config
   │
   ├── toolchain   (glibc + gcc for arm-none-linux-gnueabihf / arm-linux-gnueabihf)
   ├── packages    (BusyBox, appliance-diag, ...)  → output/build/… → output/target/
   ├── kernel      (Linux 6.18.50, zImage)
   └── images      (rootfs.ext4, rootfs.cpio.gz, zImage)  → output/images/
```

```bash
bash scripts/build_appliance.sh /path/to/buildroot-2026.05.2 build/br-output
```

The wrapper verifies the Buildroot release identity before it builds anything,
then records `BUILD_PROVENANCE.txt`: the release, the external tree, the
defconfig, the `.config` hash and the SHA-256 of every file in `output/images/`.

---

## 2. The launch contract must be explicit

The canonical hardware model does not change because the image was produced
differently:

```text
-machine virt,highmem=off,gic-version=2   -cpu cortex-a7   -m 512M   -smp 1   -nographic
```

Two launch paths are permitted by the Phase 3 design:

| Path | Root filesystem | Kernel command line |
|---|---|---|
| initramfs | `-initrd output/images/rootfs.cpio.gz` | `console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init` |
| block root | `-drive file=output/images/rootfs.ext4,format=raw,id=hd0 -device virtio-blk-device,drive=hd0` | `console=ttyAMA0,115200 earlycon=pl011,0x09000000 root=/dev/vda rw` |

```bash
bash scripts/run_buildroot_appliance.sh build/br-output \
    build/appliance.log build/appliance.provenance
```

The script picks the kernel image, the optional DTB and the rootfs image,
records the exact argv and the hashes of every input, and only then boots.

> **Why `rootfs.cpio.gz` and not `rootfs.cpio`?** Because the module's final-image
> verification walks the image and compares bytes. `BR2_TARGET_ROOTFS_CPIO_GZIP`
> is what makes the artifact compressed *and* independently checkable in pure
> Python; without it Buildroot emits an uncompressed archive under a different
> name, and the documented launch contract above no longer matches. That
> distinction is one of the Gate's seeded defects.

---

## 3. Bind the capture to the image

A console log on its own is worth very little. Bind it:

```bash
python3 scripts/verify_appliance_runtime.py \
    build/br-output/images/rootfs.cpio.gz \
    build/appliance.provenance build/appliance.log \
    --overlay fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay
```

The binder requires, together:

* the canonical machine contract in the executed argv;
* the logged kernel command line matching the provenance bootargs;
* the overlay's boot marker in the log — the overlay **ran**, it was not merely
  packaged;
* the diagnostic utility's `APPLIANCE-DIAG-BEGIN` / `APPLIANCE-DIAG-END` pair,
  with `APPLIANCE-RELEASE=` equal to the overlay marker file;
* the image hash in the provenance equal to the audited image's hash;
* every overlay file actually present inside the audited image.

The last two are what make the capture evidence about *this* image.

---

## 4. Expected runtime output

```text
EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED
```

```text
[    0.000000] Booting Linux on physical CPU 0x0
[    0.000000] Machine model: linux,dummy-virt
[    0.000000] Kernel command line: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init
[    0.0xxxxx] amba-pl011 9000000.pl011: ttyAMA0 at MMIO 0x09000000 (irq = 1, base_baud = 0) is a PL011 rev2
[    0.0xxxxx] Run /init as init process
APPLIANCE-OVERLAY-BOOT-MARKER
APPLIANCE-DIAG-BEGIN
BUILD-ID=unset
KERNEL-RELEASE=6.18.50
APPLIANCE-RELEASE=EMBED-SYSTEM P3-M06 appliance release 1.0
DT-MODEL=linux,dummy-virt
APPLIANCE-DIAG-END
```

These lines describe what the mechanism predicts. They were **not** captured on
the authoring host, which has no Buildroot build available. Replace them with
your own capture before using them as evidence.

---

## 5. Checkpoint

1. You can name which build stage produced each artifact in `output/images/`.
2. You can state the two permitted launch paths and which command-line tokens
   each requires.
3. The runtime binder passes on your capture, or you can explain precisely which
   binding check fails and why.

**Non-proof.** A successful build is not a boot. A boot is not a verified
appliance: it becomes one only when the capture is bound to the image and the
overlay is proved present *and* executed.
