# Fault F07 — Init Missing / Unusable Path

## 1. Symptom

During boot, early console prints startup messages, unpacks the initramfs, but then crashes immediately with a kernel panic:
```text
Failed to execute /sbin/myinit (error -2)
Kernel panic - not syncing: No working init found.  Try passing init= option to kernel. See Linux Documentation/admin-guide/init.rst for guidance.
CPU: 0 PID: 1 Comm: swapper/0 Not tainted 6.18.50 #1
Hardware name: Generic DT based system
[<c0312345>] (unwind_backtrace) from [<c030bcd1>] (show_stack+0xb/0xc)
...
```

---

## 2. Full Diagnostic Discipline Walkthrough

### Step 1: Own Description
The kernel successfully uncompressed, initialized physical memory, set up interrupt controllers, and unpacked the root filesystem archive. However, when the kernel initialization thread (`kernel_init()`) attempted to execute the first userspace program (`/sbin/myinit`), the `kernel_execve()` system call failed with error code `-2` (`-ENOENT`, No such file or directory), causing the kernel to panic because no working fallback init could be found.

### Step 2: 3–5 Hypotheses
1. The kernel command-line parameter `rdinit=/sbin/myinit` specifies a path that does not exist inside the unpacked rootfs.
2. The executable was placed in `/bin` or `/init` instead of `/sbin/myinit`.
3. The initramfs archive failed to unpack, leaving the root directory empty.
4. The executable exists, but it is dynamically linked and its required dynamic linker (`/lib/ld-linux-armhf.so.3`) does not exist on disk (which also returns `-ENOENT`).

### Step 3: Discriminating Experiment
Inspect the actual table of contents of the initramfs archive on the host without running the kernel:
```bash
zcat rootfs.cpio.gz | cpio -tv | grep "init"
```

### Step 4: Observable Evidence
The archive listing shows:
```text
-rwxr-xr-x   1 root     root       1423400 Jan  1 00:00 bin/busybox
lrwxrwxrwx   1 root     root            11 Jan  1 00:00 init -> bin/busybox
```
Observation: The executable exists as `/init`, but the kernel command line specifically requested `rdinit=/sbin/myinit`. The path `/sbin/myinit` does NOT exist in the archive.

### Step 5: Narrow Scope
The initramfs unpacks correctly and contains a valid executable at `/init`. The fault is isolated entirely to a mismatch between the requested `rdinit=` boot argument and the actual location of the binary.

### Step 6: Root Cause
`rdinit=/sbin/myinit` points to a non-existent path. When `kernel_init()` calls `try_to_run_init_process("/sbin/myinit")`, it returns `-ENOENT` (-2).

### Step 7: Fix
Pass the correct init path via bootargs:
```bash
-append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init"
```
Or create a symlink `/sbin/myinit -> ../bin/busybox` inside the root filesystem.

### Step 8: Regression Check
Boot QEMU with the corrected command line. Verify:
1. `Failed to execute ... (error -2)` disappears from serial logs;
2. Kernel logs show `Run /init as init process`;
3. Userspace shell prompt (`/ # `) appears cleanly.
