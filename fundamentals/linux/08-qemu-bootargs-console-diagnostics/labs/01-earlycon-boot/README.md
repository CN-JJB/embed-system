# Lab 4.1 — Early Console (earlycon) Architecture & Polled MMIO Writes

## 1. Objective

Understand how the Linux kernel outputs diagnostic log messages over serial UART before device drivers, interrupt controllers, and TTY line disciplines are initialized. Contrast polled MMIO early console (`earlycon`) with driver-managed interrupt console (`console=ttyAMA0,115200`).

---

## 2. Theoretical Foundation

During early boot (`stext` -> `start_kernel()`):
- Memory management is in primitive bootmem/memblock state;
- The GIC interrupt controller is not yet initialized;
- Linux device driver subsystems and device trees have not yet bound drivers to hardware;
- TTY layer buffers and line disciplines do not exist.

If an error or panic occurs during this phase, a kernel configured only with `console=ttyAMA0` will remain **completely silent**. The CPU will hang or panic with zero output on the terminal.

### The `earlycon` Mechanism

`earlycon` bypasses the entire Linux driver model:
1. It registers an ultra-minimal `struct console` using direct **polled MMIO register writes**.
2. For ARM PL011 UART (`drivers/tty/serial/amba-pl011.c`), `pl011_early_write()` spins in a tight loop checking the UART Flag Register (`UARTFR`, offset `0x18`) until the Transmit FIFO is not full, then writes character bytes directly to the Data Register (`UARTDR`, offset `0x00`).
3. It requires no interrupts, no spinlocks, and no heap allocation.
4. Parameter syntax:
   ```text
   earlycon=pl011,0x09000000
   ```
   - `pl011`: Driver name identifier.
   - `0x09000000`: Physical MMIO base address of the PL011 UART on QEMU `virt`.

### The Console Handoff Sequence

1. `start_kernel()` initializes architecture and early consoles.
2. `printk: legacy bootconsole [pl11] enabled` appears at `[ 0.000000]`.
3. Later in boot, `console_init()` runs:
   - The real PL011 driver registers `ttyAMA0` with GIC IRQ 28.
   - `printk: console [ttyAMA0] enabled` appears.
4. The kernel automatically unregisters the early bootconsole:
   - `printk: legacy bootconsole [pl11] disabled`.
5. From this point forward, console I/O is interrupt-driven and managed by the TTY line discipline.

---

## 3. Hands-On Execution

1. Launch QEMU with `earlycon` enabled:
   ```bash
   qemu-system-arm \
       -machine virt,highmem=off,gic-version=2 \
       -cpu cortex-a7 \
       -m 512M \
       -smp 1 \
       -nographic \
       -kernel /path/to/zImage \
       -initrd /path/to/rootfs.cpio.gz \
       -append "earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init"
   ```

2. Observe the very first line of serial output:
   ```text
   [    0.000000] Booting Linux on physical CPU 0x0
   [    0.000000] Linux version 6.18.50 ...
   ...
   [    0.000000] earlycon: pl11 at MMIO 0x09000000 (options '')
   [    0.000000] printk: legacy bootconsole [pl11] enabled
   ```

3. Locate the handover point:
   ```text
   [    0.140569] printk: console [ttyAMA0] enabled
   [    0.141313] printk: legacy bootconsole [pl11] disabled
   ```

---

## 4. Observable Evidence

Capture the terminal excerpt showing:
1. `earlycon: pl11 at MMIO 0x09000000`
2. `printk: legacy bootconsole [pl11] enabled`
3. `printk: console [ttyAMA0] enabled`
4. `printk: legacy bootconsole [pl11] disabled`
