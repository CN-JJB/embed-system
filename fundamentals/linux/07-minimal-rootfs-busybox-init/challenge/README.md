# P3-M03 AI-Free Challenge — Production BusyBox Init & inittab Configuration

## 1. Challenge Briefing

In Lab 3.4, you used a simple shell script (`/init`) to bootstrap userspace. While functional for quick prototypes, production Embedded Linux systems typically use a dedicated init supervisor like **BusyBox `/sbin/init`** configured through `/etc/inittab`.

In this AI-Free challenge, you must configure a clean, production-oriented BusyBox init architecture from scratch:
1. Configure `/etc/inittab` with standard BusyBox init actions (`sysinit`, `askfirst`, `ctrlaltdel`, `shutdown`).
2. Write `/etc/init.d/rcS` to initialize pseudo-filesystems (`/proc`, `/sys`, `/dev`).
3. Configure the primary serial console on `ttyAMA0` using the `askfirst` action (`ttyAMA0::askfirst:-/bin/sh`).
4. Ensure all applet symlinks, directories, and file permissions are properly structured.
5. Package the root filesystem into `rootfs_challenge.cpio.gz`.
6. Boot the system in QEMU with `rdinit=/sbin/init` and verify that pressing Enter displays the shell prompt and `ps` confirms `/sbin/init` as PID 1.

---

## 2. Assessment Rules (AI-Free)

> [!IMPORTANT]
> - **AI-Free Mode**: You may consult official upstream documentation (BusyBox FAQ, Linux kernel documentation, man pages `inittab(5)`), but you must NOT use automated AI code generation.
> - **Assessment Integrity**: You must NOT inspect grading reference solutions or hidden test fixtures until your attempt is submitted and scored.
> - **Verification Evidence**: A valid submission requires observable terminal evidence from the booted guest showing PID 1 process state and active mounts.

---

## 3. Implementation Contract

Your rootfs staging directory must satisfy:

1. **Init Executable**:
   - `/sbin/init` must exist and be an executable symbolic link pointing to `/bin/busybox`.
2. **Inittab File (`/etc/inittab`)**:
   - Must include a `sysinit` line targeting `/etc/init.d/rcS`.
   - Must include an `askfirst` line on `ttyAMA0` launching `-/bin/sh`.
3. **Startup Script (`/etc/init.d/rcS`)**:
   - Must possess executable permission (`0755`).
   - Must mount `/proc` (type `proc`).
   - Must mount `/sys` (type `sysfs`).
   - Must mount `/dev` (type `devtmpfs`).
4. **Interactive Verification**:
   - When booted in QEMU, the console displays:
     ```text
     Please press Enter to activate this console.
     ```
   - Pressing Enter yields the BusyBox prompt (`/ # `).
   - `ps` shows:
     ```text
       PID TTY          TIME CMD
         1 ?        00:00:00 init
     ...
     ```

---

## 4. Verification Command

Package your rootfs and run the validation target:
```bash
make challenge-build
make check
```
