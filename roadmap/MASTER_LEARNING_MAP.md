# Master Learning Map — Embedded Linux / BSP / Driver Engineer

This is the current top-level learning map. It deliberately favors **authoritative resources + learner-built practice** over AI-authored completeness.

## How to use it

For each phase:

1. understand the dependency graph;
2. read only the primary material needed for the current problem;
3. use one strong course/book for teaching sequence;
4. inspect real upstream source;
5. build or debug something yourself;
6. record evidence and unanswered questions;
7. move on when you can explain the mechanism and transfer it to a changed case.

Do not wait until every adjacent topic is “finished”. Embedded systems knowledge is recursive; the roadmap controls when to go deeper.

---

# Phase 0 — Environment and engineering evidence habits

## Goal

Be able to work reproducibly on Linux, use Git, build C projects, inspect binaries, debug, capture logs and distinguish claims from evidence.

## Core topics

- Linux shell / files / permissions;
- Git basics;
- compiler/linker/debugger toolchain;
- Make;
- `file`, `readelf`, `nm`, `objdump`;
- GDB;
- `strace`;
- reproducible notes and command capture;
- evidence discipline: build vs runtime vs hardware measurement.

## Resources

- GNU manuals: GCC, binutils, GDB, make;
- Linux man-pages;
- existing Phase 0 baseline assets.

## Suggested practice

Compile one tiny multi-file C program in several modes, inspect every artifact, intentionally break linking, debug a crash, capture the root cause and regression.

---

# Phase 1 — System C + Linux userspace foundations

Detailed historical roadmap: [`phase-1-foundations.md`](phase-1-foundations.md)

## Goal

Become comfortable with C as a systems language and with Linux process/file/concurrency primitives before touching kernel drivers.

## Knowledge spine

```text
objects / lifetime / ownership
→ compile + link + ELF
→ file descriptors
→ process / fork / exec / wait
→ signals + pipes + IPC
→ serialization / binary layout
→ threads + mutex/condition variables
→ debugging with GDB/sanitizers/strace
```

## MUST concepts

- object lifetime, storage duration, pointer/array extent;
- ownership and cleanup;
- integer representation/UB at practical depth;
- translation units, static/external linkage;
- ELF sections/symbols/relocations;
- file descriptor lifecycle;
- `fork`/`exec`/`waitpid`;
- pipes, `dup2`, signals;
- struct layout, alignment, endian conversion;
- pthread lifecycle and synchronization;
- race/deadlock basics;
- hypothesis-driven debugging.

## Primary resources

- Linux man-pages;
- TLPI selected chapters;
- OSTEP selected process/address-space/concurrency chapters;
- GNU toolchain manuals;
- CS:APP selected linking/machine/VM material.

See [`../resources/CANONICAL_RESOURCES.md`](../resources/CANONICAL_RESOURCES.md).

## Suggested learner-built project

A small multi-file telemetry/log processing service:

```text
FD input → parser → bounded queue → worker → statistics/logging
```

Requirements should naturally force ownership, binary format, threads, shutdown and debugging. Keep networking optional.

## Self-check

You should be able to explain why a bug is an ownership/FD/process/synchronization problem using evidence, not only fix it by trial and error.

---

# Phase 2 — MCU + Cortex-M + STM32 + FreeRTOS

Detailed historical roadmap: [`phase-2-stm32-freertos.md`](phase-2-stm32-freertos.md)

## Goal

Understand what happens below Linux abstractions: reset, linker/startup, interrupts, MMIO, clocks, timers, ADC/DMA and RTOS context switching.

## Knowledge spine

```text
reset / vector table / startup
→ linker script / .data / .bss
→ MMIO / RCC / GPIO / timer
→ NVIC / exception entry
→ ADC / DMA
→ FreeRTOS task lists / tick / PendSV
→ ISR-to-task synchronization
→ priority inversion / stack / watchdog
```

## Primary resources

- STM32F103 RM0008 + datasheet + errata;
- PM0056 / Arm Cortex-M architecture docs;
- CMSIS headers;
- FreeRTOS docs and FreeRTOS-Kernel source.

## Suggested learner-built project

A small acquisition node:

```text
hardware timer trigger
→ ADC
→ circular DMA buffer
→ ISR/task handoff
→ processing task
→ UART telemetry
```

Use a scope/logic analyzer for timing claims. Do not replace measurement with source inspection.

## Self-check

You should be able to move between:

- datasheet/reference manual;
- register state;
- interrupt context;
- RTOS task state;
- physical waveform.

---

# Phase 3 — Embedded Linux boot chain

Detailed historical roadmap: [`phase-3-embedded-linux.md`](phase-3-embedded-linux.md)

Existing modules P3-M01–M08 are retained as reference material.

## Goal

Understand the whole path from host cross-toolchain to a running ARM Linux userspace, and be able to diagnose failures across artifact/boot/rootfs/DT layers.

## Knowledge spine

```text
cross toolchain / target ELF
→ Linux Kconfig + build artifacts
→ QEMU / kernel boot
→ bootargs / early console / normal console
→ initramfs / rootfs / BusyBox / PID 1
→ Device Tree
→ Buildroot
→ userspace ↔ SVC ↔ kernel privilege
→ VA/MMU/TLB/memory attributes
```

