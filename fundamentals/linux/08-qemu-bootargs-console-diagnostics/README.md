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
| Milestone 4: PID 1 Launch & Real BusyBox Userland Execution                 |
| "Run /init as init process"                                                 |
| "=== REAL-BUSYBOX-INIT-START ===" / "=== REAL-BUSYBOX-INIT-READY ==="       |
| "BusyBox v1.36.1 ..." (real multi-call identity)                            |
| "PID   USER     TIME  COMMAND" (real 'ps' header)                           |
| "~ # " (real BusyBox ash prompt)                                            |
+-----------------------------------------------------------------------------------+
```

---

## 4. Controlled Fault Catalog

| Fault ID | Title | Symptom | Root Cause |
|---|---|---|---|
| **F04** | Bad Bootargs Root / Init | `check access for rdinit=… failed` → VFS panic `Unable to mount root fs on unknown-block(0,0)` | Nonexistent `rdinit=` path reroutes to block-root mount |
| **F05** | Console Mismatch / Silent Boot | Silence; with earlycon: `Warning: unable to open an initial console` then secondary shell-exit panic | `console=ttyS0` instead of `ttyAMA0` (nonexistent 8250 port) |
| **F06** | Insufficient RAM | PRIMARY `mem=32M` OOM deadlock panic; `mem=8M` early timeout-hang; `-m 8M` QEMU refusal | Memory restriction below working set |
| **F07–F09** | Userland Init Integration Faults | `Failed to execute …` across fallbacks → `No working init found`; or header-only empty `ps` | Unusable init + no fallbacks; missing `+x`; unmounted `/proc` |

---

## 5. Module Labs & Hands-On Exercises

- **Lab 01**: Early Console Bring-Up & Visibility (`labs/01-earlycon-boot/`)
- **Lab 02**: Console Driver Registration & Handoff Analysis (`labs/02-console-handoff-mismatch/`)
- **Lab 03**: Boot-Log Milestone Auditing (`labs/03-bootlog-milestones/`)

---

## 6. AI-Free Challenge & Module Gate

- **AI-Free Challenge**: Silent Boot Failure Isolation (`challenge/README.md`)
- **Module Gate**: Canonical Boot Configuration & Milestone Certification (`gate/README.md`)

Both assessments submit a **data-only candidate launch manifest** (`KEY=value`, exactly one definition per key). One trusted runner (`scripts/parse_candidate_manifest.py` + `scripts/run_candidate_manifest.sh`) parses it, validates it, builds the real `qemu-system-arm` argv from those values, records the normalized argv as provenance, and executes exactly that configuration. Declarations, execution and grading therefore share a single source of truth: a correct-looking declaration that is not executed cannot pass, and a machine/CPU/RAM/SMP override that contradicts the declaration is rejected.

---

## 7. Verification

Run module verification (learner-safe: static teaching checks + assessment provisioning):

```bash
make check
```

Run the real QEMU boot test (requires the pinned Linux zImage and the REAL BusyBox initramfs; binds runtime evidence to the actual execution):

```bash
make real-bootargs-qemu-check
```

Boot an arbitrary candidate manifest with full executed-argv runtime binding:

```bash
TIMEOUT_SEC=60 bash scripts/run_candidate_manifest.sh \
    gate/build/candidate_boot_manifest.conf /tmp/candidate_boot.log /tmp/candidate_boot.argv
bash scripts/verify_candidate_runtime.sh /tmp/candidate_boot.argv /tmp/candidate_boot.log \
    gate/build/candidate_boot_manifest.conf
```

> `scripts/audit_boot_milestones.sh` is the STATIC teaching-fixture auditor (ordered strings; a forged log passes it by design). Runtime certification uses `scripts/verify_runtime_boot.sh` (canonical-config runtime evidence) and `scripts/verify_candidate_runtime.sh` (candidate-argv-bound runtime evidence), both of which reject forged/concatenated logs.
