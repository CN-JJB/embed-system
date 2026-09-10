# Fault F04 — Bad Kernel Command Line: Root / Init Selection Failure

> Calibrated on real Linux 6.18.50 (`7cfc41f8e80f11ffa8382ed1a505154ceffb79c7`) + real BusyBox 1.36.1 initramfs, QEMU `virt,highmem=off,gic-version=2`, `-cpu cortex-a7`, `-m 512M`.

## 1. Symptom

A nonexistent `rdinit=` path on an initramfs boot does NOT fall through to `/sbin/init` the way a failed exec does. The kernel's early access check (`init_eaccess()` in `kernel_init_freeable()`, `init/main.c`) detects the missing path before userspace starts, discards the ramdisk init request, and pivots to mounting a block root filesystem — which does not exist here:

```text
[    1.085596] check access for rdinit=/nonexistent failed: -2, ignoring
[    1.098612] Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
```

Key point: the panic is a **VFS root-mount panic**, not `No working init found`. The `No working init found` panic only occurs when the requested init *passes* the early access check but *fails* at `execve()` time (see F07/F08) while every fallback candidate is also unusable.

---

## 2. Full Diagnostic Discipline Walkthrough

### Step 1: Own Description
The kernel boots cleanly through driver registration and initramfs unpacking, then panics while trying to mount a block root device nobody configured.

### Step 2: 3–5 Hypotheses
1. The `rdinit=` path has a typo or points to a nonexistent initramfs entry.
2. The initramfs archive failed to unpack, leaving the root directory empty.
3. The intended init exists but under a different path (`/init` vs `/sbin/init`).
4. A `root=` block device was intended but its driver or device node is missing.

### Step 3: Discriminating Experiment
Inspect the effective kernel command line and the initramfs contents without running the kernel:
```bash
grep "Kernel command line:" /tmp/boot.log
grep "check access for rdinit" /tmp/boot.log
zcat rootfs.cpio.gz | cpio -t 2>/dev/null | grep -E "init"
```

### Step 4: Observable Evidence
The kernel log shows:
```text
Kernel command line: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/nonexistent
check access for rdinit=/nonexistent failed: -2, ignoring
```
The archive listing shows the real init at `/init`; `/nonexistent` is absent. Error `-2` is `-ENOENT` at the *access-check* stage, which routes to `prepare_namespace()` (block-root path) rather than the initramfs fallback list.

### Step 5: Narrow Scope
Drivers, unpacker, and the real `/init` are all healthy. The fault is isolated to the mismatch between the requested `rdinit=` path and the archive contents.

### Step 6: Root Cause
`rdinit=/nonexistent` fails the pre-userspace access check, so the kernel abandons the initramfs init path and panics mounting a nonexistent block root.

### Step 7: Fix
Correct the `-append` boot argument:
```bash
-append "earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init"
```

### Step 8: Regression Check
Re-run QEMU boot and verify `Run /init as init process` followed by `REAL-BUSYBOX-INIT-READY` and a real BusyBox shell.

---

## 3. Contrast With F07/F08 (read before diagnosing)

| Requested init state | Early access check | Outcome on this rootfs |
|---|---|---|
| Path missing (`rdinit=/nonexistent`) | fails (`-2`) → `prepare_namespace()` | **VFS panic** (this fault) |
| Path exists, exec fails (`-13`/`-2` at `execve`), fallbacks present | passes | **falls through** to `/sbin/init` → boots (no panic) |
| Path exists, exec fails, fallbacks removed | passes | `Failed to execute …` → `No working init found` panic (F07/F08) |
