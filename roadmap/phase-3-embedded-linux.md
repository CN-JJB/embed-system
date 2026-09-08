# Phase 3 — Embedded Linux Boot-Chain & Bring-Up

> Status: **Execution blueprint — Leader review required**  
> Recommended duration: **4 weeks** (3-week Fast Track / 5-week remediation variants)  
> Core modules + project: **~29.0 h MUST**  
> Final Gate: **~3.0 h MUST**  
> Total mandatory planned load: **~32.0 h MUST** (strictly bounded within the canonical ~31–33 h envelope; target ~32 h)  
> Weekly planned load: **~8.0 h average**, preserving meaningful unscheduled buffer for kernel builds, rootfs debugging, and QEMU experimentation  
> Full research/evidence: `research/phase-3/2026-09-08-embedded-linux-curriculum-design.md`

---

## Exit capability

Phase 3 is complete when the learner can independently:

- explain the complete Embedded Linux boot sequence on the canonical ARMv7-A virtual platform: `Host Cross-Toolchain -> QEMU Direct Kernel Boot -> Self-Extracting Decompressor -> Kernel Entry (stext, MMU off) -> __create_page_tables -> __enable_mmu -> start_kernel() -> Flattened Device Tree (DTB) -> Root Filesystem (initramfs / ext4) -> BusyBox Multi-Call Binary -> PID 1 (/sbin/init) -> Userspace Shell`;
- configure, cross-compile, and inspect target software artifacts using canonical target tuples (`arm-none-linux-gnueabihf-` canonical package / `arm-linux-gnueabihf-` distro host toolchain), cross-compilers, target sysroots, dynamic linkers (`/lib/ld-linux-armhf.so.3`), and shared libraries; distinguish target ELF binaries from host binaries and diagnose architecture mismatches (`Exec format error`) and missing dynamic loaders;
- configure the Linux kernel using `Kconfig` on a generic virtual platform baseline (`multi_v7_defconfig` with `CONFIG_ARCH_VIRT=y`) and a bounded Phase 3 configuration delta (`CONFIG_ARM_LPAE=n`, `CONFIG_VMSPLIT_3G=y`, `CONFIG_SERIAL_AMBA_PL011=y`, `CONFIG_DEVTMPFS=y`); cross-compile the kernel into uncompressed ELF (`vmlinux`), compressed boot image (`zImage`), and symbol map (`System.map`); explain the role of Kbuild and compile flags (`ARCH=arm CROSS_COMPILE=...`);
- configure kernel command-line boot arguments (`bootargs`), select and diagnose early console (`earlycon=pl011,0x09000000`) versus normal serial console (`console=ttyAMA0,115200`), interpret kernel boot logs (`dmesg`), identify kernel subsystems (DRAM detection, GICv2 interrupt controller init, timer registration, serial driver, VFS), and distinguish kernel panics from userspace init crashes;
- construct a minimal manual root filesystem from scratch without build automation: create the Filesystem Hierarchy Standard (FHS) skeleton (`/bin`, `/sbin`, `/etc`, `/proc`, `/sys`, `/dev`, `/mnt`, `/root`), cross-compile a statically linked BusyBox multi-call binary, populate essential device nodes (`/dev/null`, `/dev/console`), configure and mount pseudo-filesystems (`procfs`, `sysfs`, `devtmpfs`), and implement PID 1 `/sbin/init` and `/etc/init.d/rcS` scripts;
- decompile, inspect, and modify a Device Tree Source (DTS) and compiled blob (DTB) using `dtc`; explain hardware description nodes, properties, `compatible` matching keys, `reg` base address/length pairs, `interrupts` specifiers, and `status` toggles; correlate DTS nodes with runtime sysfs nodes under `/sys/firmware/devicetree/base`;
- reproduce the minimal appliance using shallow Buildroot automation; configure target architecture (`BR2_cortex_a7=y`), cross-toolchain, BusyBox, rootfs overlay (`BR2_ROOTFS_OVERLAY`), and kernel; audit the generated build tree (`output/images/`, `output/target/`, `output/build/`); explain what Buildroot automates compared to manual rootfs construction; diagnose package provenance, configuration drift, and build stamps;
- trace the architectural execution spine connecting userspace to hardware on ARMv7-A: unprivileged User mode (PL0) versus privileged operating system modes (PL1, Supervisor `SVC`); system call entry via the trap instruction (`svc #0`); exception vector handling; memory isolation; virtual memory address translation under the frozen configuration (`CONFIG_ARM_LPAE=n`, `CONFIG_VMSPLIT_3G=y`) using two-level short-descriptor page tables (16 KB Level 1 PGD, 1 KB Level 2 PTE, 4 KB pages); Translation Table Base Registers (`TTBR0` for user space, `TTBR1` for kernel space); TLB caching and context switch invalidation; and memory attribute distinctions (Normal Memory with configurable cacheability/speculation vs Device Memory with non-cacheable access and side-effect preservation);
- debug complex Embedded Linux boot-chain faults using the disciplined hypothesis-driven framework:
  $$\text{Symptom} \longrightarrow \text{Own Description} \longrightarrow \text{3–5 Hypotheses} \longrightarrow \text{Experiment} \longrightarrow \text{Evidence} \longrightarrow \text{Narrow Scope} \longrightarrow \text{Root Cause} \longrightarrow \text{Fix} \longrightarrow \text{Regression}$$

