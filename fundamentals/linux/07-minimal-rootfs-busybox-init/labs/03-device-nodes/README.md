# Lab 3.3 — Essential Device Access: Static Nodes vs. devtmpfs

## 1. Objective

Understand how the Linux kernel maps physical hardware devices to userspace file paths under `/dev`. Distinguish between traditional static device nodes created with `mknod` and the modern dynamic kernel-managed `devtmpfs` filesystem enabled in our Phase 3 kernel configuration (`CONFIG_DEVTMPFS=y` and `CONFIG_DEVTMPFS_MOUNT=y`).

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

### The Role of `CONFIG_DEVTMPFS_MOUNT=y`

In our frozen Phase 3 kernel configuration:
- `CONFIG_DEVTMPFS=y`: Enables the kernel-space device filesystem driver.
- `CONFIG_DEVTMPFS_MOUNT=y`: Instructs the kernel to automatically mount `devtmpfs` onto `/dev` *before* launching PID 1.

When `CONFIG_DEVTMPFS_MOUNT=y` is active:
1. The kernel creates and manages device nodes dynamically as hardware drivers register.
2. Static nodes created on the storage media are hidden under the mounted `devtmpfs`.
3. However, if the kernel is booted with `CONFIG_DEVTMPFS_MOUNT=n`, or if the early console is opened before `devtmpfs` mounts, a static `/dev/console` node in the rootfs is essential to prevent early userspace launch failure.

---

## 3. Hands-On Execution

1. In your rootfs staging directory, inspect the `/dev` directory:
   ```bash
   ls -la dev/
   ```

2. If building an initramfs without relying on root privileges for `mknod`:
   - Because creating physical device nodes requires `sudo` or `fakeroot`, our build workflow leverages `CONFIG_DEVTMPFS_MOUNT=y` or mounts `devtmpfs` in the startup script:
   ```bash
   # In /init or /etc/init.d/rcS
   mount -t devtmpfs none /dev
   ```

3. If running in an environment with root access:
   ```bash
   sudo mknod -m 600 dev/console c 5 1
   sudo mknod -m 666 dev/null c 1 3
   ```

4. Verify that `/dev` exists as a directory ready for kernel mounting.
