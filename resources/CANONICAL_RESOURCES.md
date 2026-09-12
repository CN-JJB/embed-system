# Canonical Resources — Resource-First Registry

This registry ranks resources by **what job they do**. Inclusion does not mean “read cover to cover”. The learner should use the smallest set that answers the current question.

## Tier labels

- **PRIMARY** — authoritative truth for current behavior: specification, vendor manual, upstream documentation.
- **SOURCE** — upstream implementation worth reading.
- **COURSE** — high-quality teaching sequence/labs.
- **MODEL** — durable conceptual explanation/book.
- **LATER** — valuable, but defer until the roadmap reaches it.

---

# 1. System C / Linux userspace

## MUST

### Linux man-pages — PRIMARY
https://www.kernel.org/doc/man-pages/

Use for current Linux/POSIX userspace API contracts: files, processes, signals, pthreads, mmap, IPC, sockets, proc interfaces.

### The Linux Programming Interface (TLPI) — MODEL / REFERENCE
https://man7.org/tlpi/

Use selected chapters for file descriptors, process lifecycle, signals, pipes, threads, synchronization, mmap and IPC. Do not treat a 2010 book as the authority for newly added kernel interfaces; cross-check current man-pages.

### OSTEP — MODEL / COURSE
https://pages.cs.wisc.edu/~remzi/OSTEP/

Use selected chapters for processes, address spaces, scheduling, concurrency, locks, files and I/O. Excellent for “why”; Linux man-pages/source remain the implementation authority.

### GNU toolchain manuals — PRIMARY
- GCC: https://gcc.gnu.org/onlinedocs/
- GNU binutils: https://sourceware.org/binutils/docs/
- GDB: https://sourceware.org/gdb/current/onlinedocs/gdb.html
- GNU make: https://www.gnu.org/software/make/manual/

Use only the relevant sections for compilation/linking, ELF inspection, debugging and build behavior.

## SHOULD

### CS:APP — MODEL
Use selected machine-code, linking, exceptional control flow, virtual memory and concurrency chapters/labs. Strong conceptual bridge; verify Linux-specific details elsewhere.

### musl libc — SOURCE
https://git.musl-libc.org/cgit/musl/

Read small implementations (e.g. syscall wrappers, string/memory functions) to connect API contracts with compact production C.

---

# 2. MCU / STM32 / Cortex-M / FreeRTOS

## MUST

### STM32F103 official documentation — PRIMARY
https://www.st.com/en/microcontrollers-microprocessors/stm32f103/documentation.html

Core documents for the existing Phase 2 baseline:

- RM0008 — STM32F10x reference manual;
- PM0056 — Cortex-M3 programming manual for STM32 families;
- DS5319 — device datasheet for STM32F103 medium density;
- applicable errata sheet for the exact part.

Use the reference manual for peripheral registers/clock tree, the programming manual/Arm docs for core exceptions/NVIC, the datasheet for electrical/timing limits, and errata before blaming software.

### Arm Cortex-M architecture documentation — PRIMARY
https://developer.arm.com/documentation/

Use the architecture/manual material relevant to Cortex-M3 exception entry/return, stacking, privilege, memory ordering and barriers.

### FreeRTOS documentation — PRIMARY / COURSE
https://docs.freertos.org/

### FreeRTOS-Kernel — SOURCE
https://github.com/FreeRTOS/FreeRTOS-Kernel

Read selected paths for scheduler, queues, lists, Cortex-M port and heap implementation. Tie source reading to an experiment; do not read the kernel linearly.

### CMSIS — PRIMARY / SOURCE
https://github.com/ARM-software/CMSIS_5

Use CMSIS core headers to connect NVIC/SysTick/register abstractions to architecture and vendor definitions.

## SHOULD

Use a logic analyzer/oscilloscope whenever timing, ISR latency, jitter, DMA cadence or GPIO-visible sequencing is the actual question. Static code inspection cannot replace physical measurement.

---

# 3. Embedded Linux boot chain

## MUST

### Bootlin Embedded Linux system development — COURSE
https://bootlin.com/training/embedded-linux/

Free current slides/labs are available from Bootlin. Use this as the main teaching sequence for cross-compilation, kernel, rootfs, BusyBox, filesystems, build systems and application debugging.

Training material index:
https://bootlin.com/docs/

### Linux kernel documentation — PRIMARY
https://docs.kernel.org/

Use topic-specific docs rather than broad linear reading.

### Linux kernel source — SOURCE
https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/

For the repository's frozen Phase 3 experiments, retain the pinned stable baseline documented in the Phase 3 roadmap. For new learning, source-read the version actually being used.

### QEMU Arm `virt` documentation — PRIMARY
https://www.qemu.org/docs/master/system/arm/virt.html

Use for the generic virtual platform, CPU choice, highmem behavior, DT generation and supported hardware. QEMU `virt` is excellent for mechanism learning; it is not physical board bring-up.

### Devicetree Specification v0.4 — PRIMARY
https://www.devicetree.org/specifications/

Use for core DT semantics. Linux binding/schema conventions come from kernel documentation/source, not only the generic spec.

### Buildroot manual — PRIMARY
https://buildroot.org/downloads/manual/manual.html

Use for configuration, package model, output tree, overlays, reproducibility, rebuild semantics and external trees.

### Bootlin Buildroot training — COURSE
https://bootlin.com/training/buildroot/

Use after the manual rootfs/kernel path is understood. The Buildroot course is especially valuable because Bootlin is deeply involved upstream.

### BusyBox — SOURCE
https://git.busybox.net/busybox/