**Mastery Target**: Embedded Linux boot chain at **L3**, QEMU bring-up and diagnostics at **L3**, rootfs/init/BusyBox at **L3**, Device Tree introductory mechanics at **L2–L3**, shallow Buildroot at **L2–L3**, Linux kernel build/navigation at **L2**, architecture spine (privilege/MMU/VM/memory attributes) at **L2–L3 selected mechanisms**, and boot-chain debugging at **L3 $\rightarrow$ L4-local** on practiced boot/init/configuration fault families.

**Explicit Boundary & Non-Goals**:
- **Not yet a Linux Driver / BSP expert**: Writing loadable kernel modules, `struct platform_driver`, `file_operations`, character devices, or subsystem drivers (IIO, hwmon, GPIO, SPI, I2C) is strictly reserved for Phase 4.
- **No deep U-Boot porting**: U-Boot is understood at the boot-chain interface level; source-level U-Boot driver writing, board porting, and SPL modifications are excluded.
- **No Yocto mainline**: Production Yocto/BitBake recipe authoring is deferred; Buildroot provides the transparent shallow build model.
- **No hardware purchase required**: The curriculum is **QEMU-first**; virtual platform evidence is strictly distinguished from physical board bring-up evidence.
- **No Zynq / FPGA / PCIe / DDR bring-up**: Scope creep into hardware-software co-design or high-speed memory interfaces is excluded.

---

## Course shape

Phase 3 weaves the toolchain, kernel, userspace, and architecture into a continuous systems bring-up continuum:

```text
host cross-toolchain    <-> target ELF, tuple, sysroot, and dynamic loader
kernel source / Kbuild  <-> multi_v7_defconfig + CONFIG_ARCH_VIRT, vmlinux, zImage, System.map
kernel bootargs         <-> earlycon=pl011, console=ttyAMA0, and dmesg boot log
manual minimal rootfs   <-> BusyBox multi-call binary, FHS skeleton, and device nodes
PID 1 / init lifecycle  <-> /proc, /sys, /dev pseudo-filesystems, and zombie reaping
Device Tree first pass  <-> hardware description, dtc, reg/interrupts, and sysfs tree
shallow Buildroot       <-> automated reproducible image, rootfs overlay, and provenance
architecture spine      <-> PL0/PL1 privilege, svc syscall, short-descriptor MMU, and memory types
Appliance Project       <-> integrated reproducible boot, evidence manifest, and fault recovery
```

Debugging begins in Module 1. There is no isolated "debugging week"; every module includes controlled deliberate faults requiring the full diagnostic chain.

---

## Module sequence

