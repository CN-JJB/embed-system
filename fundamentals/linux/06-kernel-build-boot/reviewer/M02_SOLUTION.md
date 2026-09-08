# P3-M02 Solution & Reference Evidence

> Reviewer Reference Only.

## 1. Effective Kernel Configuration Reference
- `CONFIG_ARCH_VIRT=y`: Generic ARM virtual platform active.
- `CONFIG_ARM_LPAE`: Not set (`# CONFIG_ARM_LPAE is not set` / `=n`), enforcing 2-level short-descriptor translation tables.
- `CONFIG_VMSPLIT_3G=y`: 3 GB user virtual space (`0x00000000`–`0xBFFFFFFF`), 1 GB kernel space (`0xC0000000`–`0xFFFFFFFF`).
- `CONFIG_PAGE_OFFSET=0xC0000000`: Base address of kernel virtual space.
- `CONFIG_SERIAL_AMBA_PL011=y` & `CONFIG_SERIAL_AMBA_PL011_CONSOLE=y`: PrimeCell PL011 UART driver and console enabled.
- `CONFIG_PRINTK=y`: Kernel logging enabled.

## 2. Kernel Artifact Reference
- `gate_vmlinux`:
  - `Class: ELF32`
  - `Machine: ARM`
  - `Flags: 0x5000400, Version5 EABI, hard-float ABI`
  - `Entry point address: 0xc0008024` (or `0xc0008000`)
- `gate_System.map`:
  - `start_kernel`: `0xc0800000`
  - `rest_init`: `0xc0800014`
  - All addresses strictly match `gate_vmlinux`.

## 3. Canonical QEMU Launch Command
```bash
qemu-system-arm \
  -machine virt,highmem=off,gic-version=2 \
  -cpu cortex-a7 \
  -m 512M \
  -smp 1 \
  -nographic \
  -kernel arch/arm/boot/zImage
```
- `highmem=off`: Mandatory because `CONFIG_ARM_LPAE=n`. Without `highmem=off`, QEMU places memory and MMIO devices above 4 GB, out of range of a 32-bit short-descriptor kernel.
- `gic-version=2`: Specifies ARM Generic Interrupt Controller v2.
- `cortex-a7`: Cortex-A7 ARMv7-A 32-bit CPU.
- VFS Panic: Expected because no root filesystem (`root=`) or initramfs is supplied in Module 02.
