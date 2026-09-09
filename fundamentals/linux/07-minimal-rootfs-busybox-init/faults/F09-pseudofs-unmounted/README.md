# Fault F09 — Pseudo-Filesystem Unmounted (`/proc` Missing)

## 1. Symptom

The system boots successfully to an interactive BusyBox shell prompt (`/ # `). However, standard diagnostic and process monitoring commands fail with errors:
```text
/ # ps
ps: /proc: No such file or directory

/ # cat /proc/uptime
cat: can't open '/proc/uptime': No such file or directory

/ # cat /proc/cpuinfo
cat: can't open '/proc/cpuinfo': No such file or directory
```

---

## 2. Full Diagnostic Discipline Walkthrough

### Step 1: Own Description
The kernel and userspace shell booted normally without panics. However, any utility attempting to read process information or kernel statistics from `/proc` fails because the virtual `procfs` pseudo-filesystem has not been mounted.

### Step 2: 3–5 Hypotheses
1. `/init` or `/etc/init.d/rcS` omitted the `mount -t proc none /proc` command.
2. The `/proc` mount point directory was not created in the rootfs directory skeleton.
3. The kernel configuration was compiled without `CONFIG_PROC_FS=y`.
4. The mount command failed due to incorrect syntax or filesystem type spelling.

### Step 3: Discriminating Experiment
Check existing mount points and directory existence inside the guest:
```sh
/ # ls -ld /proc
drwxr-xr-x    2 root     root             0 Jan  1 00:00 /proc

/ # ls /proc
(empty output)

/ # mount
(no procfs listed)
```

### Step 4: Observable Evidence
1. The `/proc` directory exists on the filesystem.
2. But `/proc` is completely empty (no process PID subdirectories, no `cpuinfo`, no `uptime`).
3. Running `mount` shows no active `proc` mount.
4. Manually typing `mount -t proc none /proc` succeeds instantly, and subsequent `ps` commands work properly:
   ```sh
   / # mount -t proc none /proc
   / # ps
     PID TTY          TIME CMD
       1 ?        00:00:00 init
      12 ttyAMA0  00:00:00 sh
      15 ttyAMA0  00:00:00 ps
   ```

### Step 5: Narrow Scope
The kernel has `CONFIG_PROC_FS=y` active and `/proc` exists. The failure is strictly due to the init startup script failing to execute the mount command during startup.

### Step 6: Root Cause
`/init` or `/etc/init.d/rcS` failed to mount `procfs` at boot. Note the key pedagogical takeaway:
> **The Linux kernel does NOT require `/proc` to boot to userspace.** However, standard userspace process management tools require `procfs` to function.

### Step 7: Fix
Add the mount command to `/init` or `/etc/init.d/rcS`:
```sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || true
```

### Step 8: Regression Check
Reboot the appliance in QEMU:
- Run `ps`: Successfully lists PID 1, kernel threads, and shell.
- Run `cat /proc/uptime`: Successfully prints system uptime.
