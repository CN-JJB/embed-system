# START HERE — Learner Route

This is the **learner-facing entry point** for `embed-system`.

If you are learning from this repository, do **not** begin by reading every roadmap, every resource link, or every existing solved lab. Follow the route on this page.

The repository has three kinds of material:

1. **Route documents** — tell you what to learn next.
2. **Resource index** — tells you exactly which resource to use for each knowledge point.
3. **Reference exemplars** — existing labs/projects/scripts that you may consult after attempting the work yourself.

Use them in that order.

---

## 0. The navigation rule

For every learning unit, use the same loop:

```text
1. Open the unit entry in this file
2. Open the matching row in resources/TOPIC_RESOURCE_INDEX.md
3. Read the named PRIMARY resource slice
4. Use one COURSE/MODEL resource for explanation
5. Inspect the named upstream source target, when one is listed
6. Build / break / trace the suggested experiment yourself
7. Write a short evidence note
8. Check the exit criterion
9. Continue to the next unit
```

Do not turn “read all links” into the goal.

A unit is sufficiently learned when you can:

- explain the mechanism in your own words;
- locate the authoritative source again when you forget details;
- observe the mechanism with an appropriate tool;
- transfer the reasoning to a changed case.

For debugging topics, also require that you can discriminate competing hypotheses using evidence.

---

# 1. Before Phase 1 — baseline and environment

## Step 0A — Run or inspect the Phase 0 baseline

Start here:

- [`gates/phase-0-baseline/README.md`](gates/phase-0-baseline/README.md)

Treat Phase 0 as a **diagnostic**, not as a course you must perfect before proceeding.

You need enough comfort with:

- Linux shell and file navigation;
- Git clone/status/diff/commit basics;
- compiling a small C program;
- Make basics;
- `file`, `readelf`, `nm`, `objdump`;
- GDB basics;
- capturing commands/logs in a reproducible note.

If one of these is weak, use the **P0 rows** in [`resources/TOPIC_RESOURCE_INDEX.md`](resources/TOPIC_RESOURCE_INDEX.md) for targeted remediation.

### Exit criterion

You can clone a small project, build it, inspect the executable, intentionally trigger one compile/link/runtime failure, diagnose it, and record exactly what proved the root cause.

Then go to Phase 1.

---

# 2. Phase 1 — System C + Linux userspace

Phase 1 is the software foundation for every later embedded Linux/kernel topic.

Detailed historical blueprint:

- [`roadmap/phase-1-foundations.md`](roadmap/phase-1-foundations.md)

Do the following units **in order**.

## P1.1 — C objects, lifetime, extent and process memory

Repository orientation:

- [`fundamentals/system-c/01-objects-lifetime/`](fundamentals/system-c/01-objects-lifetime/)

Resource rows:

- **P1.1** in [`resources/TOPIC_RESOURCE_INDEX.md`](resources/TOPIC_RESOURCE_INDEX.md)

Do not move on until you can distinguish storage duration, lifetime, pointer value, pointed-to object lifetime, array extent, stack/heap/static storage, and undefined out-of-bounds access.

## P1.2 — Compilation, linking, ELF and Make

Repository orientation:

- [`fundamentals/system-c/02-compile-link-elf/`](fundamentals/system-c/02-compile-link-elf/)

Resource rows:

- **P1.2**

You should be able to explain:

```text
source → preprocessing → compilation → assembly → relocatable object → link → ELF executable
```

and use `readelf`, `nm`, and `objdump` to prove what happened.

## P1.3 — Files and file descriptors

Repository orientation:

- [`fundamentals/linux/01-files-fd/`](fundamentals/linux/01-files-fd/)

Resource rows:

- **P1.3**

Focus on descriptor ownership, open-file descriptions, offsets, duplication, cleanup, partial I/O and error boundaries.

## P1.4 — Processes: fork / exec / wait

Repository orientation:

- [`fundamentals/linux/02-process-exec/`](fundamentals/linux/02-process-exec/)

Resource rows:

- **P1.4**

You should be able to predict which process owns which descriptors and why zombies/exec failures happen.

## P1.5 — Ownership, callbacks and `void *ctx`

Repository orientation:

- [`fundamentals/system-c/03-ownership-callbacks/`](fundamentals/system-c/03-ownership-callbacks/)

Resource rows:

- **P1.5**

The purpose is API/lifetime reasoning, not clever pointer syntax.

## P1.6 — Pipes, `dup2`, signals and small IPC

