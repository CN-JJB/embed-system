# P3-M02 — Linux Kernel Source Orientation, Kconfig, Build Flow & Image Artifacts

> **Phase 3 / Module 02**  
> **Target Depth:** L2 Kernel Build Architecture / L3 Linux Early Boot Flow  
> **Prerequisites:** P3-M01 (Cross-Toolchains, Target Tuples & Sysroots), P1-M03 (Makefiles & ELF Objects), P2-M01 (Bare-Metal Startup & Linker Scripts)  
> **Planned Learner Time:** **4.0 h MUST**, 1.0 h SHOULD  
> **AI Mode:** AI-Free first attempt on Challenge and Gate; official Linux documentation and pinned kernel source permitted.

---

## 1. Why Linux Kernel Build Architecture Matters

With the cross-toolchain in place, we build the core operating system: the **Linux kernel**.

Unlike a monolithic bare-metal application or MCU firmware (where all source files are compiled into one binary), the Linux kernel codebase contains over 30 million lines of code spanning dozens of CPU architectures and thousands of device drivers. No single system builds the entire tree. Instead:
1. The **Kconfig** configuration system selects which subsystems, architectures, drivers, and options are active.
2. The **Kbuild** makefile engine reads `.config` and compiles only the selected source files.
3. The build produces three fundamentally distinct artifacts:
   - `vmlinux`: The uncompressed ELF kernel executable with full debug symbols.
   - `arch/arm/boot/zImage`: The compressed, self-extracting boot image loaded by the bootloader or QEMU.
   - `System.map`: The symbol lookup table binding kernel symbol names to exact virtual memory addresses.

Furthermore, kernel execution begins long before C code or `start_kernel()` runs:
The assembly boot stub in `arch/arm/kernel/head.S` must initialize CPU registers with the MMU off, build initial Level 1 page tables in RAM, enable the MMU, switch to virtual memory execution, and only then jump into C startup.

---

## 2. Mental Model

### 2.1 The Kernel Build & Boot Continuum

```text
+-------------------------------------------------------------------------------+
| KERNEL SOURCE TREE (Linux 6.18.50 LTS)                                        |
|   arch/arm/configs/multi_v7_defconfig + Phase 3 Config Delta Fragment        |
|                                |                                              |
|                                v  make olddefconfig                           |
|                       Final Effective .config                                 |
|                                |                                              |
|                                v  make ARCH=arm CROSS_COMPILE=... zImage      |
|                       Kbuild Compilation Engine                               |
+-------------------------------------------------------------------------------+
                                 |
           +---------------------+---------------------+
           |                     |                     |
           v                     v                     v
      vmlinux         arch/arm/boot/zImage         System.map
    (Raw ELF32)    (Self-Extracting Boot Image) (Symbol Address Table)
  - Debug symbols      - Loaded by QEMU           - Debugging / Oops
  - Static analysis    - Compressed payload       - Build-specific
           |                     |
           |                     v
           |          +---------------------------------------------------------+
           |          | QEMU ARMv7-A Cortex-A7 System Execution                 |
           |          |                                                         |
           |          | 1. QEMU loads zImage to RAM (0x40008000)                |
           |          | 2. Self-extractor runs (arch/arm/boot/compressed/head.S)|
           |          | 3. Kernel Entry: stext (arch/arm/kernel/head.S)         |
           |          |    - MMU OFF, D-cache OFF, r2 = DTB pointer             |
           |          |    - __create_page_tables (build initial PGD in RAM)    |
           |          |    - processor-specific setup / MMU enable transition   |
           |          |      (__enable_mmu / __turn_mmu_on -> SCTLR, see 3.1)   |
           |          |    - __mmap_switched (switch to virtual memory 0xC0..)  |
           |          | 4. C Entry: start_kernel() (init/main.c)                |
           |          |    - setup_arch() / earlycon=pl011 / console_init()     |
           |          |    - mm_init() / trap_init() / rest_init()              |
           |          |    - kernel_init() thread spawned (PID 1)               |
           |          |    - tries to mount rootfs:                             |
           |          |      Terminates in expected VFS Panic                   |
           |          |      ("Unable to mount root fs")                        |
           |          +---------------------------------------------------------+
```

### 2.2 Canonical Source Pins & Contracts
- **Linux Kernel**: Pinned to **Linux 6.18.50 LTS** (tag `v6.18.50`, peeled commit `7cfc41f8e80f11ffa8382ed1a505154ceffb79c7`).
- **QEMU Target**: Pinned to **QEMU 11.1.1** (tag `v11.1.1`, peeled commit `c3d48b7d1e89604920e5b81b91140c2ad39a1943`).
- **Canonical Machine Contract**:
  ```bash
  qemu-system-arm \
    -machine virt,highmem=off,gic-version=2 \
    -cpu cortex-a7 \
    -m 512M \
    -smp 1 \
    -nographic \
    -kernel arch/arm/boot/zImage
  ```

