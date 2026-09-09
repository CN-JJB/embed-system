# Lab 2.4 — QEMU Direct Kernel Boot Contract

## Objective
1. Master the canonical QEMU launch command for Phase 3.
2. Understand the technical contract behind every command-line flag.
3. Understand how QEMU provides the Device Tree Blob (DTB) automatically to register `r2` in direct boot.
4. Understand why the kernel terminates in a VFS root mount panic (`Unable to mount root fs`) and why this confirms successful kernel boot.

## Canonical Command Line
```bash
qemu-system-arm \
  -machine virt,highmem=off,gic-version=2 \
  -cpu cortex-a7 \
  -m 512M \
  -smp 1 \
  -nographic \
  -kernel arch/arm/boot/zImage
```

> [!NOTE]
> **Device Tree Passing Contract in Direct Boot**:  
> In QEMU direct kernel boot (`-kernel`), QEMU automatically generates an internal Device Tree conforming to the machine configuration and places its physical address into CPU register **`r2`** prior to entering the kernel entry point. While bare-metal boot paths may place firmware/DTB at the fixed RAM base (`0x40000000`), the 32-bit ARM Linux direct-boot protocol dynamically receives the DTB address via `r2`.

## Parameter Contract Breakdown
- `-machine virt,highmem=off,gic-version=2`:
  - `virt`: Generic ARM virtual platform.
  - `highmem=off`: Mandatory because our curriculum freezes `CONFIG_ARM_LPAE=n`. If `highmem` is left enabled, QEMU maps MMIO devices and high memory above 4 GB, out of range of a 32-bit short-descriptor translation table.
  - `gic-version=2`: Explicitly instantiates the ARM GICv2 interrupt controller at `0x08000000`.
- `-cpu cortex-a7`:
  - Overrides QEMU's default CPU model (`cortex-a15`) to standardize on Cortex-A7 (ARMv7-A).
- `-m 512M`: Allocates 512 MB physical DRAM starting at `0x40000000`.
- `-smp 1`: Single core configuration matching `CONFIG_NR_CPUS=1`.
- `-nographic`: Directs the PL011 serial UART directly to your terminal standard I/O.
- `-kernel arch/arm/boot/zImage`: Loads the compressed self-extracting kernel into RAM.

## Expected Runtime Milestone
In Module 02, no root filesystem or initramfs is supplied.
When booted, the kernel initializes memory, starts CPU 0, binds the PL011 serial driver, mounts devtmpfs, initializes timers and interrupts, and attempts to find PID 1.
Because no root device is given on the command line (`root=`), the kernel panics:
```text
Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
```
This panic is **expected proof of success**: it demonstrates that the kernel successfully executed all early hardware and subsystem bring-up stages, stopping only at the boundary where userspace filesystem handoff begins (which is built in Module P3-M03).