Read selected init/applet paths to understand embedded userspace behavior.

---

# 4. Linux kernel and driver development

## MUST

### Bootlin Linux kernel and driver development — COURSE
https://bootlin.com/training/kernel/

This is the preferred high-level sequence for the first serious driver phase. The materials are current, practical and designed by kernel engineers.

### Linux Kernel Labs — COURSE / LAB
https://linux-kernel-labs.github.io/

Use for guided labs on kernel modules and drivers. Treat its examples as teaching scaffolding and cross-check APIs against current kernel docs/source because training snapshots can lag mainline.

### Linux kernel driver API documentation — PRIMARY
https://docs.kernel.org/driver-api/

High-priority sections/topics:

- device/driver infrastructure: https://docs.kernel.org/driver-api/infrastructure.html
- platform devices/drivers: https://docs.kernel.org/driver-api/driver-model/platform.html
- GPIO: https://docs.kernel.org/driver-api/gpio/
- pin control: https://docs.kernel.org/driver-api/pin-control.html
- I2C: https://docs.kernel.org/i2c/
- SPI: https://docs.kernel.org/spi/
- DMAEngine: https://docs.kernel.org/driver-api/dmaengine/
- regulator: https://docs.kernel.org/power/regulator/
- clock framework: search current kernel docs/source for the subsystem used by the target SoC;
- power management: https://docs.kernel.org/power/

### Devicetree bindings — PRIMARY
https://docs.kernel.org/devicetree/bindings/writing-schema.html
https://docs.kernel.org/devicetree/bindings/writing-bindings.html

Read before inventing properties. Prefer existing subsystem conventions and real upstream bindings.

## SOURCE targets

When learning a subsystem, choose one simple upstream driver and trace:

```text
DT/firmware node
→ match
→ probe
→ devm/resource acquisition
→ register programming / subsystem registration
→ IRQ/work path
→ remove / PM path
```

Prefer small drivers over flagship SoC drivers with large vendor frameworks.

---

# 5. Bootloader / BSP / build and distribution engineering

## MUST

### U-Boot documentation — PRIMARY / SOURCE
https://docs.u-boot.org/en/latest/

Focus on:

- boot flow and environment;
- Device Tree handling;
- driver model;
- board configuration;
- image/boot commands;
- debugging and testing.

Do not start with deep SPL/DDR porting unless the target role/hardware requires it.

### Buildroot — PRIMARY / COURSE
Manual: https://buildroot.org/downloads/manual/manual.html

Bootlin training: https://bootlin.com/training/buildroot/

Use for small/medium embedded systems and for understanding the complete build pipeline with low conceptual overhead.

### Yocto Project / OpenEmbedded — PRIMARY
https://docs.yoctoproject.org/

Start with the Overview and Concepts Manual:
https://docs.yoctoproject.org/dev/overview-manual/index.html

Then use the BSP Developer's Guide, Development Tasks Manual and Linux Kernel Development Manual only when the roadmap reaches production BSP work.

### BitBake manual — PRIMARY
https://docs.yoctoproject.org/bitbake/dev/singleindex.html

Learn the task/dependency/signature/sstate model, not just recipe syntax.

### Bootlin Yocto/OpenEmbedded training — COURSE
https://bootlin.com/training/yocto/

Use after Buildroot concepts are comfortable. Do not learn Yocto before understanding what an embedded Linux build system is automating.

---

# 6. Bring-up, debugging, tracing and performance

## MUST / SHOULD as roadmap reaches Phase 6

### Bootlin debugging, tracing, profiling and performance analysis — COURSE
https://bootlin.com/training/debugging/

Covers userspace and kernel debugging, strace/ltrace, GDB, perf, ftrace, kprobes, eBPF tools, KernelShark/LTTng and crash analysis.

### Linux kernel tracing documentation — PRIMARY
https://docs.kernel.org/trace/

Use ftrace/tracepoints/kprobes before reaching for a more complex tool when the simpler observation answers the question.

### perf — PRIMARY / TOOL
Use current `perf` documentation/man pages and kernel source/tools for version-sensitive details.

### PREEMPT_RT / real-time Linux — LATER
Use current kernel documentation and maintained Bootlin real-time training when deterministic latency becomes a project requirement. Do not treat “real-time” as merely raising thread priority.

---

# 7. Optional specializations

These come **after** driver/BSP competence unless a job/project demands them earlier.

## Networking

Bootlin Embedded Linux networking:
https://bootlin.com/training/networking/

Study Linux networking architecture, PHY/switch support and network-driver debugging only when networking is a target competency.

## Graphics

Use DRM/KMS kernel docs and Bootlin graphics training when display pipelines are relevant. Avoid making graphics mandatory for a general BSP/driver track.

## Security

Use kernel security docs, vendor secure-boot documentation, U-Boot verified boot/UEFI documentation and a threat-model-first learning plan. Security is not a checklist of crypto APIs.

## Hardware-software co-design

Use SoC TRMs, bus/interconnect documentation, FPGA/RTL tooling and real measurement. Keep this as a specialization after software-side bring-up is strong unless the learner's role is explicitly FPGA/SoC co-design.

---

# 8. How to use this registry

For each roadmap unit:

1. read the **PRIMARY** material needed to know the contract;
2. use one **COURSE/MODEL** resource for explanation and sequence;
3. inspect a small **SOURCE** target;
4. build/break/trace one experiment yourself;
5. write a short engineering note answering:
   - what happened?
   - what evidence supports it?
   - what alternative hypotheses were ruled out?
   - what does the evidence *not* prove?

Do not accumulate resources without doing experiments.