> [!IMPORTANT]
> **Why `highmem=off`?**  
> On Cortex-A7 with QEMU `virt`, QEMU defaults `highmem=on`, placing PCI MMIO and high memory above 4 GB. However, our Phase 3 architecture baseline deliberately freezes `CONFIG_ARM_LPAE=n` (to teach classic 2-level 32-bit short-descriptor page tables). A non-LPAE 32-bit kernel cannot address physical memory above 4 GB. Therefore, passing `highmem=off` is mandatory to guarantee all devices and RAM are mapped within the 32-bit physical address space!

---

## 3. Minimal Theory Boundary

### 3.1 Bounded Source Reading: `arch/arm/kernel/head.S`
The kernel entry point is `stext`. The ARMv7-A startup sequence follows the canonical architecture:
```text
stext (MMU off)
→ processor/platform validation
→ __create_page_tables
→ processor-specific setup
→ __enable_mmu / __turn_mmu_on
→ __mmap_switched
→ C startup (start_kernel)
```

1. **CPU State**: Supervisor mode (`SVC`, PL1), MMU disabled, Data Cache disabled, Instruction Cache optional.
2. **Boot Data**: Register `r1` holds machine ID (legacy) or `0xFFFFFFFF` (Device Tree boot); `r2` holds the physical address of the Device Tree Blob (DTB) passed by QEMU direct boot.
3. **Processor Validation**: Reads processor ID (`mrc p15, 0, r9, c0, c0`) and validates against `proc_info_list` (`__lookup_processor_type`).
4. **`__create_page_tables`**: Populates the initial 16 KB Level-1 Page Directory (PGD) in physical RAM. It:
   - Identity-maps the physical RAM range containing the turn-on code;
   - Maps the kernel code/data into the high virtual memory region starting at `PAGE_OFFSET` (`0xC0000000`);
   - **UART MMIO Note**: Early page tables map serial debug IO **only if `CONFIG_DEBUG_LL=y`** is compiled in. Standard runtime `earlycon=pl011` does not rely on `__create_page_tables` mapping UART; `earlycon` uses early fixmap mappings established during early C architecture initialization (`setup_arch`).
5. **Processor Setup & MMU Enable Transition**: Invokes processor-specific initialization (`__v7_setup` in `arch/arm/mm/proc-v7.S`, which among other things programs the TTBCR/TTBR translation-table base), then passes through `__enable_mmu` to `__turn_mmu_on` in `arch/arm/kernel/head.S`. The transition spans several helpers:
   - `__enable_mmu` loads the domain access register (CP15 `c3`) and the translation table base register (CP15 `c2`, `TTBR0`) from values prepared by the page-table and processor-setup code, then branches to `__turn_mmu_on`;
   - `__turn_mmu_on` writes the CP15 system control register (`SCTLR`) with the MMU enable bit and issues instruction-sync barriers, then returns to `__mmap_switched` in the virtual address space.
   > Do not memorize a fixed register-by-register order from this summary. For exact register-level details, read the pinned source: `arch/arm/kernel/head.S` (`__enable_mmu`, `__turn_mmu_on`) and `arch/arm/mm/proc-v7.S` (`__v7_setup`).
6. **`__mmap_switched`**: Now running with MMU enabled in virtual memory (`0xC0000000+`):
   - Sets up initial C runtime kernel stack (`sp`);
   - Clears kernel `.bss` section;
   - Sets up architecture data structures and branches to architecture-independent C startup: `start_kernel()`!

### 3.2 Bounded Source Reading: `init/main.c`
In `start_kernel()`:
- `setup_arch(&command_line)`: Reads the early architecture parameters and early command line.
- `early_boot_irqs_disabled`: Verifies interrupt state.
- `mm_init()`: Initializes memory management and buddy allocator.
- `trap_init()`: Populates exception vectors.
- `console_init()`: Initializes registered console drivers (`ttyAMA0` for PL011). Prior to this call, serial output is only possible if `CONFIG_SERIAL_EARLYCON=y` and `earlycon=pl011,...` was passed.
- `rest_init()`: Spawns the `kernel_init` thread (which becomes PID 1) and enters the idle loop (`cpu_startup_entry()`).
- `kernel_init()`: Calls `try_to_run_init_process()` to launch `/sbin/init`. In M02, because no rootfs is supplied, it triggers the expected VFS root mount panic.

### 3.3 Configuration Baseline & Phase 3 Delta
We reject `vexpress_defconfig` (legacy hardware board) and standardize on **`multi_v7_defconfig`** (which enables `CONFIG_ARCH_VIRT=y`).
Our version-controlled Phase 3 config fragment enforces:
```text
CONFIG_ARCH_VIRT=y
CONFIG_ARM_LPAE=n
CONFIG_VMSPLIT_3G=y
CONFIG_SERIAL_AMBA_PL011=y
CONFIG_SERIAL_AMBA_PL011_CONSOLE=y
CONFIG_SERIAL_EARLYCON=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_VIRTIO_MMIO=y
CONFIG_VIRTIO_BLK=y
CONFIG_EXT4_FS=y
CONFIG_PRINTK=y
```