Repository orientation:

- [`fundamentals/linux/03-pipe-signals-ipc/`](fundamentals/linux/03-pipe-signals-ipc/)

Resource rows:

- **P1.6**

Be able to diagnose pipe EOF hangs from descriptor ownership rather than by adding sleeps.

## P1.7 — Struct layout, endian and serialization

Repository orientation:

- [`fundamentals/system-c/04-layout-bytes-serialization/`](fundamentals/system-c/04-layout-bytes-serialization/)

Resource rows:

- **P1.7**

Be able to distinguish in-memory representation from a portable wire/file format.

## P1.8 — Evidence tools: GDB, sanitizers, `strace`

Resource rows:

- **P1.8**

Use tools to answer a specific hypothesis. Do not memorize command lists.

## P1.9 — pthreads, mutexes, condition variables and races

Repository orientation:

- [`fundamentals/linux/04-pthreads-sync/`](fundamentals/linux/04-pthreads-sync/)

Resource rows:

- **P1.9**

You should be able to state the shared-state invariant protected by a lock and the predicate associated with a condition variable.

## P1.10 — Integration project

Build your own small service first:

```text
FD input → parser → bounded queue → worker → statistics/logging
```

Existing reference project:

- [`projects/linux-systems-telemetry/`](projects/linux-systems-telemetry/)

**Do not read the finished project first.** Attempt your own version, then compare architecture/debug choices.

Optional self-check after the project:

- [`gates/phase-1-final/`](gates/phase-1-final/)

The old Final Gate is a useful reference/self-test, but it is no longer a mandatory blocker for continuing.

### Phase 1 exit criterion

Given an unfamiliar small Linux/C failure, you can classify it as primarily a lifetime/ownership, ELF/link, FD, process, signal/pipe, serialization, or synchronization problem and prove the diagnosis using appropriate evidence.

Then go to Phase 2.

---

# 3. Phase 2 — Cortex-M / STM32 / FreeRTOS

Detailed historical blueprint:

- [`roadmap/phase-2-stm32-freertos.md`](roadmap/phase-2-stm32-freertos.md)

Keep one principle throughout this phase:

> A register configuration is not evidence that the hardware event actually occurred.

Use a debugger, logic analyzer, or oscilloscope when the claim is physical/timing-related.

## P2.1 — Reset, startup, linker script and vector table

Repository orientation:

- [`fundamentals/mcu/01-startup-linker-vector/`](fundamentals/mcu/01-startup-linker-vector/)

Resource rows:

- **P2.1**

Trace reset through initial MSP, `Reset_Handler`, `.data`, `.bss`, C runtime initialization and `main()`.

## P2.2 — MMIO, RCC, GPIO, timers and NVIC

Repository orientation:

- [`fundamentals/mcu/02-mmio-clock-timer-nvic/`](fundamentals/mcu/02-mmio-clock-timer-nvic/)

Resource rows:

- **P2.2**

Always move among reference manual → register value → debugger observation → physical output.

## P2.3 — ADC + DMA acquisition path

Repository orientation:

- [`fundamentals/mcu/03-adc-dma-acquisition/`](fundamentals/mcu/03-adc-dma-acquisition/)

Resource rows:

- **P2.3**

Understand trigger source, ADC clock/sample time, DMA width/count/circular mode, buffer lifetime and completion evidence.

## P2.4 — FreeRTOS scheduler and context switch

Repository orientation:

- [`fundamentals/rtos/01-freertos-scheduler-context-switch/`](fundamentals/rtos/01-freertos-scheduler-context-switch/)

Resource rows:

- **P2.4**

Trace ready/delayed lists, tick processing and PendSV register save/restore in source.

## P2.5 — Queue and ISR/task boundary

Repository orientation:

- [`fundamentals/rtos/02-freertos-queue-isr-boundary/`](fundamentals/rtos/02-freertos-queue-isr-boundary/)

Resource rows:

- **P2.5**

Understand `FromISR` APIs, interrupt-priority restrictions and when a context switch is requested.

## P2.6 — Priority inversion, stack health and watchdog

Repository orientation:

- [`fundamentals/rtos/03-freertos-priority-inversion-stack-watchdog/`](fundamentals/rtos/03-freertos-priority-inversion-stack-watchdog/)

Resource rows:

- **P2.6**

Measure the inversion case; do not accept a conceptual diagram as runtime proof.

## P2.7 — Integration project

Build your own acquisition node:

