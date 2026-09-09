# Lab 3.5 — Deterministic Initramfs CPIO Archive Packaging

## 1. Objective

Package the manual root filesystem into a compressed CPIO archive (`initramfs`) suitable for direct kernel booting in QEMU. Understand the CPIO `newc` archive format, file permissions preservation, symlink handling, and deterministic packaging techniques.

---

## 2. Theoretical Foundation

The Linux kernel supports multiple mechanisms for obtaining its initial root filesystem:
- **`initramfs` (Initial RAM File System)**: A gzipped CPIO archive packed with userspace files. When passed via the `-initrd` flag in QEMU (or embedded in `zImage`), the kernel's unpacker (`init/initramfs.c`) unpacks the archive directly into a `tmpfs` RAM disk mounted at `/`. The kernel then looks for `/init`.
- **Block Root (`root=/dev/vda` or `root=/dev/mmcblk0p2`)**: A block storage partition formatted with `ext4` or other disk filesystem. The kernel mounts the storage driver and opens the root partition directly.

### The CPIO `newc` Format
Linux initramfs requires the SVR4 portable CPIO format without CRC (`newc`):
- Magic bytes: `070701` (ASCII).
- Each file header contains file permissions, UID/GID (usually 0/0 for root), file size, and path name.
- Symbolic links are stored with their target path string as the file content.
- The archive ends with a special header named `TRAILER!!!`.

### Deterministic Packaging Requirements
To ensure reproducible builds:
1. **Filename sorting**: Directory traversal order must be fixed across hosts using `LC_ALL=C sort`.
2. **Normalized timestamps**: Timestamps inside the archive should be normalized to avoid unnecessary hash churn.
3. **Gzip normalization**: Using `gzip -n` prevents embedding timestamps in the gzip header.

---

## 3. Hands-On Execution

1. Change into your rootfs staging directory:
   ```bash
   cd /path/to/rootfs-staging
   ```

2. Package using standard `cpio`:
   ```bash
   find . -mindepth 1 | LC_ALL=C sort | cpio -o -H newc | gzip -9 -n > ../rootfs.cpio.gz
   ```

3. Or package using the provided hermetic script:
   ```bash
   bash ../scripts/package_initramfs.sh $(pwd) ../rootfs.cpio.gz
   ```

4. Audit archive contents:
   ```bash
   zcat ../rootfs.cpio.gz | cpio -tv | head -n 25
   ```
   Verify:
   - `/init` exists and has `-rwxr-xr-x` permissions (`0755`);
   - Applet symlinks (`/bin/sh`, `/bin/ls`) point to `busybox`;
   - Empty directories (`/proc`, `/sys`, `/dev`) are present.