| ID | Module | Target | MUST hours | SHOULD hours | Principal Gate |
|---|---|---|---:|---:|---|
| **P3-M01** | Cross-Compilation Toolchains, Target Tuples, Sysroots & Target Artifacts | L3 toolchain / L4-local artifact faults | 3.5 | 1.0 | Cross-compile static & dynamic binaries; audit sysroot dependencies; diagnose architecture & dynamic-loader mismatch |
| **P3-M02** | Linux Kernel Source Orientation, Kconfig, Build Flow & Image Artifacts | L2 kernel build / L3 boot flow | 4.0 | 1.0 | Configure `multi_v7_defconfig` with `CONFIG_ARCH_VIRT=y`, cross-compile `vmlinux` & `zImage`, inspect symbols in `System.map`, boot to VFS panic in QEMU |
| **P3-M03** | Manual Minimal Rootfs, BusyBox, Pseudo-Filesystems & PID 1 Init Lifecycle | L3 rootfs & init / L4-local init faults | 4.0 | 1.0 | Construct manual FHS rootfs; build static BusyBox; populate `/dev`; write `/sbin/init`; boot to interactive shell |
| **P3-M04** | QEMU Bring-Up, Bootargs, Console Handoff & Boot Failure Diagnostics | L3 QEMU & bootargs / L4-local boot diagnosis | 3.5 | 1.0 | Configure `bootargs`; contrast `earlycon` vs normal console; diagnose kernel panic vs init failure across seeded faults |
| **P3-M05** | Device Tree First Pass: Hardware Description, DTC & Resource Inspection | L2–L3 DT / L3 resource representation | 3.5 | 1.0 | Decompile QEMU DTB with `dtc`; modify node properties (`status`, `reg`); verify runtime tree in `/sys/firmware/devicetree/base` |
| **P3-M06** | Shallow Buildroot: Automated Pipeline, Rootfs Overlay & Provenance Auditing | L2–L3 Buildroot / L3 reproducibility | 3.5 | 1.0 | Reproduce appliance via Buildroot for QEMU `virt`; inject rootfs overlay; audit build provenance; diagnose build stamp fault |
| **P3-M07** | Architecture Spine: Privilege Levels, Syscall Traps, MMU & Address Translation | L2–L3 architecture spine / L3 VM concepts | 3.5 | 1.0 | Trace `svc` trap from userspace to kernel; inspect `/proc/<pid>/maps`; explain 2-level page tables under `CONFIG_ARM_LPAE=n`; contrast Normal vs Device MMIO |
| **P3-M08** | Reproducible QEMU Embedded Linux Appliance Integration Project | L3 integrated appliance | 3.5 | 1.0 | Build pinned reproducible appliance; generate evidence manifest; execute fault injection & recovery campaign |
| **P3-GATE**| Phase 3 Final Gate Assessment | L3 transfer / L4-local diagnostic | 3.0 | 0.0 | AI-Free 4-part transfer exam in `gates/phase-3-final/` (Toolchain, Boot Log/Bootargs, Device Tree, and Fault Isolation/Architecture) |

---

## Time Budget Sum Table

| Work Area | Modules Included | MUST Hours | SHOULD Hours | Calendar Allocation |
|---|---|---:|---:|---|
| **Toolchain & Kernel Build Foundations** | P3-M01, P3-M02 | 7.5 h | 2.0 h | Week 1 (~7.5 h MUST) |
| **Rootfs, Init & Boot Failure Diagnostics** | P3-M03, P3-M04 | 7.5 h | 2.0 h | Week 2 (~7.5 h MUST) |
| **Device Tree & Shallow Buildroot** | P3-M05, P3-M06 | 7.0 h | 2.0 h | Week 3 (~7.0 h MUST) |
| **Architecture Spine, Project & Final Gate** | P3-M07, P3-M08, P3-GATE | 10.0 h | 2.0 h | Week 4 (~10.0 h MUST) |
| **Phase 3 Total** | **All 8 Modules + Final Gate** | **32.0 h** | **8.0 h** | **4 Weeks (~8.0 h/week MUST average)** |

> [!NOTE]
> The planned MUST total of **32.0 h** strictly fulfills the ~31–33 h constraint mandated by Issue #27 and the canonical Phase 0 curriculum blueprint (2026-12 monthly plan: 32 h). Unscheduled weekly buffer (~5.0–6.0 h/week) protects the learner against long compilation times, host toolchain setup issues, and complex rootfs debugging.

---

## Mandatory source policy

All curriculum content, source-reading tasks, and lab exercises must derive from authoritative upstream sources and primary specifications. Every canonical component is pinned to exactly one version without alternatives:

- **Linux Kernel Source Tree** (Upstream git: `git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git`, Canonical Baseline: **Linux 6.18.50 LTS**, tag `v6.18.50`, commit `6be83efaa5dc4cb733737fafe94685ffcb79339e`, released 2026-09-07, EOL projected Dec 2028; GPL-2.0-only):
  - Canonical config baseline: `arch/arm/configs/multi_v7_defconfig` (enabling `CONFIG_ARCH_VIRT=y`) combined with a bounded Phase 3 configuration fragment (`CONFIG_ARM_LPAE=n`, `CONFIG_VMSPLIT_3G=y`, `CONFIG_SERIAL_AMBA_PL011=y`, `CONFIG_DEVTMPFS=y`, `CONFIG_DEVTMPFS_MOUNT=y`, `CONFIG_VIRTIO_MMIO=y`, `CONFIG_VIRTIO_BLK=y`, `CONFIG_EXT4_FS=y`);
  - Boot assembly: `arch/arm/kernel/head.S` (`stext`, `__create_page_tables`, `__enable_mmu`, `__mmap_switched`);
  - Boot initialization entry points: `init/main.c` (`start_kernel()`, `console_init()`, `rest_init()`, `kernel_init()`, `try_to_run_init_process()`);
  - Command-line documentation: `Documentation/admin-guide/kernel-parameters.rst`;
  - Device Tree usage documentation: `Documentation/devicetree/usage-model.rst`;
  - Ramfs/initramfs documentation: `Documentation/filesystems/ramfs-rootfs-initramfs.rst`.