```text
hardware timer
→ ADC trigger
→ circular DMA
→ ISR/task handoff
→ processing task
→ UART telemetry
```

Existing reference project:

- [`projects/stm32-freertos-acquisition-node/`](projects/stm32-freertos-acquisition-node/)

Optional self-check:

- [`gates/phase-2-final/`](gates/phase-2-final/)

### Phase 2 exit criterion

When a sample stream is wrong, delayed or missing, you can systematically move through clock tree, peripheral configuration, DMA state, interrupt state, RTOS scheduling state and physical waveform instead of guessing.

Then go to Phase 3.

---

# 4. Phase 3 — Embedded Linux boot chain

Detailed historical blueprint:

- [`roadmap/phase-3-embedded-linux.md`](roadmap/phase-3-embedded-linux.md)

Current external teaching sequence:

- Bootlin **Embedded Linux system development** slides/labs, especially the current QEMU lab package where convenient.

Use the **P3 rows** in the topic resource index to know exactly which external section/document/source belongs to each unit.

## P3.1 — Cross toolchain, target tuple, ELF and sysroot

Repository orientation:

- [`fundamentals/linux/05-cross-toolchain-target-artifacts/`](fundamentals/linux/05-cross-toolchain-target-artifacts/)

Resource row:

- **P3.1**

## P3.2 — Kernel source, Kconfig, Kbuild and image artifacts

Repository orientation:

- [`fundamentals/linux/06-kernel-build-boot/`](fundamentals/linux/06-kernel-build-boot/)

Resource row:

- **P3.2**

## P3.3 — Minimal rootfs, BusyBox and PID 1

Repository orientation:

- [`fundamentals/linux/07-minimal-rootfs-busybox-init/`](fundamentals/linux/07-minimal-rootfs-busybox-init/)

Resource row:

- **P3.3**

## P3.4 — QEMU, bootargs, early console and boot diagnosis

Repository orientation:

- [`fundamentals/linux/08-qemu-bootargs-console-diagnostics/`](fundamentals/linux/08-qemu-bootargs-console-diagnostics/)

Resource row:

- **P3.4**

## P3.5 — Device Tree first pass

Repository orientation:

- [`fundamentals/linux/09-device-tree-first-pass/`](fundamentals/linux/09-device-tree-first-pass/)

Resource row:

- **P3.5**

## P3.6 — Buildroot

Repository orientation:

- [`fundamentals/linux/10-shallow-buildroot/`](fundamentals/linux/10-shallow-buildroot/)

Resource row:

- **P3.6**

## P3.7 — ARMv7 privilege, SVC, MMU, TLB and memory attributes

Repository orientation:

- [`fundamentals/linux/11-architecture-spine/`](fundamentals/linux/11-architecture-spine/)

Resource row:

- **P3.7**

This module contains unusually detailed source-verified reference work. Use it after you have first formed your own model from the primary architecture/kernel resources.

## P3.8 — Build your own QEMU appliance

Your deliverable should include:

- kernel;
- rootfs;
- reproducible launch command;
- small diagnostic utility;
- input/version manifest;
- one boot-chain fault postmortem;
- one userspace-environment fault postmortem.

Only after your own attempt, compare with:

- [`projects/qemu-embedded-linux-appliance/`](projects/qemu-embedded-linux-appliance/)

Resource row:

- **P3.8**

### Phase 3 exit criterion

Given a failed embedded-Linux boot, you can determine whether the primary fault lies in host/target artifacts, kernel config/build, emulated/board hardware description, kernel command line/console, rootfs/init, Device Tree, build-system propagation, or userspace/privilege/address translation.

Then go to Phase 4.

---

# 5. Phase 4 — Linux kernel drivers

Phase 4 is **resource-first**. There is intentionally no giant pre-solved driver tree.

Phase map:

- [`roadmap/phase-4-linux-drivers-bsp.md`](roadmap/phase-4-linux-drivers-bsp.md)

Follow these rows in order:

```text
P4.1 module/build/debug orientation
→ P4.2 device / driver / bus / bind / probe
→ P4.3 platform_driver + Device Tree + MMIO resources
→ P4.4 IRQ + threaded IRQ + workqueues + locking
→ P4.5 GPIO descriptor API
→ P4.6 I2C client-driver pattern + regmap orientation
→ P4.7 SPI device/driver pattern
→ P4.8 pinctrl + clock + regulator + reset dependencies
→ P4.9 DMA mapping + DMAEngine orientation
→ P4.10 runtime/system power management
→ P4.11 small driver capstone
```

