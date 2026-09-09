# P3-M03 — Manual Minimal Rootfs, BusyBox, Pseudo-Filesystems & PID 1 Init Lifecycle

> **Phase 3 / Module 03**  
> **Target Depth:** L3 Rootfs & Init Architecture / L4-Local Init Fault Diagnostics  
> **Prerequisites:** P3-M01 (Cross-Toolchains, Static vs Dynamic Linkage), P3-M02 (Linux Kernel Build & Boot Flow), P1-M02/M04 (File Descriptors & Process Lifecycle)  
> **Planned Learner Time:** **4.0 h MUST**, 1.0 h SHOULD  
> **AI Mode:** AI-Free first attempt on Challenge and Gate; official upstream documentation and source reading permitted.

---

## 1. Why Manual Rootfs Construction Matters

In P3-M02, we cross-compiled the Linux kernel and booted it in QEMU, observing the canonical kernel panic:
```text
Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
```
The kernel brought up CPU cores, memory banks, and serial drivers, but halted because it had no filesystem from which to launch the first userspace program.

Many embedded tutorials immediately jump to automated build systems like Buildroot or Yocto to generate filesystem images. Doing so too early creates a major conceptual blind spot: developers treat the root filesystem as an opaque black box. When an appliance hangs at boot with `Exec format error`, `Permission denied`, or silent shell drops, developers who only know how to run `make menuconfig` cannot diagnose the failure.

In this module, you construct an Embedded Linux root filesystem **entirely by hand**:
1. Build the minimal **Filesystem Hierarchy Standard (FHS)** directory skeleton;
2. Cross-compile a statically linked **BusyBox 1.36.1** multi-call binary;
3. Understand device nodes (`/dev/console`, `/dev/null`) and the dynamic `devtmpfs` filesystem;
4. Implement **PID 1**, mounting essential kernel pseudo-filesystems (`procfs`, `sysfs`);
5. Package the filesystem into a deterministic **initramfs CPIO archive**;
6. Boot real Linux 6.18.50 to an interactive shell in QEMU and capture empirical evidence.

---

## 2. Mental Model

### 2.1 The Kernel-to-Userspace Handshake Continuum

```text
+-------------------------------------------------------------------------------+
| KERNEL SPACE (Linux 6.18.50 LTS)                                              |
|                                                                               |
| 1. start_kernel() -> setup_arch() -> mm_init() -> console_init()              |
| 2. rest_init() spawns PID 1 kernel thread: kernel_init()                      |
| 3. Unpack initramfs archive into root tmpfs VFS (init/initramfs.c)             |
| 4. Search for init candidate via try_to_run_init_process():                   |
|    - rdinit= argument (default: /init)                                        |
|    - /sbin/init, /etc/init, /bin/init, /bin/sh                                |
| 5. kernel_execve() transitions CPU from privileged PL1 (SVC) to PL0 (User)    |
+-------------------------------------------------------------------------------+
                                      |
                                      v
+-------------------------------------------------------------------------------+
| USERSPACE (PID 1 — /init or /sbin/init)                                       |
|                                                                               |
| 1. PID 1 Startup: Must never exit; immune to unhandled signals                |
| 2. Mount Pseudo-Filesystems:                                                  |
|    - mount("proc", "/proc", "proc", 0, NULL) -> Process & telemetry window    |
|    - mount("sysfs", "/sys", "sysfs", 0, NULL) -> Unified Device Model / DT   |
|    - mount("devtmpfs", "/dev", "devtmpfs", 0, NULL) -> Dynamic device nodes   |
| 3. Orphan Adoption & Zombie Reaping:                                          |
|    - Adopts all orphan child processes                                        |
|    - Continually calls waitpid(-1, NULL, WNOHANG) to reap zombie processes    |
| 4. Spawn Interactive Root Shell (/bin/sh on ttyAMA0)                          |
+-------------------------------------------------------------------------------+
```

---

### 2.2 FHS Directory Skeleton

The Filesystem Hierarchy Standard defines standard locations for binaries and configuration. An embedded appliance uses a stripped-down subset:

- `/bin` & `/sbin`: Fundamental system commands and administration utilities provided by BusyBox applets.
- `/etc`: Configuration files (`/etc/inittab`, `/etc/init.d/rcS`).
- `/dev`: Hardware device node interface. Managed by `devtmpfs` under `CONFIG_DEVTMPFS_MOUNT=y`.
- `/proc`: Kernel process statistics and system telemetry (`procfs`). Contains no disk files.
- `/sys`: Kernel device hierarchy, drivers, and device tree (`sysfs`). Contains no disk files.
- `/tmp` & `/run`: Ephemeral runtime memory filesystems (`tmpfs`).
- `/mnt` & `/root`: Mount point for persistent external drives and root user home directory.

---

### 2.3 BusyBox Multi-Call Binary Architecture