- **QEMU System Emulator** (Upstream git: `https://gitlab.com/qemu-project/qemu.git`, Canonical Baseline: **QEMU 11.1.1**, tag `v11.1.1`, commit `2443d3b769ea84c4f0ff8c3c2e17ea44f51e0e89`, released 2026-08-26; GPL-2.0):
  - Canonical launch contract: `qemu-system-arm -M virt -cpu cortex-a7 -m 512M -smp 1 -nographic`;
  - CPU model: Explicit `cortex-a7` (32-bit ARMv7-A); without `-cpu cortex-a7`, QEMU `virt` defaults to `cortex-a15`;
  - Interrupt controller contract: ARM Generic Interrupt Controller v2 (GICv2 at `0x08000000`);
  - Hardware model reference: PL011 UART (`0x09000000`, IRQ 1), DRAM base (`0x40000000`), virtio-mmio bus (`0x0a000000`);
  - Official documentation: `docs/system/arm/virt.rst`.
- **BusyBox Multi-Call Binary** (Upstream git: `https://git.busybox.net/busybox/`, Canonical Baseline: **BusyBox 1.36.1**, tag `1_36_1`, commit `4d4ff7db5a28cb20d36c39fbbd79dcf7a527c8a6`, released 2023-05-19; GPL-2.0-only):
  - Multi-call dispatcher: `applets/applets.c` and `libbb/appletlib.c`;
  - Init implementation: `init/init.c` (signal handling, `/etc/inittab` parsing, respawn/sysinit actions, console redirection).
- **Buildroot Automated Build System** (Upstream git: `https://gitlab.com/buildroot.org/buildroot.git`, Canonical Baseline: **Buildroot 2026.05.2**, tag `2026.05.2`, commit `3a1f8e6c4e09b24b89812df93f6c3821045b85a3`, released 2026-07-10, stable bugfix release [non-LTS; Buildroot LTS releases occur only on odd-numbered years: 2025.02, 2027.02]; GPL-2.0-or-later):
  - Target configuration: Generic ARM Cortex-A7 (`BR2_arm=y`, `BR2_cortex_a7=y`) targeting QEMU `virt`;
  - Official manual: `docs/manual/manual.html`;
  - Target skeleton: `system/skeleton/`;
  - Package infrastructure reference: `package/busybox/busybox.mk`.
- **Device Tree Compiler (DTC)** (Upstream git: `https://git.kernel.org/pub/scm/utils/dtc/dtc.git`, Canonical Baseline: **DTC v1.7.0**, tag `v1.7.0`, commit `03961727c62d08a594ae8cb786db900d72049d5c`, released 2023-03-01; GPL-2.0-or-later / BSD-2-Clause):
  - Specification: *Devicetree Specification Release v0.4* (tag `v0.4`, released 2021-12-08, CC-BY-4.0).
- **Cross-Toolchain Baseline**:
  - Canonical Baseline: **Arm GNU Toolchain 13.3.rel1** (`arm-none-linux-gnueabihf`), GCC 13.3.1 20240614, Binutils 2.42, Glibc 2.39, official target triple `arm-none-linux-gnueabihf-`, official sysroot `arm-none-linux-gnueabihf/libc/`; GPL-3.0-with-GCC-exception / LGPL-2.1;
  - Actual Host Toolchain (distro authoring environment): Ubuntu 24.04 LTS package `gcc-arm-linux-gnueabihf` (GCC 13.3.0, target prefix `arm-linux-gnueabihf-`, sysroot `/usr/arm-linux-gnueabihf/`). Canonical and actual host environments are explicitly separated.
- **Architecture Reference Documentation**:
  - *ARM Architecture Reference Manual Armv7-A and Armv7-R edition* (ARM DDI 0406C.d) — Primary authority for ARMv7-A execution modes (PL0 User, PL1 Supervisor/System), CP15 system control registers, VMSA short-descriptor page tables, memory types (Normal vs Device), and barriers (`DMB`, `DSB`, `ISB`);
  - *Cortex-A Series Programmer's Guide for ARMv7-A* (ARM DEN 0013D) — MMU translation walkthrough, cache organization, and boot flow.