For each row, use [`resources/TOPIC_RESOURCE_INDEX.md`](resources/TOPIC_RESOURCE_INDEX.md). It names the specific kernel documentation pages and representative source paths to read.

### Phase 4 exit criterion

You can trace:

```text
firmware/DT node
→ device creation
→ driver registration
→ match
→ probe
→ resource acquisition
→ subsystem-facing behavior
→ IRQ/work/data path
→ PM/remove lifecycle
```

and debug why binding/probe failed using evidence.

Then go to Phase 5.

---

# 6. Phase 5 — BSP, U-Boot, Buildroot and Yocto/OpenEmbedded

Phase map:

- [`roadmap/phase-5-bsp-build-boot.md`](roadmap/phase-5-bsp-build-boot.md)

Follow:

```text
P5.1 BSP layer mental model
→ P5.2 U-Boot standard boot / environment / FDT
→ P5.3 Buildroot project customization / packages / BR2_EXTERNAL
→ P5.4 Yocto/OE layers / recipes / tasks / signatures / sstate
→ P5.5 kernel + DT patch/config management
→ P5.6 image layout / update / recovery orientation
→ P5.7 licensing / CVE / SBOM / reproducibility
→ P5.8 reproducible board-integration capstone
```

Use the exact document headings in the **P5 rows** of the topic resource index instead of opening the Buildroot/Yocto/U-Boot documentation homepage and wandering.

### Phase 5 exit criterion

From a clean source-controlled BSP input set, you can explain which metadata/config/patch produced each boot artifact and can diagnose a stale or missing change all the way to the final image.

Then go to Phase 6.

---

# 7. Phase 6 — Bring-up, tracing, performance and real-time

Phase map:

- [`roadmap/phase-6-debug-performance.md`](roadmap/phase-6-debug-performance.md)

Follow the observation hierarchy rather than a fashionable-tool hierarchy:

```text
P6.1 reproducible symptom + logs/proc/sysfs/debugfs
→ P6.2 dynamic debug + probe/bind diagnosis
→ P6.3 tracefs / ftrace / tracepoints
→ P6.4 perf stat / record / report
→ P6.5 kprobes / eBPF / LTTng orientation
→ P6.6 panic/oops + KASAN/KCSAN/lockdep
→ P6.7 latency + PREEMPT_RT
→ P6.8 boot-time measurement/optimization
→ P6.9 memory + I/O performance
→ P6.10 evidence-backed debug/performance capstone
```

Use the **P6 rows** in the resource index for the exact tracing/debugging documentation pages.

### Phase 6 exit criterion

You can start from a real symptom, form competing hypotheses, choose the cheapest tool that distinguishes them, identify the root cause, and show before/after evidence without confusing correlation with causation.

---

# 8. Optional specialization — only after the core route or when a job requires it

Choose one or two, not all:

- networking / PHY / MDIO / Ethernet / DSA;
- DRM/KMS graphics;
- ALSA/ASoC audio;
- storage / eMMC / NAND / UBI;
- security / verified boot / TEE / update;
- PCIe;
- advanced power management;
- IOMMU/SMMU/coherency;
- FPGA/custom IP integration;
- upstream contribution/subsystem maintenance.

The master context remains:

- [`roadmap/MASTER_LEARNING_MAP.md`](roadmap/MASTER_LEARNING_MAP.md)

---

# 9. What to record while learning

For any experiment that taught you something important, keep this note:

```text
Question
Environment / exact versions
Expected mechanism
Observation
3–5 hypotheses
Experiment
Evidence
Root cause / conclusion
Regression
What this evidence does NOT prove
Next question
```

This is your real learning record.

---

# 10. If you get lost

Use this decision tree:

```text
I do not know what to learn next
→ START_HERE.md

I know the topic, but not what to read
→ resources/TOPIC_RESOURCE_INDEX.md

I need the broad competency map / dependencies
→ roadmap/MASTER_LEARNING_MAP.md

I need deep historical detail for Phase 1/2/3
→ roadmap/phase-1/2/3 documents

I want to compare against an existing implementation
→ fundamentals/ or projects/ reference assets

I need to know why a claim is true
→ PRIMARY spec/vendor/upstream docs first

I forgot an API
→ current upstream docs/man-pages/source, not an AI-generated memory answer
```

If these links still leave ambiguity about the *next action*, that is a documentation defect: fix the route rather than collecting more resources.