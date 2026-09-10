# Fault F05 — Console Mismatch: Terminal Silence After Early Boot

> Calibrated on real Linux 6.18.50 + real BusyBox 1.36.1 initramfs, QEMU `virt` (PL011 @ `0x09000000` → `ttyAMA0`).

## 1. Symptom

With `console=ttyS0,115200` and **no** `earlycon`, the terminal is *completely silent* — zero kernel characters from start to finish (indistinguishable from a dead CPU or decompressor hang without further probing).

With `earlycon=pl011,0x09000000` added, the same mismatch becomes diagnosable:

```text
[    1.057346] Warning: unable to open an initial console.
[    1.105610] Freeing unused kernel image (initmem) memory: 2048K
[    1.110075] Run /init as init process
[    1.183924] Kernel panic - not syncing: Attempted to kill init! exitcode=0x00000000
```

Read this trace precisely: early logs prove the kernel is alive through driver init and initramfs unpack; `Warning: unable to open an initial console.` isolates the defect to console binding (the kernel cannot open `/dev/console` on the nonexistent `ttyS0`); `/init` still runs, but its shell has no controlling terminal, exits instantly on EOF, and PID 1's exit secondarily panics with `Attempted to kill init!`. That trailing panic is a *consequence* of the silent console, not a broken init — do not chase it as an F07/F08.

---

## 2. Full Diagnostic Discipline Walkthrough

### Step 1: Own Description
Silent terminal (or early-only output ending at the console warning); kernel demonstrably alive under `earlycon`.

### Step 2: 3–5 Hypotheses
1. `console=` names a device with no hardware on this platform (`ttyS0` = PC 8250/16550; `virt` has PL011 → `ttyAMA0`).
2. Baud/parity mismatch on an otherwise correct device.
3. QEMU serial routed away from the terminal (missing `-nographic`).
4. Genuine early crash (excluded once `earlycon` produces output).

### Step 3: Discriminating Experiment
Two-channel bootargs experiment on the real rootfs:
1. **No earlycon**: `console=ttyS0,115200 rdinit=/init` → total silence.
2. **With earlycon**: `earlycon=pl011,0x09000000 console=ttyS0,115200 rdinit=/init` → early logs + `Warning: unable to open an initial console.` The kernel is alive; only the console is misrouted.

### Step 4: Observable Evidence
`9000000.pl011: ttyAMA0 at MMIO …` shows the hardware driver registering **`ttyAMA0`**, while the command line asked for `ttyS0`. The `Warning:` line is the kernel telling you the open of the initial console failed.

### Step 5: Narrow Scope
CPU, kernel, UART hardware, and rootfs are healthy. The fault is strictly the `console=` device-name mismatch.

### Step 6: Root Cause
`console=ttyS0` targets a nonexistent 8250 port on ARM `virt`; `/dev/console` cannot bind, silencing all post-earlycon output (and starving the shell of a tty).

### Step 7: Fix
```bash
-append "earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init"
```

### Step 8: Regression Check
1. `Warning: unable to open an initial console` disappears;
2. `printk: console [ttyAMA0] enabled` + `legacy bootconsole [pl11] disabled` handoff appears;
3. `REAL-BUSYBOX-INIT-READY` and a real `~ # ` shell follow.