- **Operating Systems Literature**:
  - Remzi H. Arpaci-Dusseau and Andrea C. Arpaci-Dusseau, *Operating Systems: Three Easy Pieces* (OSTEP v1.10) — Chapters 6 (Direct Execution), 18 (Paging), 19 (TLBs), 20 (Smaller Tables);
  - Michael Kerrisk, *The Linux Programming Interface* (TLPI) — Chapters 6 (Processes & Memory Allocation), 49 (Memory Mapping).

---

## Required source-reading objects

To prevent aimless browsing of large codebases, learners inspect only targeted, pedagogically critical excerpts:

1. **`linux/arch/arm/kernel/head.S` — Early Assembly Boot & Page Table Creation**:
   - Trace entry at `stext`: verify that the kernel is entered with MMU off, D-cache off, and `r2` pointing to the DTB.
   - Inspect `__create_page_tables`: trace how the initial Level 1 translation table (PGD) is populated in physical RAM before the MMU is turned on.
   - Trace `__enable_mmu`: observe the programming of CP15 `TTBR0`, Domain Access Control Register (`DACR`), and the enablement of the MMU bit in CP15 `SCTLR`.
   - Trace `__mmap_switched`: observe the transition to virtual memory execution, setting up the C stack and branching to `start_kernel()`.
2. **`linux/init/main.c` — The Kernel Initialization & Init Handshake Sequence**:
   - `start_kernel()`: Locate `setup_arch()`, `trap_init()`, `mm_init()`, `early_boot_irqs_disabled`, and `console_init()`. Explain why printk before `console_init()` requires `earlycon`.
   - `rest_init()` & `kernel_init()`: Locate the transition from kernel thread to userspace process.
   - `try_to_run_init_process()`: Inspect the exact search order for PID 1 candidates (`execute_command`, `/sbin/init`, `/etc/init`, `/bin/init`, `/bin/sh`). Explain why a missing executable bit returns `-EACCES` (-13) and a missing dynamic linker returns `-ENOENT` (-2).
3. **`busybox/init/init.c` — PID 1 Process Responsibilities**:
   - `init_main()`: Signal handling setup (catching `SIGTERM`, `SIGHUP`, `SIGINT`, ignoring `SIGPIPE`), environment setup, console initialization.
   - `parse_inittab()`: Parsing actions (`sysinit`, `wait`, `once`, `respawn`, `askfirst`, `shutdown`, `restart`).
   - `run_actions()` & `check_delayed_sigs()`: Reaping zombie processes (`waitpid(-1, &status, WNOHANG)`) and preventing orphan buildup.
4. **`linux/arch/arm/boot/dts/` — Device Tree Hardware Abstraction**:
   - Inspect the decompiled QEMU `virt.dts`.
   - Identify root nodes (`/`), `cpus`, `memory@40000000`, `intc@8000000` (GICv2), and `pl011@9000000` (UART).
   - Trace how the `reg = <0x09000000 0x1000>` and `interrupts = <0 1 4>` properties convey MMIO and IRQ parameters without hardcoding them in C driver source.
5. **`buildroot/package/busybox/busybox.mk` — Automated Build Pipeline**:
   - Trace how Buildroot sets `BUSYBOX_KCONFIG_FILE`, injects configuration overrides via `BUSYBOX_KCONFIG_FIXUPS`, invokes `$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)`, and installs the binaries into `$(TARGET_DIR)`.

---

## Fault recurrence contract

The curriculum organizes recurring Embedded Linux bring-up and configuration failure modes into **competency families**. Module challenges teach diagnostic discipline within each family; the Phase 3 Final Gate evaluates *unfamiliar variants* under strict AI-Free examination conditions:

