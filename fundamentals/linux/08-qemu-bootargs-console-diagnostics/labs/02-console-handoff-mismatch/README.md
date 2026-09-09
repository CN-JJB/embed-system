# Lab 4.2 — Console Registration, Multiple Console Semantics & Handoff Mismatch

## 1. Objective

Investigate how the Linux kernel selects and registers the primary system console (`/dev/console`). Analyze the failure mode where a misconfigured console device (`console=ttyS0`) silences terminal output, and demonstrate how `earlycon` discriminates between a dead CPU and a disconnected console.

---

## 2. Theoretical Foundation

### Multiple `console=` Parameter Semantics

The kernel command line allows passing multiple `console=` arguments:
```text
console=ttyAMA0,115200 console=tty0
```
Linux handles multiple consoles as follows (`Documentation/admin-guide/serial-console.rst`):
1. **Log distribution**: Kernel `printk()` messages are broadcast to **all** registered console devices.
2. **The primary console**: The **last console listed on the command line** that successfully registers becomes `/dev/console`.
3. **File descriptor 0, 1, 2 inheritance**: When the kernel runs PID 1, it opens `/dev/console` to establish standard input, standard output, and standard error.

### Console Mismatch Failure Mode

On ARM QEMU `virt`:
- The serial UART hardware is an **ARM PrimeCell PL011** at physical address `0x09000000`.
- The corresponding Linux driver driver is `drivers/tty/serial/amba-pl011.c`, which registers device nodes named **`ttyAMA<n>`** (`ttyAMA0`).
- If a developer specifies a PC-compatible 8250/16550 serial device:
  ```text
  console=ttyS0,115200
  ```
  The kernel attempts to bind `/dev/console` to `ttyS0`. Since no 8250 hardware exists at standard PC I/O ports on QEMU `virt`, console initialization fails with:
  ```text
  Warning: unable to open an initial console.
  ```

### The Discriminating Role of `earlycon`

Compare the two observable behaviors under `console=ttyS0`:

| Bootargs | Observable Symptom | Diagnosis |
|---|---|---|
| `console=ttyS0` (no earlycon) | **Dead silence**. Zero characters emitted to the terminal from start to finish. | Indistinguishable from CPU lockup, corrupted vector table, or early decompressor hang. |
| `earlycon=pl011,0x09000000 console=ttyS0` | Early log prints cleanly up to driver init; then logs cease and `Warning: unable to open an initial console` appears. | **Proves kernel is alive** and executing; isolates the defect strictly to console handoff. |

---

## 3. Hands-On Execution

1. Boot QEMU with console mismatch and earlycon:
   ```bash
   qemu-system-arm \
       -machine virt,highmem=off,gic-version=2 \
       -cpu cortex-a7 \
       -m 512M \
       -smp 1 \
       -nographic \
       -kernel /path/to/zImage \
       -initrd /path/to/rootfs.cpio.gz \
       -append "earlycon=pl011,0x09000000 console=ttyS0,115200 rdinit=/init"
   ```
   Notice that early boot logs print, followed by:
   ```text
   Warning: unable to open an initial console.
   Run /init as init process
   ```
   After this line, no shell prompt appears on the terminal.

2. Boot QEMU without earlycon:
   ```bash
   qemu-system-arm \
       -machine virt,highmem=off,gic-version=2 \
       -cpu cortex-a7 \
       -m 512M \
       -smp 1 \
       -nographic \
       -kernel /path/to/zImage \
       -initrd /path/to/rootfs.cpio.gz \
       -append "console=ttyS0,115200 rdinit=/init"
   ```
   Observe the complete silence.

3. Restore the correct console device:
   ```bash
   -append "earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init"
   ```
   Interactive userspace shell returns.