Rather than shipping hundreds of separate binaries, BusyBox compiles all tools into a single executable (`/bin/busybox`):
- All command names (`/bin/sh`, `/bin/ls`, `/bin/ps`, `/sbin/init`) are **symbolic links** pointing to `/bin/busybox`.
- When invoked, `libbb/appletlib.c` inspects `argv[0]`.
- BusyBox dispatches directly to the matching internal function (e.g. `ls_main()`, `init_main()`, `ash_main()`).
- Statically linking BusyBox (`CONFIG_STATIC=y`) ensures zero dynamic linker (`/lib/ld-linux-armhf.so.3`) or shared library dependencies.

---

### 2.4 The Special Status of PID 1

Process ID 1 is fundamentally distinct from every other process in Linux:
1. **Immortal**: If PID 1 terminates, the kernel panics immediately with `Attempted to kill init!`.
2. **Signal Immunity**: Signals like `SIGINT` or `SIGTERM` sent to PID 1 are ignored unless PID 1 installs explicit signal handlers.
3. **Orphan Re-Parenting**: Any child whose parent dies is adopted by PID 1.
4. **Zombie Reaping**: Terminated processes remain zombies (`Z`) until reaped. PID 1 must call `waitpid(-1, ...)` in its event loop to prevent process table exhaustion.

---

## 3. Authoritative Sources & Source Reading

To build rigorous engineering intuition, inspect the real source code:

1. **Linux Kernel 6.18.50 LTS**:
   - `init/main.c: kernel_init()`: Trace how `ramdisk_execute_command` (from `rdinit=`) is evaluated before fallback candidates.
   - `init/main.c: try_to_run_init_process()`: Notice that `kernel_execve()` return codes are printed when execution fails (e.g. `-EACCES` (-13) when executable bit is missing; `-ENOENT` (-2) when path does not exist).
   - `Documentation/filesystems/ramfs-rootfs-initramfs.rst`: Read the distinction between `initramfs` (tmpfs archive) and legacy block ramdisk (`initrd`).
2. **BusyBox 1.36.1**:
   - `applets/applets.c` & `libbb/appletlib.c`: Trace the `applet_name` resolution loop matching `argv[0]`.
   - `init/init.c: init_main()`: Trace signal handler installation and the main event loop calling `check_delayed_sigs() -> waitpid(-1, NULL, WNOHANG)`.

---

## 4. Hands-On Lab Sequence

| Lab | Directory | Core Concept | Deliverable |
|---|---|---|---|
| **Lab 3.1** | `labs/01-fhs-skeleton/` | FHS directory skeleton & mount points | Minimal directory tree |
| **Lab 3.2** | `labs/02-busybox-install/` | Static BusyBox compilation & applet symlinks | Static ARM ELF audit |
| **Lab 3.3** | `labs/03-device-nodes/` | Character nodes (`/dev/console`) vs `devtmpfs` | Device access setup |
| **Lab 3.4** | `labs/04-init-script/` | PID 1 init lifecycle & pseudo-filesystem mounts | Working `/init` script |
| **Lab 3.5** | `labs/05-initramfs-archive/` | Deterministic `cpio` packaging (`newc` format) | `rootfs.cpio.gz` archive |
| **Lab 3.6** | `labs/06-qemu-interactive-boot/` | QEMU virtual machine bring-up to shell | Live interactive shell |

---

## 5. Controlled Faults & Diagnostic Walkthroughs

Practice the disciplined diagnostic loop:
$$\text{Symptom} \longrightarrow \text{Own Description} \longrightarrow \text{3–5 Hypotheses} \longrightarrow \text{Experiment} \longrightarrow \text{Evidence} \longrightarrow \text{Narrow Scope} \longrightarrow \text{Root Cause} \longrightarrow \text{Fix} \longrightarrow \text{Regression}$$

- **Fault F07 (`faults/F07-init-missing/`)**: Init path missing or unusable (`rdinit=/nonexistent`). Diagnose kernel panic and `-ENOENT` (-2).
- **Fault F08 (`faults/F08-init-permissions/`)**: Init missing executable mode (`chmod 0644 /init`). Diagnose kernel `-EACCES` (-13).
- **Fault F09 (`faults/F09-pseudofs-unmounted/`)**: Userspace shell reachable but `/proc` unmounted. Diagnose `ps` failure without kernel panic.

---

## 6. AI-Free Challenge: Production BusyBox Init

Located in `challenge/README.md`:
Transform the prototype `/init` shell script into a production-grade BusyBox `/sbin/init` configuration with `/etc/inittab`, `/etc/init.d/rcS`, and an interactive `askfirst` shell on `ttyAMA0`.

---

## 7. AI-Free Module Gate Exam

Located in `gate/README.md`:
Given a defective rootfs staging directory, execute the diagnostic loop, resolve all permission and symlink defects, package a clean initramfs, and prove interactive shell boot in QEMU.

---

## 8. Verification & Automation

```bash
# Run learner-safe verification suite
make check

# Build real static BusyBox from upstream source
make real-busybox-build-check

# Execute strict actual-host QEMU boot to interactive shell
make real-qemu-check
```