| Fault Competency Family | Introduced In | Final Gate Competency Focus | Root Cause Category |
|---|---|---|---|
| Binary architecture mismatch (`Exec format error`) | P3-M01 | Gate Part A: Toolchain & artifact reasoning | Toolchain / Target Tuple |
| Dynamic loader missing (`/lib/ld-linux-armhf.so.3: not found`) | P3-M01 | Gate Part A: Sysroot & library dependencies | Runtime Linker / Sysroot |
| Stale or mismatched build artifact (`System.map` / DTB mismatch) | P3-M02 | Gate Part A: Artifact provenance & symbols | Build System / Artifact |
| Silent boot / missing early output (Console configuration mismatch) | P3-M03 / M04 | Gate Part B: Bootargs & console diagnosis | Kernel Command Line / UART |
| Rootfs mount failure / VFS panic (`Unable to mount root fs`) | P3-M03 / M04 | Gate Part B: Storage & filesystem diagnosis | Kernel Command Line / VFS |
| PID 1 execution failure (Missing executable bit / permission denied) | P3-M03 / M04 | Gate Part B: Init lifecycle & permissions | Filesystem Permissions / Exec |
| Pseudo-filesystem unmounted (`/proc` missing $\rightarrow$ `ps` fails) | P3-M03 | Gate Part B: Userspace environment setup | Init Script / Pseudo-FS |
| Device Tree node disabled (`status = "disabled"` on console UART) | P3-M05 | Gate Part C: DT resource representation | Device Tree / Node Status |
| DT resource address typo (Wrong `reg` address $\rightarrow$ MMIO fault) | P3-M05 | Gate Part C: Hardware description binding | Device Tree / Resource Mapping |
| Buildroot package configuration drift / unbuilt custom target | P3-M06 | Gate Part D: Build system reproducibility | Buildroot / Configuration Stamp |
| Userspace dereference of kernel address space (Virtual memory fault) | P3-M07 | Gate Part D: Architecture privilege & MMU | Memory Space / Privilege |
| Device MMIO attribute mismatch diagnosis (Controlled page-table fixture) | P3-M07 | Gate Part D: Memory attributes & ordering | Architecture / Memory Attributes |

A fix without **appropriate observable evidence for the fault family** (e.g. `readelf`/`file`/sysroot headers for toolchain, serial bootlog and `dmesg` for kernel boot, permissions and `/proc` mount state for rootfs, DTS/DTB decompilation and `/sys/firmware/devicetree/base` for Device Tree, configuration hashes and build logs for Buildroot, and page-table descriptors or GDB state for architecture faults) does not pass any module gate.

---

## Appliance Project milestones

The canonical integration project is the **Reproducible QEMU Embedded Linux Appliance** (P3-M08). It represents a production-grade, verifiable embedded appliance environment without application bloat:

```text
Build Inputs:
Pinned Linux Kernel (6.18.50) + Pinned BusyBox (1.36.1) + Original Init Script + Custom Diagnostic Utility
   |
   v
Cross-Compilation Pipeline (GNU Make / Buildroot Reproducible Recipe)
   |
   +---> zImage (Kernel Image)
   +---> virt.dtb (Device Tree Blob)
   +---> rootfs.cpio.gz (Minimal initramfs) / rootfs.ext4 (Persistent Drive)
   |
   v
Automated QEMU Launch Harness (run_qemu.sh)
   |
   +---> QEMU virt Machine (-cpu cortex-a7 -m 512M -smp 1)
   +---> Earlycon PL011 UART (Bootlog capture to console.log)
   |
   v
PID 1 Initialization Sequence (/sbin/init -> /etc/init.d/rcS)
   |
   +---> Mount /proc, /sys, /dev (devtmpfs)
   +---> Launch Syslog & Appliance Diagnostic Daemon (appliance_diag)
   +---> Emit System Telemetry (/var/log/appliance_status.json)
   +---> Spawn Interactive Root Shell
```

- **Milestone 0 (Reproducible Build Inputs & Workspace Harness)**: Establish a hermetic build directory with pinned source revisions, verified cross-toolchain environment variables (`ARCH=arm`, `CROSS_COMPILE=arm-linux-gnueabihf-` or `arm-none-linux-gnueabihf-`), and a top-level Makefile capable of orchestrating kernel build, BusyBox build, rootfs generation, and QEMU execution.
- **Milestone 1 (Target Kernel & Device Tree Generation)**: Cross-compile the pinned Linux 6.18.50 kernel using `multi_v7_defconfig` with the Phase 3 config fragment (`CONFIG_ARCH_VIRT=y`, `CONFIG_ARM_LPAE=n`, `CONFIG_VMSPLIT_3G=y`, devtmpfs, virtio-blk, ext4, initramfs, and PL011 console); extract and compile `virt.dtb` matching the QEMU machine configuration.
- **Milestone 2 (Minimal Rootfs & PID 1 Init Automation)**: Assemble the appliance rootfs containing static BusyBox utilities, essential directory skeleton, `/etc/inittab`, and `/etc/init.d/rcS` mounting `procfs`, `sysfs`, and `devtmpfs`. Cross-compile a C-based system diagnostic tool (`appliance_diag`) that queries kernel release (`uname()`), uptime (`/proc/uptime`), memory statistics (`/proc/meminfo`), and hardware device tree entries (`/sys/firmware/devicetree/base/model`).
- **Milestone 3 (Automated Boot & Artifact Manifest Verification)**: Create a robust `run_qemu.sh` launch script that boots the system in non-interactive headless mode with explicit `-cpu cortex-a7`, logs serial output to `artifacts/boot.log`, executes automated userspace health verification commands via QEMU guest automation, and generates an `ARTIFACT_MANIFEST.sha256` hashing all inputs and outputs.
- **Milestone 4 (Controlled Fault Injection & Diagnostic Postmortem)**: Inject two controlled boot-chain failures requiring the full diagnostic chain:
  1. *Boot Failure*: Deliberately corrupt the kernel command line (`root=/dev/null` or `init=/bin/badinit`), capture the kernel panic evidence in `boot.log`, articulate 3 hypotheses, execute discriminating experiment, identify root cause, and implement recovery;
  2. *Userspace Failure*: Deliberately omit `procfs` mounting in `/etc/init.d/rcS`, capture the resulting diagnostic failure in `appliance_diag`, isolate the missing filesystem dependency via error code inspection, and restore correct service behavior.
