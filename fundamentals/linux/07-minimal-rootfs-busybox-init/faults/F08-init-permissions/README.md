# Fault F08 — Init Permission / Execution Failure

## 1. Symptom

During boot, the kernel unpacks initramfs and attempts to launch `/init`, but immediately logs an error and panics:
```text
Failed to execute /init (error -13)
Kernel panic - not syncing: No working init found.  Try passing init= option to kernel. See Linux Documentation/admin-guide/init.rst for guidance.
CPU: 0 PID: 1 Comm: swapper/0 Not tainted 6.18.50 #1
```

---

## 2. Full Diagnostic Discipline Walkthrough

### Step 1: Own Description
The kernel successfully locates `/init` in the unpacked root filesystem, but execution fails with kernel error code `-13` (`-EACCES`, Permission denied), causing `kernel_init()` to fail and terminate in a panic.

### Step 2: 3–5 Hypotheses
1. `/init` exists but does not have the executable mode bit set (`chmod +x` missing; mode is `0644` instead of `0755`).
2. `/init` resides on a filesystem mounted with the `noexec` mount flag.
3. `/init` is a script whose shebang interpreter (e.g. `#!/bin/sh`) lacks executable permissions.
4. SELinux or LSM policy denies execution (not applicable on minimal appliance).

### Step 3: Discriminating Experiment
Inspect the inode permissions inside the initramfs archive:
```bash
zcat rootfs.cpio.gz | cpio -tv | grep -E "init|bin/sh"
```

### Step 4: Observable Evidence
The archive listing shows:
```text
-rw-r--r--   1 root     root       1423400 Jan  1 00:00 init
-rwxr-xr-x   1 root     root       1423400 Jan  1 00:00 bin/busybox
```
Observation: `/init` has mode `0644` (`-rw-r--r--`). The execute bit (`x`) is completely missing for owner, group, and others.

### Step 5: Narrow Scope
The file is present, the path is correct, and the binary is valid. The failure is isolated strictly to filesystem mode bits stored in the CPIO archive header.

### Step 6: Root Cause
When the kernel's `sys_execve()` / `do_execveat_common()` checks file permissions (`inode_permission(..., MAY_EXEC)`), it encounters a file lacking execute flags and returns `-EACCES` (-13).

### Step 7: Fix
Set executable permission on `/init` in the staging directory and repackage:
```bash
chmod +x rootfs-staging/init
bash scripts/package_initramfs.sh rootfs-staging rootfs.cpio.gz
```

### Step 8: Regression Check
1. Verify mode in archive:
   ```bash
   zcat rootfs.cpio.gz | cpio -tv | grep "init"
   # Must show -rwxr-xr-x
   ```
2. Boot in QEMU:
   - `Failed to execute /init (error -13)` is eliminated.
   - Clean handoff to userspace shell occurs.
