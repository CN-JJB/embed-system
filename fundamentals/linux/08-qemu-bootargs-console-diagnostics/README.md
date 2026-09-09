# P3-M04 — QEMU Bootargs, Console Handoff, and Boot Diagnostics

**Time Budget:** 3.5 h MUST  
**Prerequisites:** P3-M01 (Toolchain), P3-M02 (Kernel Build & Boot), P3-M03 (Rootfs / BusyBox / PID 1)  
**Target Architecture:** ARM Cortex-A7 (ARMv7-A) on QEMU `virt` machine  

---

## 1. Module Overview

When an embedded Linux kernel fails during early bring-up, the system engineer typically faces a blank screen or a silent serial terminal. Without an in-depth understanding of the console handoff mechanism and boot-time milestones, debugging degenerates into blind guessing.

This module establishes a rigorous, evidence-based diagnostic methodology for the Linux boot sequence. You will master:
1. **The QEMU vs. Kernel Command-Line Boundary**: Distinguishing emulator options (`-machine`, `-cpu`, `-m`, `-smp`) from kernel command-line arguments (`-append "..."`).
2. **The Console Handoff Lifecycle**: How early boot debug console (`earlycon=pl011,0x09000000`) bridges the visibility gap before the full TTY/serial driver (`console=ttyAMA0,115200`) initializes.
3. **Boot Milestone Sequence**: A strict chronological mental model from decompressor execution to PID 1 userland spawn.
4. **Failure Diagnosis**: Applying the systematic diagnostic loop to discriminate boot argument errors, console misrouting, and memory exhaustion.

---

## 2. Canonical Platform & Command-Line Contract

The canonical execution environment for all Phase 3 modules is:

### 2.1 QEMU Virtual Machine Options
```text
-machine virt,highmem=off,gic-version=2
-cpu cortex-a7
-m 512M
-smp 1
-nographic
```

### 2.2 Kernel Bootargs Contract
```text
earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init
```

Key argument specifications:
- `earlycon=pl011,0x09000000`: Direct memory-mapped MMIO driver for the ARM PrimeCell PL011 UART at physical base address `0x09000000`. Does not require interrupts, memory management, or driver model subsystems.
- `console=ttyAMA0,115200`: Canonical full-featured UART driver (`amba-pl011`) with interrupt handling, termios line discipline, and baud rate selection.
- `rdinit=/init`: Designates the first executable invoked from the unpacked initramfs root filesystem.

---

## 3. The 5 Boot Milestones

The Linux boot process follows a deterministic sequence of milestones. Diagnosing a failure begins by identifying the **last achieved milestone**:

```text
+-----------------------------------------------------------------------------------+
| Milestone 0: Decompressor & Early Console                                         |
| "Uncompressing Linux... done, booting the kernel."                                |
| "printk: legacy bootconsole [pl11] enabled"                                       |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| Milestone 1: CPU Architecture & Memory Initialization                             |
| "Booting Linux on physical CPU 0x0"                                               |
| "Machine model: linux,dummy-virt"                                                 |
| "Memory: ... available"                                                           |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| Milestone 2: Console Driver Registration & Handoff                                |
| "amba-pl011 9000000.pl011: ttyAMA0 at MMIO 0x09000000..."                        |
| "printk: console [ttyAMA0] enabled"                                               |
| "printk: legacy bootconsole [pl11] disabled"                                      |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| Milestone 3: Initramfs Archive Unpacking                                          |
| "Trying to unpack rootfs image as initramfs..."                                   |
| "Freeing initrd memory: ... KiB"                                                  |
+-----------------------------------------------------------------------------------+
                                         |
                                         v
+-----------------------------------------------------------------------------------+
| Milestone 4: PID 1 Launch & Userland Execution                                    |
| "Run /init as init process"                                                       |
| "Starting PID 1 Minimal Init Process"                                             |
| "/ # " (Interactive BusyBox Shell Prompt)                                         |
+-----------------------------------------------------------------------------------+
```

---

## 4. Controlled Fault Catalog

| Fault ID | Title | Symptom | Root Cause |
|---|---|---|---|
| **F04** | Bad Bootargs Root / Init | Kernel Panic: `Attempted to kill init!` or `Failed to execute ...` | Invalid `rdinit=` path or missing rootfs entry |
| **F05** | Console Mismatch / Silent Boot | Silence after decompression or silence after earlycon | Incorrect `console=` device name or baud rate |
| **F06** | Insufficient RAM | QEMU refusal (`-m 8M`), early boot hang (`mem=8M`), or OOM panic (`mem=32M`) | Physical or kernel-limited memory below runtime threshold |
| **F07–F09** | Userland Init Integration Faults | Kernel panic, execution permission denied, or `ps` failure | Missing `/init`, non-executable bit, or unmounted `/proc` |

---

## 5. Module Labs & Hands-On Exercises

- **Lab 01**: Early Console Bring-Up & Visibility (`labs/01-earlycon-boot/`)
- **Lab 02**: Console Driver Registration & Handoff Analysis (`labs/02-console-handoff-mismatch/`)
- **Lab 03**: Boot-Log Milestone Auditing (`labs/03-bootlog-milestones/`)

---

## 6. AI-Free Challenge & Module Gate

- **AI-Free Challenge**: Silent Boot Failure Isolation (`challenge/README.md`)
- **Module Gate**: Canonical Boot Configuration & Milestone Certification (`gate/README.md`)

---

## 7. Verification

Run module verification:
```bash
make check
```

Run real QEMU boot test (requires cross-compiler, Linux kernel zImage, and rootfs archive):
```bash
make real-bootargs-qemu-check
```