- **Final Project Acceptance**: Clean build from empty workspace in under 15 minutes (excluding kernel download); zero manual interactive steps required to boot; complete SHA256 manifest; verified boot log showing clean handoff to PID 1; passing automated diagnostic test suite; concise English `BUILD_RUN_DEBUG.md`.

**Explicit Non-Goals**: No network server stacks (HTTP/MQTT); no graphical display or framebuffer; no package managers (apt/opkg); no systemd or complex service supervisors; no proprietary vendor toolchains.

---

## Spaced review strategy

- **D+1:** 5–8 min closed-book architectural recall (e.g. draw the Embedded Linux boot sequence from reset to PID 1; write the minimal kernel command line for serial console on QEMU `virt`).
- **D+3:** 10–15 min changed-context transfer question (e.g. given a specific `dmesg` snippet showing `Kernel panic - not syncing: Attempted to kill init! exitcode=0x00000004`, determine whether the problem is in the kernel, linker script, or userspace binary).
- **D+7:** 20–30 min AI-Free reconstruction from a blank directory (e.g. write a complete `/etc/inittab` and `/etc/init.d/rcS` from memory; or construct a manual `qemu-system-arm -M virt -cpu cortex-a7` command line with proper kernel, dtb, initramfs, and append strings).
- **Phase End:** Complete Phase 3 Final Gate transfer assessment under isolated exam conditions.

---

## 4-week execution map

| Week | MUST Modules | SHOULD Activities | Weekly Gate / Milestones | Weekly Planned Load |
|---|---|---|---|---:|
| **Week 1** | **P3-M01** (3.5 h) + **P3-M02** (4.0 h) | Disassemble `vmlinux` startup code; inspect `__create_page_tables` in `head.S` | Cross-compile toolchain validation & first QEMU kernel boot to VFS panic | 7.5 h MUST |
| **Week 2** | **P3-M03** (4.0 h) + **P3-M04** (3.5 h) | Experiment with dynamic linking & shared library copying into rootfs | Interactive BusyBox shell boot & diagnosis of seeded boot failures | 7.5 h MUST |
| **Week 3** | **P3-M05** (3.5 h) + **P3-M06** (3.5 h) | Write custom DTS node; explore Buildroot `make graph-build` | Device Tree decompilation/modification & Buildroot automated image | 7.0 h MUST |
| **Week 4** | **P3-M07** (3.5 h) + **P3-M08** Project (3.5 h) + **P3-GATE** (3.0 h) | Trace page-fault handler in kernel source | Appliance project acceptance & Phase 3 Final Gate Pass in `gates/phase-3-final/` | 10.0 h MUST |

If personal or work schedules slip, drop SHOULD activities immediately to preserve the 32.0 h MUST envelope and protect Gate review time.

---

## AI policy progression

- **AI-Free (Strict):**
  - All Module Gates and D+7 blank-file reconstructions.
  - Initial unknown-fault diagnostic sessions (learner must articulate hypotheses and identify evidence channels independently).
  - Phase 3 Final Gate Assessment.
  - *Official Linux documentation, kernel source code, man pages, ARM architecture manuals, and QEMU documentation are fully permitted.*
- **AI-Hint (Socratic Only):**
  - Allowed during lab exploration after learner documents initial hypotheses and planned experiment.
  - Navigation of complex kernel source directories or Kconfig option dependencies.
  - Troubleshooting obscure host toolchain or QEMU terminal escape sequence issues.
- **AI-Assisted:**
  - Post-verification script optimization, Makefile cleanup, and English documentation polish after systems boot cleanly and pass validation.

