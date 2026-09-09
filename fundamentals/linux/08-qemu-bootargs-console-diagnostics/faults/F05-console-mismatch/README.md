# Fault F05 — Console Mismatch: Terminal Silence After Early Boot

## 1. Symptom

When launching QEMU, the terminal either remains in complete silence, or prints early boot messages and abruptly ceases output before userspace is reached:

```text
(Terminal completely silent from start to finish)
```
or with `earlycon`:
```text
[    0.000000] earlycon: pl11 at MMIO 0x09000000 (options '')
[    0.000000] printk: legacy bootconsole [pl11] enabled
...
[    1.023485] Warning: unable to open an initial console.
[    1.077365] Run /init as init process
(no further output on terminal)
```

---

## 2. Full Diagnostic Discipline Walkthrough

### Step 1: Own Description
The virtual machine launches, but the user receives zero console interaction. If `earlycon` is active, messages cease immediately after early console registration, displaying `Warning: unable to open an initial console`, indicating the kernel cannot route standard I/O to the user's terminal.

### Step 2: 3–5 Hypotheses
1. The kernel command line specifies a serial device (`console=ttyS0`) that does not correspond to the physical UART hardware on the board (`PL011`).
2. The baud rate or parity configuration is mismatched (`115200` vs `9600`).
3. QEMU was invoked without `-nographic`, routing serial output to an unattached graphical window.
4. The kernel crashed in early assembly before any printk calls could execute.

### Step 3: Discriminating Experiment
Execute a two-channel experiment:
1. **Experiment A**: Inject `earlycon=pl011,0x09000000` into `-append`. If output appears, the CPU and early kernel are alive, ruling out CPU crash.
2. **Experiment B**: Inspect the serial drivers compiled into the kernel and registered in the Device Tree:
   ```bash
   grep -E "serial|tty" /tmp/boot_earlycon.log
   ```

### Step 4: Observable Evidence
Under `earlycon`, the boot log reveals:
```text
[    0.139049] 9000000.pl011: ttyAMA0 at MMIO 0x9000000 (irq = 28, base_baud = 0) is a PL011 rev1
[    1.023485] Warning: unable to open an initial console.
```
Observation: The hardware UART is registered as **`ttyAMA0`**, but the effective command line specified `console=ttyS0`.

### Step 5: Narrow Scope
The kernel, CPU, and hardware UART are fully functional. The fault is strictly an argument mismatch between the driver device name (`ttyAMA0`) and the requested console (`ttyS0`).

### Step 6: Root Cause
Passing `console=ttyS0` on ARM QEMU `virt` targets a PC 8250/16550 serial port that does not exist on this platform. The primary console fails to bind, silencing all subsequent output.

### Step 7: Fix
Update the console argument:
```bash
-append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init"
```

### Step 8: Regression Check
Boot QEMU and verify:
1. `Warning: unable to open an initial console` disappears;
2. Interactive shell prompt (`/ # `) appears cleanly on the terminal.
