# Lab 3.3 — Essential Device Access: Static Nodes vs. devtmpfs

## 1. Objective

Understand how the Linux kernel maps physical hardware devices to userspace file paths under `/dev`. Distinguish between traditional static device nodes created with `mknod` and the modern dynamic kernel-managed `devtmpfs` filesystem, and learn exactly what our Phase 3 kernel configuration (`CONFIG_DEVTMPFS=y`, `CONFIG_DEVTMPFS_MOUNT=y`) does — and does not — do on an **initramfs** boot.

---

## 2. Theoretical Foundation

In UNIX/Linux, devices are accessed via special inode entries characterized by:
- **Type**: Character device (`c`, byte stream, e.g. serial ports, consoles) or Block device (`b`, random-access blocks, e.g. hard disks, eMMC, virtio-blk).
- **Major Number**: Identifies the device driver responsible for handling the I/O.
- **Minor Number**: Identifies the specific physical or virtual device instance managed by that driver.

Historically, the root filesystem developer manually ran `mknod` to populate `/dev`:
```bash
# /dev/null: Character, Major 1, Minor 3, readable/writable by all
mknod -m 666 dev/null c 1 3

# /dev/console: Character, Major 5, Minor 1, root access only
mknod -m 600 dev/console c 5 1
```

### What `CONFIG_DEVTMPFS_MOUNT=y` Actually Does (read carefully)

Our Phase 3 kernel sets `CONFIG_DEVTMPFS=y` and `CONFIG_DEVTMPFS_MOUNT=y`. The Kconfig help for `DEVTMPFS_MOUNT` (`drivers/base/Kconfig`, Linux 6.18.50) states:

> This will instruct the kernel to automatically mount the devtmpfs filesystem at `/dev`, directly after the kernel has mounted the root filesystem. […] **This option does not affect initramfs based booting, here the devtmpfs filesystem always needs to be mounted manually after the rootfs is mounted.**

Consequences for this module's initramfs path:

1. **No automatic `/dev` mount before PID 1.** On initramfs boot the kernel does NOT mount devtmpfs for you, even with `CONFIG_DEVTMPFS_MOUNT=y`. Userspace must run `mount -t devtmpfs none /dev` itself (as our `/init` and `/etc/init.d/rcS` do).
2. **Static nodes still matter for initial stdio.** Before userspace mounts devtmpfs, the kernel's `console_on_rootfs()` opens `/dev/console` for PID 1's stdin/stdout/stderr. If the archive carries no static `/dev/console`, the kernel logs `Warning: unable to open an initial console.` Our canonical real rootfs therefore ships static `dev/console (c 5 1, 600)` and `dev/null (c 1 3, 666)` nodes, encoded deterministically (see below). Once userspace mounts devtmpfs over `/dev`, the dynamic nodes take over.
3. **Block-root boots differ.** On a persistent block root filesystem the automount DOES apply after the kernel mounts the rootfs — one more reason to keep the two boot paths conceptually separate.

### Deterministic Device Nodes Without Root

Creating device nodes with `mknod` normally requires root, which would make packaging host-dependent. Our hermetic packager avoids that: list the nodes in a `devnodes.manifest` next to the staging tree:

```text
dev/console c 5 1 600
dev/null c 1 3 666
```

`scripts/package_initramfs.sh` detects the manifest and routes packaging through `scripts/pycpio.py`, which encodes correct character-device type, major/minor, and mode directly into the `newc` headers — no root, fully deterministic. Validate the result from archive metadata (not from an unprivileged extraction, which cannot recreate nodes):

```bash
bash scripts/verify_initramfs_nodes.sh fixtures/build/real_rootfs.cpio.gz
```

---

## 3. Hands-On Execution

1. In your rootfs staging directory, inspect the `/dev` mount point and manifest:
   ```bash
   ls -la dev/ && cat devnodes.manifest
   ```

2. Canonical userspace mount (in `/init` or `/etc/init.d/rcS`) — still required on initramfs:
   ```bash
   mount -t devtmpfs none /dev
   ```

3. Inspect encoded node metadata straight from the archive:
   ```bash
   zcat rootfs.cpio.gz > /tmp/a.cpio
   python3 ../scripts/pycpio.py --list /tmp/a.cpio | grep -E "dev/console|dev/null"
   # expect: char 0600 5:1 dev/console, char 0666 1:3 dev/null
   ```

4. In the running guest, observe the handoff: static nodes at first console open, then the devtmpfs mount over `/dev`:
   ```sh
   cat /proc/mounts | grep /dev
   # none /dev devtmpfs rw,relatime,... 0 0
   ```
