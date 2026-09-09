# Lab 3.2 — Statically Linked BusyBox Build, ELF Audit & Applet Installation

## 1. Objective

Cross-compile the pinned **BusyBox 1.36.1** multi-call utility as a statically linked 32-bit ARM executable. Prove via `readelf` that the binary has no dynamic interpreter (`PT_INTERP`) or shared library dependencies (`DT_NEEDED`). Install the binary and generate applet symlinks into the staging rootfs.

---

## 2. Multi-Call Binary Architecture

A full GNU/Linux distribution installs hundreds of independent executable binaries (`/bin/ls`, `/bin/cp`, `/bin/cat`, `/bin/echo`), each containing its own ELF header, startup code, and library linkages. On resource-constrained embedded systems, this causes severe storage bloat.

BusyBox solves this via the **multi-call binary** pattern:
1. All utilities (applets) are compiled into a **single unified ELF executable** (`/bin/busybox`).
2. Applet names in `/bin` and `/sbin` are **symbolic links** pointing to `/bin/busybox`:
   ```text
   /bin/ls    -> /bin/busybox
   /bin/sh    -> /bin/busybox
   /sbin/init -> ../bin/busybox
   ```
3. When the user executes `/bin/ls -l /tmp`:
   - The kernel executes `/bin/busybox` with `argv[0] = "/bin/ls"`.
   - `libbb/appletlib.c` strips directory prefixes and inspects the basename (`"ls"`).
   - BusyBox performs a binary search on the internal `applet_names[]` table and jumps directly to `ls_main(argc, argv)`.

---

## 3. Rationale for Static Linkage in Minimal Rootfs

In P3-M01, we saw that dynamically linked binaries require:
1. An exact dynamic linker path (`/lib/ld-linux-armhf.so.3`);
2. Shared C libraries (`libc.so.6`, `libm.so.6`, `libresolv.so.2`) in `/lib` or `/usr/lib`.

If any shared library or the dynamic loader is missing from the rootfs, the kernel immediately aborts execution with:
```text
/bin/sh: No such file or directory
```
For our initial manual root filesystem, compiling BusyBox with `CONFIG_STATIC=y` eliminates all runtime library dependencies. The binary runs self-contained as soon as the kernel enters userspace.

---

## 4. Hands-On Execution

1. Configure BusyBox for static compilation:
   ```bash
   cd /path/to/busybox-1.36.1
   make defconfig
   sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
   # Disable CONFIG_TC to eliminate dependency on deprecated CBQ headers
   sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' .config
   ```

2. Cross-compile for ARM:
   ```bash
   make -j$(nproc) ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabihf-
   ```
   *(On Ubuntu distro hosts, pass `CROSS_COMPILE=arm-linux-gnueabihf-`)*

3. Audit the compiled ELF binary:
   ```bash
   readelf -h busybox | grep "Machine:"
   readelf -l busybox | grep "INTERP" || echo "[PASS] No PT_INTERP (Statically linked)"
   readelf -d busybox 2>&1 | grep "NEEDED" || echo "[PASS] No DT_NEEDED shared libraries"
   ```

4. Install into staging rootfs:
   ```bash
   make ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabihf- install CONFIG_PREFIX=/path/to/rootfs-staging
   ```

5. Verify applets created:
   ```bash
   ls -l /path/to/rootfs-staging/bin/sh
   ls -l /path/to/rootfs-staging/sbin/init
   ```

---

## 5. Automated Verification

Run the ELF audit script:
```bash
bash ../scripts/audit_busybox_elf.sh /path/to/rootfs-staging/bin/busybox
```
Expected output:
```text
[PASS] ELF static ARM identity verified: ... (Machine: ARM, Static: YES, No PT_INTERP, No DT_NEEDED)
```
