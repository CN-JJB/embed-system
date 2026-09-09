# Lab 3.4 — PID 1 / Init Process Lifecycle & Pseudo-Filesystems

## 1. Objective

Implement the first userspace program executed by the Linux kernel (**PID 1**). Understand the unique responsibilities of PID 1 (process lifetime, signal handling, orphan process adoption, zombie reaping, and pseudo-filesystem initialization). Compare a shell script init (`/init`) with BusyBox init (`/sbin/init` + `/etc/inittab`).

---

## 2. Theoretical Foundation

### The Special Status of PID 1

In Linux, process creation follows `fork()` and `execve()`. However, the very first process in userspace cannot be created by `fork()` from another userspace process. Instead:
1. The kernel initialization thread (`init/main.c: kernel_init()`) mounts the root filesystem.
2. The kernel invokes `try_to_run_init_process()`, which calls the kernel-internal `kernel_execve()` to load and execute the init program.
3. This process receives Process ID **1** (PID 1).

PID 1 has unique operating system semantics:
- **Never terminates**: If PID 1 ever exits, the Linux kernel immediately issues a kernel panic:
  ```text
  Kernel panic - not syncing: Attempted to kill init! exitcode=...
  ```
- **Signal immunity**: Unlike normal processes, unhandled signals (like `SIGTERM`, `SIGINT`) sent to PID 1 are discarded by default by the kernel unless PID 1 explicitly installs a signal handler.
- **Orphan adoption**: When any parent process dies before its child, the child becomes an "orphan". The Linux kernel re-parents all orphan processes to PID 1.
- **Zombie reaping**: When a process terminates, it enters the `ZOMBIE` state (`EXIT_ZOMBIE`) until its parent reads its exit status via `waitpid()`. Because orphans are adopted by PID 1, PID 1 **must continuously reap terminating children** (`waitpid(-1, &status, WNOHANG)`) to prevent zombie processes from exhausting kernel PID table entries.

### Pseudo-Filesystems

The kernel communicates its internal status to userspace via virtual pseudo-filesystems that exist entirely in kernel RAM:
- **`procfs` (`mount -t proc none /proc`)**:
  - Exposes process status directories (`/proc/<pid>/cmdline`, `/proc/<pid>/status`, `/proc/<pid>/fd/`).
  - Exposes kernel telemetry: `/proc/cpuinfo`, `/proc/meminfo`, `/proc/uptime`, `/proc/mounts`, `/proc/cmdline`.
  - Tools like `ps`, `top`, `killall`, and `free` fail completely if `/proc` is unmounted.
- **`sysfs` (`mount -t sysfs none /sys`)**:
  - Exposes the kernel Unified Device Model (devices, buses, classes, power management).
  - Exposes compiled Device Tree properties under `/sys/firmware/devicetree/base`.
- **`devtmpfs` (`mount -t devtmpfs none /dev`)**:
  - Populates hardware device nodes dynamically as drivers register with the kernel.

---

## 3. Hands-On Execution

We examine two canonical init implementations:

### Method A: Minimal Shell Script Init (`/init`)
Ideal for early bring-up and debugging:

```bash
cat << 'EOF' > rootfs-staging/init
#!/bin/sh
# Minimal PID 1 Shell Init Script

echo "===================================================="
echo "=== Minimal PID 1 Userspace Initialized (PID: $$) ==="
echo "===================================================="

# Mount essential pseudo-filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || true

echo "[INIT] Mounted /proc, /sys, and /dev successfully."

# Exec into interactive shell so shell takes over PID 1 or stays alive
exec /bin/sh
EOF

chmod +x rootfs-staging/init
```

> [!CAUTION]
> Note the `exec /bin/sh`. Using `exec` replaces the shell process with the interactive shell without changing PID 1. If the script simply ended with `/bin/sh` without `exec`, exiting the sub-shell would cause the script to reach EOF and exit, immediately triggering a kernel panic!

### Method B: BusyBox Init (`/sbin/init` + `/etc/inittab`)
Standard for production BusyBox appliances:

1. `/etc/inittab`:
   ```ini
   ::sysinit:/etc/init.d/rcS
   ttyAMA0::askfirst:-/bin/sh
   ::ctrlaltdel:/sbin/reboot
   ::shutdown:/bin/umount -a -r
   ```

2. `/etc/init.d/rcS`:
   ```bash
   #!/bin/sh
   mount -t proc none /proc
   mount -t sysfs none /sys
   mount -t devtmpfs none /dev 2>/dev/null || true
   echo "=== Embedded Linux System Initialized ==="
   ```
   `chmod +x /etc/init.d/rcS`

3. In this model, `/sbin/init` handles signal processing, executes `/etc/init.d/rcS`, spawns the interactive shell on `ttyAMA0`, and runs an internal event loop that reaps zombie processes via `waitpid(-1, NULL, WNOHANG)`.