## Primary teaching sequence

Use Bootlin Embedded Linux training as the main external sequence, while cross-checking details with:

- Linux kernel docs/source;
- QEMU Arm `virt` docs;
- Devicetree specification;
- Buildroot manual;
- BusyBox source.

## Suggested learner-built project

Build a small reproducible QEMU appliance yourself. Do not start by copying the repository's final answer. Aim to produce:

- a kernel;
- a root filesystem;
- a reproducible launch command;
- a small diagnostic utility;
- one manifest recording inputs;
- two deliberately introduced boot/userspace faults and short postmortems.

Existing repository M07/M08 material can be consulted later as a reference or comparison.

## Completion criterion

You can identify whether a failure belongs primarily to:

- host/target artifact mismatch;
- kernel configuration/build;
- QEMU hardware contract;
- command line / console;
- rootfs/init;
- Device Tree;
- build-system propagation;
- userspace/privilege/address translation.

A separate mandatory AI-authored Phase 3 Final Gate is no longer required.

---

# Phase 4 — Linux kernel driver model and subsystem drivers

Detailed resource map: [`phase-4-linux-drivers-bsp.md`](phase-4-linux-drivers-bsp.md)

## Goal

Become able to read, modify and write small Linux drivers using the kernel's device model rather than treating a driver as “module init + register poking”.

## Knowledge spine

```text
module/build/debug basics
→ device / driver / bus / binding
→ Device Tree match
→ platform_driver + probe/remove
→ devm resources / MMIO / IRQ
→ concurrency and deferred work
→ sysfs/debugfs only where appropriate
→ GPIO / I2C / SPI consumer drivers
→ DMA / clock / regulator / pinctrl orientation
→ power management
→ upstream-style binding and review habits
```

## First project direction

Prefer a QEMU-supported or simple physical device where evidence is easy to collect. Write one small driver end-to-end and then port the same reasoning to I2C or SPI.

Do not begin with a large vendor BSP driver.

---

# Phase 5 — BSP / bootloader / build-system / board integration

Detailed resource map: [`phase-5-bsp-build-boot.md`](phase-5-bsp-build-boot.md)

## Goal

Understand a BSP as an integration product across firmware, bootloader, DT, kernel, rootfs, build system and board configuration.

## Knowledge spine

```text
boot ROM / boot media orientation
→ U-Boot boot flow + environment + DT
→ kernel / DT / rootfs integration
→ Buildroot board/package customization
→ Yocto/OpenEmbedded layer/recipe/task model
→ kernel patches/config fragments
→ machine/BSP metadata
→ image/update strategy
→ reproducibility/licensing/CVE awareness
```

## Project direction

Take one real board or emulator target from clean sources to a reproducible bootable image, document every external input, and make one small BSP change that crosses at least two layers (for example DT + kernel config, or U-Boot environment + rootfs image layout).

---

# Phase 6 — Bring-up / debugging / tracing / performance / real-time

Detailed resource map: [`phase-6-debug-performance.md`](phase-6-debug-performance.md)

## Goal

Move from “can build drivers/BSPs” to “can isolate difficult failures and performance/latency problems efficiently”.

## Knowledge spine

```text
boot log + dynamic debug
→ sysfs/proc/debugfs
→ ftrace / tracepoints
→ perf
→ kprobes / eBPF orientation
→ kernel crash / lockdep / sanitizers
→ latency / scheduling / IRQ analysis
→ power management interactions
→ PREEMPT_RT when required
→ boot-time / memory / I/O performance
```

## Project direction

Take one intentionally degraded system and produce an evidence-backed performance/debug report. The important artifact is the reasoning chain and measurement, not a large codebase.

---

# Optional specialization tracks

Do not make these mandatory unless they match a target role.

## Networking

- Linux network stack orientation;
- PHY / MDIO;
- Ethernet MAC driver concepts;
- switch/DSA orientation;
- packet tracing/performance;
- XDP/eBPF later.

Use Bootlin networking training and kernel networking docs.

## Graphics

- DRM/KMS mental model;
- display controller / bridge / panel;
- framebuffer vs modern DRM;
- device tree bindings;
- userspace graphics stack orientation.

## Security / update

- threat modeling;
- secure/verified boot;
- key storage;
- update/rollback model;
- image signing;
- attack surface reduction;
- SBOM/CVE workflow.

## Hardware-software co-design

- bus/interconnect reasoning;
- memory maps;
- DMA/coherency;
- FPGA/SoC integration;
- custom IP ↔ DT ↔ driver path;
- performance counters and physical measurement.

---

# Learning method: what “done” means

Do not define completion as “read all links”.

A topic is sufficiently learned when you can usually do four things:

1. **Explain** the mechanism in your own words.
2. **Locate** the authoritative documentation/source when details are forgotten.
3. **Observe** the mechanism with an appropriate tool.
4. **Transfer** the reasoning to a changed device/configuration/failure.

For debugging topics, add a fifth:

5. **Discriminate hypotheses** using evidence rather than random changes.

## Recommended notebook format

For meaningful experiments, keep a short entry:

```text
Question
Environment / versions
Observation
Hypotheses
Experiment
Evidence
Root cause / conclusion
What this evidence does not prove
Next question
```

That notebook is more valuable than accumulating solved AI exercises.
