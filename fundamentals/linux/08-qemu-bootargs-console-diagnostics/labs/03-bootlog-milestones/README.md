# Lab 4.3 — Kernel Boot Log Chronology & Semantic Milestones

## 1. Objective

Systematically navigate the Linux kernel boot log (`dmesg`). Understand the chronological progression of subsystem initialization, map log messages to kernel C source files, and establish a milestone-based diagnostic model to isolate boot failures.

---

## 2. Theoretical Foundation: The Milestone Sequence

A full Linux boot log contains hundreds of lines. Effective systems engineers do not scan logs randomly; they trace progress across **semantic milestones**:

```text
[Milestone 1] Architecture Detection & Decompressor Handoff
              Uncompressing Linux... done, booting the kernel.
              Linux version 6.18.50 ...
              CPU: ARMv7 Processor ...
              |
              v
[Milestone 2] Memory Architecture & Early Subsystems
              Memory policy: Data cache writealloc
              percpu: Embedded 13 pages/cpu
              Kernel command line: console=ttyAMA0 ...
              |
              v
[Milestone 3] Core Hardware Drivers (Interrupts, Timers, Serial)
              GICv2 interrupt controller initialized
              clocksource: jiffies / arch_sys_counter
              9000000.pl011: ttyAMA0 at MMIO 0x9000000 (irq = 28)
              printk: console [ttyAMA0] enabled
              |
              v
[Milestone 4] Storage Subsystems & Root Filesystem
              virtio-mmio / virtio-pci registered
              Trying to unpack rootfs image as initramfs...
              Freeing initrd memory: ...
              |
              v
[Milestone 5] Userspace Transition & PID 1
               Freeing unused kernel image (initmem) memory: 2048K
               Run /init as init process
               === REAL-BUSYBOX-INIT-START ===
               === REAL-BUSYBOX-INIT-READY ===
               |
               v
[Milestone 6] Real BusyBox Interactive Environment
               BusyBox v1.36.1 (real multi-call identity)
               PID   USER     TIME  COMMAND   (real 'ps' header)
               none /proc proc ...            (active mounts)
               ~ #                             (real ash prompt)
```

---

## 3. Diagnostic Scope Narrowing Table

When a boot failure terminates with a hang or panic, locate the **last successful milestone**:

| Last Observed Milestone | Failure Domain | Common Root Causes |
|---|---|---|
| Uncompressing Linux... | Early Assembly (`head.S`) | Broken page table setup, `CONFIG_ARM_LPAE` mismatch, CPU mode wrong |
| Linux version | Memory / Architecture Setup | Bad memory parameter (`mem=`), unsupported board DTB, MMU translation fault |
| GIC / Timer | Hardware Driver Initialization | Device Tree IRQ or register typo, missing driver in kernel `.config` |
| Console registration | Storage & VFS Mounting | Corrupted initramfs archive, bad `root=` partition, missing storage driver |
| Trying to unpack rootfs... | Init Candidate Selection | `rdinit=` typo reroutes to VFS panic (`-2` at access check), `init=` path typo (`-ENOENT` = -2), `init=` path missing on disk |
| Run /init as init process | Userspace Execution | Unusable init content (`-ENOENT` = -2 at exec), missing execute bit (`-EACCES` = -13), missing dynamic loader, init exit crash |

---

## 4. Hands-On Execution

1. Capture a full reference boot log from QEMU:
   ```bash
   qemu-system-arm \
       -machine virt,highmem=off,gic-version=2 \
       -cpu cortex-a7 \
       -m 512M \
       -smp 1 \
       -nographic \
       -kernel /path/to/zImage \
       -initrd /path/to/rootfs.cpio.gz \
       -append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init" \
       > /tmp/my_boot.log 2>&1
   ```

2. Run the automated milestone auditor:
   ```bash
   bash ../scripts/audit_boot_milestones.sh /tmp/my_boot.log
   ```

3. Confirm that all key milestones are present and execute in strict chronological order.