> [!CAUTION]
> Copying and pasting kernel panics or boot logs directly into an AI assistant without independently executing the diagnostic loop (hypotheses, experiment, and evidence collection) is strictly prohibited.

---

## Phase 3 Final Gate overview

The Phase 3 Final Gate is an **AI-Free**, hands-on, transfer-oriented assessment package located in `gates/phase-3-final/` (estimated **3.0 h**). It evaluates whether the learner can independently reason, configure, and debug Embedded Linux boot chains across four core ability families:

- **Part A — Toolchain, Target Tuples & Binary Artifact Reasoning (20% / Floor 60%):** Given a set of binary artifacts and library files, identify target architecture, ABI (softfp vs hardfp), dynamic dependencies, and interpreter paths using `readelf` and `file`. Resolve an unfamiliar binary execution failure (`Exec format error` or missing interpreter).
- **Part B — Kernel Boot Log, Command-Line & Init Handshake Diagnosis (25% / Floor 60%):** Given a failing serial console boot log terminating in a hang or kernel panic, formulate 3–5 hypotheses, design an experiment, identify root cause from log evidence, and correct the kernel command line (`bootargs`) or init permissions to achieve a clean boot to shell.
- **Part C — Device Tree Resource Inspection & Decompilation (25% / Floor 60%):** Decompile an unfamiliar binary DTB using `dtc`; inspect peripheral nodes, register mappings, and interrupt lines; identify a deliberate resource conflict or status error; patch the DTS source and recompile to a functioning DTB verified in QEMU.
- **Part D — Boot-Chain Fault Isolation & Architecture Reasoning (30% / Floor 70%):** Given an integrated appliance image exhibiting an obscure boot-chain failure (combining rootfs mounting, pseudo-filesystem initialization, or memory address space interpretation), isolate the root cause across the HW/SW boundary, execute the full diagnostic chain including experiment, implement an evidence-backed fix, verify regression recovery, and explain the underlying architectural mechanism (privilege transition, MMU translation under `CONFIG_ARM_LPAE=n`, or device MMIO access).

**Pass Criteria:** Overall score $\ge 75\%$; Part floors: Part A $\ge 60\%$, Part B $\ge 60\%$, Part C $\ge 60\%$, Part D $\ge 70\%$. Zero unexplained kernel panics; complete diagnostic chain (Symptom $\rightarrow$ Own Description $\rightarrow$ Hypotheses $\rightarrow$ Experiment $\rightarrow$ Evidence $\rightarrow$ Narrow Scope $\rightarrow$ Root Cause $\rightarrow$ Fix $\rightarrow$ Regression) required for all fault fixes. Concrete variant seeds remain isolated in `gates/phase-3-final/reviewer/`.

---

## Leader decision points

- **Emulation Architecture Standard**: Standardize on **ARMv7-A 32-bit (`cortex-a7`) on QEMU `-M virt`**. All invocations explicitly specify `-cpu cortex-a7` to override the QEMU default (`cortex-a15`). This provides direct, seamless conceptual bridge from Phase 2 32-bit registers and pointers to 32-bit virtual memory and two-level page tables, while maintaining lightning-fast build and emulation speeds. AArch64 is treated as an explicit comparative architectural extension note.
- **Kernel Configuration Contract**: Reject `vexpress_defconfig` for QEMU `virt`. Standardize on **`multi_v7_defconfig` (which enables `CONFIG_ARCH_VIRT=y`) combined with a frozen Phase 3 config fragment** enforcing `CONFIG_ARM_LPAE=n` (freezing 2-level short-descriptor translation), `CONFIG_VMSPLIT_3G=y` (freezing 3G user / 1G kernel split with `PAGE_OFFSET=0xC0000000`), PL011 UART, GICv2, devtmpfs, virtio-blk, ext4, and initramfs.
- **Kernel Version Pinning**: Standardize on **Linux 6.18.50 LTS** (longterm release, projected EOL Dec 2028), matching the Phase 0 canonical research baseline. Avoid bleeding-edge mainline (7.x) to protect curriculum stability.
- **Rootfs Implementation Strategy**: Enforce a strict two-stage pedagogical sequence: learners MUST manually assemble a minimal rootfs with BusyBox in P3-M03/M04 *before* experiencing Buildroot automated image generation in P3-M06.
- **No Physical Board Mandate**: Strictly maintain the QEMU-first policy. No physical hardware purchase is required for Phase 3 completion. Physical board bring-up belongs to elective extension or Phase 4 hardware targets.
