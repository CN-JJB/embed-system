# Fault F04 — Bad Kernel Command Line: Root / Init Selection Failure

## 1. Symptom

During boot, the kernel initializes hardware drivers, but terminates either in a permanent hang or a VFS panic:

**Variant A (Missing Block Device):**
```text
[    1.250491] Waiting for root device /dev/nonexistent...
(kernel hangs indefinitely)
```

**Variant B (Missing Init Path):**
```text
[    1.092599] Failed to execute /bin/badinit (error -2)
[    1.093120] Kernel panic - not syncing: No working init found.  Try passing init= option to kernel.
```

---

## 2. Full Diagnostic Discipline Walkthrough

### Step 1: Own Description
The kernel boots cleanly through hardware device registration. However, at the storage and userspace transition phase, the kernel cannot access the specified root filesystem or execute the specified init binary because the boot argument specifies an invalid path or non-existent hardware node.

### Step 2: 3–5 Hypotheses
1. The kernel command-line parameter `root=` or `rdinit=` has a typo or points to a non-existent device/path.
2. The storage controller driver (`CONFIG_VIRTIO_BLK` or `CONFIG_MMC`) was not compiled into the kernel.
3. The storage media exists, but the filesystem type driver (e.g. `ext4`) is missing.
4. The root storage controller requires additional settling time (`rootwait` missing).

### Step 3: Discriminating Experiment
Inspect the effective kernel command line passed by QEMU `-append`:
```bash
grep "Kernel command line:" /tmp/boot.log
```
Check what storage devices were registered by the kernel:
```bash
grep -E "virtio|blk|mmc|sd" /tmp/boot.log
```

### Step 4: Observable Evidence
The kernel log shows:
```text
Kernel command line: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/bin/badinit
```
Unpacking the initramfs (`zcat rootfs.cpio.gz | cpio -t`) reveals that only `/init` exists; `/bin/badinit` is absent.

### Step 5: Narrow Scope
The hardware drivers and initramfs unpacker function properly. The error code `-2` (`-ENOENT`) is returned because the path passed to `rdinit=` does not exist.

### Step 6: Root Cause
Incorrect `rdinit=` or `root=` argument passed on the kernel command line.

### Step 7: Fix
Correct the `-append` boot argument in the QEMU launch command:
```bash
-append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init"
```

### Step 8: Regression Check
Re-run QEMU boot and verify clean handoff to `/init` and interactive shell.