### 3.4 Image Artifacts: `vmlinux`, `zImage`, `System.map`
- **`vmlinux`**: ELF executable. Contains ELF sections (`.head.text`, `.text`, `.rodata`, `.data`, `.bss`) and the complete symbol table (`.symtab`, `.strtab`).
- **`arch/arm/boot/zImage`**: Compressed binary. Self-extracting stub at front (`arch/arm/boot/compressed/head.S`) decompresses piggybacked kernel code into RAM.
- **`System.map`**: A plain text file produced by `nm -n vmlinux`. Each line has the format:
  `<virtual_address> <type_letter> <symbol_name>`
  Example:
  ```text
  c0008000 T stext
  c0800000 T start_kernel
  c08006e4 t console_init
  c0800bd0 t rest_init
  ```

---

## 4. Hands-On Labs

### Lab 2.1 — Bounded Source Orientation
Location: [`labs/01-source-orientation/`](labs/01-source-orientation/)
- Trace the assembly sequence in `arch/arm/kernel/head.S`: locate `stext`, `__create_page_tables`, `__enable_mmu`, and `__mmap_switched`.
- Inspect `init/main.c`: locate `start_kernel()`, `console_init()`, and `rest_init()`.

### Lab 2.2 — Kconfig Baseline & Fragment Application
Location: [`labs/02-kconfig-kbuild/`](labs/02-kconfig-kbuild/)
- Inspect `multi_v7_defconfig` baseline.
- Apply `phase3_delta.config` and run configuration update (`olddefconfig`).
- Validate the final effective `.config` verifying `CONFIG_ARM_LPAE=n` and `CONFIG_VMSPLIT_3G=y`.

### Lab 2.3 — Kernel Image Artifact Audit
Location: [`labs/03-image-artifacts/`](labs/03-image-artifacts/)
- Inspect `vmlinux` using `readelf -h`, `readelf -S`, and `nm`.
- Contrast with `zImage` (file type, size, self-extracting nature).
- Cross-reference symbol addresses between `vmlinux` and `System.map`.

### Lab 2.4 — QEMU Direct Kernel Boot to VFS Panic
Location: [`labs/04-qemu-kernel-boot/`](labs/04-qemu-kernel-boot/)
- Construct the canonical QEMU execution command.
- Execute direct kernel boot with `-kernel arch/arm/boot/zImage`.
- Observe kernel startup messages, PL011 UART detection, memory probe, and final termination at VFS root mount panic.

---

## 5. Deliberate Seeded Fault

### Fault F03 — Stale / Mismatched `System.map`
Location: [`faults/F03-stale-system-map/`](faults/F03-stale-system-map/)
- **Symptom**: During debugging of a kernel crash or symbol lookup, the address shown in an oops trace does not match the function code in `vmlinux`, or a profiling tool produces nonsensical symbol attributions.
- **Diagnostic Loop**:
  1. Own Description: Symbol lookup table (`System.map`) does not correspond to the currently running/compiled `vmlinux` binary.
  2. Hypotheses:
     - `System.map` was generated from a previous build with different compiler flags or code changes.
     - `System.map` belongs to a different architecture or defconfig.
     - `vmlinux` was recompiled but `System.map` was not regenerated.
  3. Experiment: Compare the address of core symbols (`start_kernel`, `rest_init`) extracted from `vmlinux` using `nm -n vmlinux` against the addresses listed in `System.map`.
  4. Evidence: `System.map` lists `start_kernel` at `0xc0800000`, but `nm vmlinux` reveals `start_kernel` is located at `0xc0804100`!
  5. Root Cause: Build system artifact desynchronization; stale `System.map` left over from prior build.
  6. Fix: Re-generate `System.map` from current `vmlinux`: `$(CROSS_COMPILE)nm -n vmlinux | grep -v '\( [aNUw] \)\|\(__crc_\)' > System.map`.
  7. Regression: Run `./diagnose_f03.sh`, verify all symbol addresses match `vmlinux` with zero drift.

---

## 6. AI-Free Challenge & Module Gate

### Challenge: Effective Config & Symbol Address Audit
Location: [`challenge/`](challenge/)
Given an unfamiliar candidate `.config` and built kernel artifacts from a vendor delivery, independently audit the effective configuration against the canonical Phase 3 platform rules, report every deviation with evidence, verify the artifact/`PAGE_OFFSET` consistency, and determine whether `System.map` strictly synchronizes with `vmlinux`.

### Gate: Clean Build & Boot Contract Verification
Location: [`gate/`](gate/)
From isolated configuration and kernel artifacts, evaluate:
1. Effective configuration compliance with the full canonical Phase 3 delta (report every deviation);
2. Symbol address consistency between `vmlinux` and `System.map`;
3. Canonical QEMU command syntax verification (`-machine virt,highmem=off,gic-version=2 -cpu cortex-a7 -m 512M -smp 1 -nographic`).

Fill out [`gate/gate_manifest.template`](gate/gate_manifest.template).
