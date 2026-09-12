# Topic → Resource → Action Index

This file answers one question:

> **I know what topic I am studying. What exactly should I read, inspect and do next?**

It is intentionally more specific than `CANONICAL_RESOURCES.md`.

Use [`../START_HERE.md`](../START_HERE.md) for the route. Use this file for the resource slice.

## How to read each row

- **PRIMARY** = specification, vendor manual, man-page or upstream documentation that defines the contract.
- **COURSE / MODEL** = explanation and teaching sequence.
- **SOURCE** = implementation worth inspecting.
- **ACTION** = something you personally build, break, trace or measure.
- **EXIT** = sufficient evidence to continue; not “mastery forever”.

When a web document changes version, prefer searching by the **exact section title named here**, not by an old page number.

---

# Phase 0 — Environment and evidence habits

## P0.1 — Shell, files, commands, pipes and redirection

**Knowledge:** paths, permissions, stdin/stdout/stderr, exit status, pipes, redirection, environment.

**PRIMARY**

- GNU Bash manual: sections **Shell Commands**, **Redirections**, **Shell Parameters**, **Pipelines**, **Exit Status** — https://www.gnu.org/software/bash/manual/
- Linux man-pages: `man 2 open`, `read`, `write`, `close`; `man 7 environ`.

**COURSE**

- Bootlin command-line introduction linked from its Linux training prerequisites; use it only to close shell gaps, then return to the main route.

**ACTION**

Write a shell pipeline that captures stdout and stderr separately, checks an exit code, and records the exact command that failed.

**EXIT**

You can explain where every byte/output stream went and why the shell considered the command successful or failed.

## P0.2 — Git as engineering evidence

**PRIMARY / MODEL**

- Pro Git, **Chapter 2 — Git Basics**: Recording Changes, Viewing Commit History, Undoing Things, Remotes — https://git-scm.com/book/en/v2/Git-Basics-Getting-a-Git-Repository
- `git help status`, `git help diff`, `git help log`, `git help bisect` when needed.

**ACTION**

Create two commits, introduce a regression, use `git diff` and then `git bisect` on a tiny deterministic test.

**EXIT**

You can identify exactly which revision introduced a behavior change without manually comparing random copies.

## P0.3 — Compile / inspect / debug tool orientation

**PRIMARY**

- GCC manual: **Overall Options**, **Options Controlling C Dialect**, **Options to Request or Suppress Warnings**, **Instrumentation Options** — https://gcc.gnu.org/onlinedocs/
- GNU binutils manuals: `readelf`, `nm`, `objdump`, `ld` — https://sourceware.org/binutils/docs/
- GDB manual: **Breakpoints**, **Examining the Stack**, **Examining Data**, **Threads** — https://sourceware.org/gdb/current/onlinedocs/gdb.html
- GNU make manual: **An Introduction to Makefiles**, **Writing Rules**, **Variables** — https://www.gnu.org/software/make/manual/

**ACTION**

Compile one program with `-g`, inspect ELF headers/symbols/disassembly, break at a function in GDB, print a stack trace, then intentionally create one undefined-reference linker error.

**EXIT**

You can say whether a failure occurred during preprocessing, compilation, assembly, linking or runtime.

---

# Phase 1 — System C + Linux userspace

## P1.1 — C object lifetime, storage duration, extent and pointer validity

**Repository orientation**

- [`../fundamentals/system-c/01-objects-lifetime/`](../fundamentals/system-c/01-objects-lifetime/)

**PRIMARY**

- ISO C draft N1570 (used here for stable C object-model concepts): **6.2.4 Storage durations of objects**, **6.5.6 Additive operators** (pointer arithmetic), **6.7.6.2 Array declarators**, **7.22.3 Memory management functions** — https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf
- GCC current sanitizer documentation: **Instrumentation Options**, especially AddressSanitizer and UndefinedBehaviorSanitizer — https://gcc.gnu.org/onlinedocs/gcc/Instrumentation-Options.html

**MODEL**

- TLPI **Chapter 6 — Processes**, especially process memory layout; **Chapter 7 — Memory Allocation**.

**ACTION**

Create one stack lifetime bug, one heap use-after-free, and one array-extent bug. Predict first; then use ASan/UBSan and GDB to collect evidence.

**EXIT**

You can distinguish pointer value validity from the lifetime/extent of the object it refers to.

## P1.2 — Translation units, symbols, relocations, ELF and linking

**Repository orientation**

- [`../fundamentals/system-c/02-compile-link-elf/`](../fundamentals/system-c/02-compile-link-elf/)

**PRIMARY**

- GNU `ld` manual: **Overview**, **Linker Scripts**, **Basic Linker Script Concepts**, **SECTIONS** — https://sourceware.org/binutils/docs/ld.html
- GNU `readelf`, `nm`, `objdump` manuals — https://sourceware.org/binutils/docs/

**MODEL**

- CS:APP, **Chapter 7 — Linking**. Read for the stable mental model; use binutils/ELF docs for tool-version details.

**ACTION**

Build at least three translation units. Introduce one undefined reference and one multiple definition. Use `nm` to identify defined/undefined symbols, `readelf -S/-s/-r` for sections/symbols/relocations, and `objdump -dr` to correlate machine code with relocations.

**EXIT**

You can explain why the compiler accepted a source file but the linker rejected the program.

## P1.3 — File descriptors and open-file state

**Repository orientation**

- [`../fundamentals/linux/01-files-fd/`](../fundamentals/linux/01-files-fd/)

**PRIMARY**

- `man 2 open`, `read`, `write`, `close`, `lseek`, `dup`, `dup2`, `fcntl`.
- `man 7 file-descriptor-flags` / relevant current man-pages when needed.

**MODEL**

- TLPI **Chapter 4 — File I/O: The Universal I/O Model**.
- TLPI **Chapter 5 — File I/O: Further Details**, especially **Relationship Between File Descriptors and Open Files** and **Duplicating File Descriptors**.

**ACTION**

Open one file twice and duplicate one descriptor. Prove which descriptors share offsets and which do not. Inspect `/proc/<pid>/fd` while the process is alive.

**EXIT**

You can draw descriptor → open-file-description → file/inode relationships for your program.

## P1.4 — `fork`, `exec`, child state and `waitpid`

**Repository orientation**

- [`../fundamentals/linux/02-process-exec/`](../fundamentals/linux/02-process-exec/)

**PRIMARY**

- `man 2 fork`, `execve`, `waitpid`; `man 7 environ`.

**MODEL / COURSE**

- TLPI **Chapters 24–28**: Process Creation; Process Termination; Monitoring Child Processes; Program Execution; Process Creation and Program Execution in More Detail.
- OSTEP **Chapter 4 — The Abstraction: The Process**, **Chapter 5 — Interlude: Process API**, **Chapter 6 — Mechanism: Limited Direct Execution**.

**ACTION**

Build a parent that forks two children, redirects one child's output, execs another program, and reaps both. Intentionally omit `waitpid()` once and prove the zombie state with `ps` or `/proc`.

**EXIT**

You can predict what state and descriptors survive `fork()` and what `execve()` replaces.

## P1.5 — Ownership, callbacks and `void *ctx`

**Repository orientation**

- [`../fundamentals/system-c/03-ownership-callbacks/`](../fundamentals/system-c/03-ownership-callbacks/)

**PRIMARY**

- C language function-pointer and pointer-conversion rules from the C standard draft; use repository notes for the bounded teaching scope.

**SOURCE**

- musl small callback/context or syscall-wrapper code where the module points you; prefer compact production code over framework-heavy examples — https://git.musl-libc.org/cgit/musl/

**ACTION**

Design a callback API where ownership of the context object is explicit. Test normal completion and early-error cleanup.

**EXIT**

A reviewer can ask “who owns this allocation/FD/context at this line?” and you can answer for every path.

## P1.6 — Pipes, `dup2`, signals and small IPC

**Repository orientation**

- [`../fundamentals/linux/03-pipe-signals-ipc/`](../fundamentals/linux/03-pipe-signals-ipc/)

**PRIMARY**

- `man 2 pipe`, `pipe2`, `dup2`, `sigaction`; `man 7 signal`, `pipe`.

**MODEL**

- TLPI **Chapters 20–22** (Signals) and **Chapter 44 — Pipes and FIFOs**.

**ACTION**

Create a two-process pipeline. First intentionally leave an extra pipe writer open so EOF never arrives; then diagnose and fix it by descriptor ownership, not timing changes.

**EXIT**

You can explain exactly why `read()` blocks and which process must close which descriptor to produce EOF.

## P1.7 — Layout, alignment, endian and serialization

**Repository orientation**

- [`../fundamentals/system-c/04-layout-bytes-serialization/`](../fundamentals/system-c/04-layout-bytes-serialization/)

**PRIMARY**

- C standard draft **6.2.6 Representations of types**, **6.7.2.1 Structure and union specifiers**.
- `man 3 byteorder`, `htons`, `ntohl` for network-byte-order helpers.

**ACTION**

Inspect `sizeof`, `offsetof` and raw bytes for a struct; then define an explicit byte-oriented serialized format that does not depend on host padding.

**EXIT**

You can state which properties belong to the C object representation and which belong to your external data-format contract.

## P1.8 — GDB, sanitizers and `strace` as evidence tools

**PRIMARY**

- GDB manual: **Breakpoints**, **Examining the Stack**, **Threads**, **Examining Data**.
- GCC manual: **Instrumentation Options** (`-fsanitize=address`, `undefined`, optionally `thread` where supported).
- `man 1 strace`, especially syscall filtering and child following.

**ACTION**

For three bugs, deliberately choose a different first tool: memory corruption → sanitizer; bad state/control flow → GDB; wrong syscall/FD/process behavior → `strace`.

**EXIT**

You can justify why the chosen tool discriminates your hypotheses better than the alternatives.

## P1.9 — pthreads, locks, condition variables and concurrency bugs

**Repository orientation**

- [`../fundamentals/linux/04-pthreads-sync/`](../fundamentals/linux/04-pthreads-sync/)

**PRIMARY**

- `man 7 pthreads`; `man 3 pthread_create`, `pthread_join`, `pthread_mutex_lock`, `pthread_cond_wait`.

**MODEL / COURSE**

- TLPI **Chapters 29–33**.
- OSTEP **Chapter 26 — Concurrency: An Introduction**, **27 — Thread API**, **28 — Locks**, **30 — Condition Variables**, **32 — Common Concurrency Problems**.

**ACTION**

Implement a bounded producer/consumer queue. Write the protected invariant and condition predicate before coding. Introduce one race or missed wakeup and diagnose it.

**EXIT**

You can explain the invariant, the wait predicate and why the condition wait must be in a loop.

---

# Phase 2 — STM32 / Cortex-M / FreeRTOS

## P2.1 — Reset, startup, linker script and vector table

**Repository orientation**

- [`../fundamentals/mcu/01-startup-linker-vector/`](../fundamentals/mcu/01-startup-linker-vector/)

**PRIMARY**

- STM32F103 **RM0008**: memory map and Flash/SRAM organization relevant to the target — https://www.st.com/en/microcontrollers-microprocessors/stm32f103/documentation.html
- STM32 **PM0056**: Cortex-M3 programming model, exception/vector-table behavior.
- GNU `ld` manual: **Basic Linker Script Concepts**, especially VMA vs LMA, `MEMORY`, `SECTIONS`.
- CMSIS Cortex-M3 headers/startup conventions — https://github.com/ARM-software/CMSIS_5

**SOURCE**

- Existing repository startup assembly/linker material; compare it with CMSIS/vendor startup source without copying blindly.

**ACTION**

Trace initial MSP and reset vector, then single-step `.data` copy and `.bss` zeroing in GDB if hardware/debugger is available. Inspect ELF sections and linker symbols even if hardware is unavailable.

**EXIT**

You can explain where initialized data lives before reset and where it lives after startup.

## P2.2 — MMIO, RCC clock tree, GPIO/timers and NVIC

**Repository orientation**

- [`../fundamentals/mcu/02-mmio-clock-timer-nvic/`](../fundamentals/mcu/02-mmio-clock-timer-nvic/)

**PRIMARY**

- RM0008 chapters/headings: **Reset and clock control (RCC)**, **GPIO/AFIO**, **General-purpose timers**, peripheral register descriptions.
- PM0056 sections for **NVIC**, exception priority, `PRIMASK`/`BASEPRI`, SysTick.
- Cortex-M architecture documentation for exception entry/return and barriers — https://developer.arm.com/documentation/

**ACTION**

Derive a timer frequency from the clock tree on paper, configure it, then verify with a GPIO waveform. Change prescaler or period and predict the new waveform before measuring.

**EXIT**

Your measured period matches the clock-tree/timer calculation within explained measurement limits.

## P2.3 — ADC trigger + DMA circular acquisition

**Repository orientation**

- [`../fundamentals/mcu/03-adc-dma-acquisition/`](../fundamentals/mcu/03-adc-dma-acquisition/)

**PRIMARY**

- RM0008 headings **Analog-to-digital converter (ADC)** and **DMA controller**; read trigger selection, calibration, sampling time, data alignment, DMA channel mapping and circular mode.
- STM32F103 datasheet electrical-characteristics section for ADC clock/source-impedance/sample-time limits.

**ACTION**

Use timer-triggered ADC + circular DMA. Observe DMA half/full events and independently probe a GPIO timing marker. Intentionally create one data-width or trigger-source mismatch.

**EXIT**

You can separate “ADC never converted”, “DMA never requested”, “DMA wrote wrong width/count”, and “software read the buffer incorrectly”.

## P2.4 — FreeRTOS scheduler and PendSV context switch

**Repository orientation**

- [`../fundamentals/rtos/01-freertos-scheduler-context-switch/`](../fundamentals/rtos/01-freertos-scheduler-context-switch/)

**PRIMARY / SOURCE**

- FreeRTOS docs — https://docs.freertos.org/
- FreeRTOS-Kernel pinned/version-used source: `tasks.c` functions `xTaskIncrementTick()` and `vTaskSwitchContext()`; Cortex-M3 port `portable/GCC/ARM_CM3/port.c`, especially the PendSV/SVC scheduler-start path — https://github.com/FreeRTOS/FreeRTOS-Kernel

**ACTION**

Trace one task from ready → running → delayed → ready, then correlate with a PendSV context switch. Use GDB register/PSP observation if possible.

**EXIT**

You can explain which registers hardware saves on exception entry and which registers the FreeRTOS port saves/restores in software.

## P2.5 — ISR-to-task queue boundary

**Repository orientation**

- [`../fundamentals/rtos/02-freertos-queue-isr-boundary/`](../fundamentals/rtos/02-freertos-queue-isr-boundary/)

**PRIMARY / SOURCE**

- FreeRTOS queue/ISR API docs.
- FreeRTOS-Kernel `queue.c`: `xQueueGenericSendFromISR()` and related unblock behavior.
- Cortex-M port priority validation in `portable/GCC/ARM_CM3/port.c`; compare NVIC logical priority with `configMAX_SYSCALL_INTERRUPT_PRIORITY`.

**ACTION**

Send samples/events from an ISR to a task; record whether a higher-priority task was woken and when the context switch occurs. Intentionally configure an invalid ISR priority in a controlled debug build with assertions enabled.

**EXIT**

You can explain why ordinary task-context APIs are unsafe from an ISR and what `portYIELD_FROM_ISR` accomplishes.

## P2.6 — Priority inversion, stack health and memory/watchdog

**Repository orientation**

- [`../fundamentals/rtos/03-freertos-priority-inversion-stack-watchdog/`](../fundamentals/rtos/03-freertos-priority-inversion-stack-watchdog/)

**PRIMARY / SOURCE**

- FreeRTOS mutex/semaphore documentation.
- FreeRTOS-Kernel `queue.c` mutex implementation; `tasks.c` priority-inheritance/disinherit paths; `include/stack_macros.h`; `portable/MemMang/heap_4.c`.

**ACTION**

Create low/medium/high-priority tasks that demonstrate bounded priority inversion, measure it, then enable the mutex inheritance path and compare timing. Record stack high-water marks under worst-case load.

**EXIT**

You can distinguish starvation, priority inversion, deadlock and stack exhaustion from measured evidence.

---

# Phase 3 — Embedded Linux boot chain

## P3.1 — Cross toolchain, target ELF, ABI and sysroot

**Repository orientation**

- [`../fundamentals/linux/05-cross-toolchain-target-artifacts/`](../fundamentals/linux/05-cross-toolchain-target-artifacts/)

**COURSE**

- Bootlin **Embedded Linux system development**: use the current training material sections on **cross-compiling toolchains**, **cross-compiling applications/libraries**, and sysroot/toolchain use — https://bootlin.com/training/embedded-linux/

**PRIMARY**

- GCC/binutils current manuals; `readelf -h/-l/-d` documentation.

**ACTION**

Cross-compile one static and one dynamic ARM program. Prove ELF machine, ABI-related properties, `PT_INTERP`, and `DT_NEEDED`. Intentionally attempt to run a host binary as target or vice versa.

**EXIT**

You can determine from the ELF itself—not the filename—which architecture/loader/dependencies are required.

## P3.2 — Linux Kconfig/Kbuild and kernel artifacts

**Repository orientation**

- [`../fundamentals/linux/06-kernel-build-boot/`](../fundamentals/linux/06-kernel-build-boot/)

**COURSE**

- Bootlin Embedded Linux: sections on **Linux kernel configuration, cross-compilation and deployment**.

**PRIMARY**

- Kernel Kbuild docs: **Kbuild**, **Kconfig language**, **Linux Kernel Makefiles** — https://docs.kernel.org/kbuild/
- Kernel source for the version used: `arch/arm/configs/`, top-level `Makefile`, architecture boot-image Makefiles.

**ACTION**

Build `vmlinux`, `zImage` and `System.map`. Use `file`, `readelf`, `nm`/`System.map` to explain the difference between them.

**EXIT**

You can state which artifact QEMU/bootloader consumes and which artifact is most useful for symbols/debugging.

## P3.3 — Minimal rootfs, BusyBox, pseudo-filesystems and PID 1

**Repository orientation**

- [`../fundamentals/linux/07-minimal-rootfs-busybox-init/`](../fundamentals/linux/07-minimal-rootfs-busybox-init/)

**COURSE**

- Bootlin Embedded Linux: sections/labs on **root filesystem**, **BusyBox**, **device files**, **filesystems**.

**PRIMARY / SOURCE**

- Linux kernel documentation **Ramfs, rootfs and initramfs** — https://docs.kernel.org/filesystems/ramfs-rootfs-initramfs.html
- BusyBox source: `init/init.c` and applet dispatch paths — https://git.busybox.net/busybox/
- `man 5 proc`, `sysfs`/devtmpfs kernel docs when needed.

**ACTION**

Create a minimal initramfs manually, boot to PID 1, mount `/proc`, `/sys`, `/dev`, and deliberately break one init path or pseudo-filesystem mount.

**EXIT**

You can distinguish “kernel cannot mount root”, “kernel cannot execute init”, and “init ran but userspace environment is incomplete”.

## P3.4 — QEMU `virt`, bootargs, early console and boot diagnosis

**Repository orientation**

- [`../fundamentals/linux/08-qemu-bootargs-console-diagnostics/`](../fundamentals/linux/08-qemu-bootargs-console-diagnostics/)

**PRIMARY**

- QEMU Arm `virt` documentation — https://www.qemu.org/docs/master/system/arm/virt.html
- Linux **Kernel parameters** documentation; search exact parameters `earlycon`, `console`, `root`, `init`, `rdinit`, `panic` — https://docs.kernel.org/admin-guide/kernel-parameters.html

**ACTION**

Boot once with working early/normal console, then break only one console argument and separately break only root/init. Compare the logs and identify which layer failed.

**EXIT**

You no longer classify “no visible shell” as automatically a kernel failure.

## P3.5 — Device Tree semantics and runtime representation

**Repository orientation**

- [`../fundamentals/linux/09-device-tree-first-pass/`](../fundamentals/linux/09-device-tree-first-pass/)

**PRIMARY**

- Devicetree Specification v0.4: **Devicetree Basics** and **Device Node Requirements** — https://www.devicetree.org/specifications/
- Linux kernel **Devicetree Usage Model** — https://docs.kernel.org/devicetree/usage-model.html
- Linux binding-schema guidance becomes important in Phase 4: https://docs.kernel.org/devicetree/bindings/writing-schema.html

**ACTION**

Decompile a real DTB, locate one device node, decode `compatible`, `reg`, `interrupts`, `status`, then find the runtime node under `/sys/firmware/devicetree/base` where applicable.

**EXIT**

You can decode `reg` using the **direct parent's** `#address-cells` / `#size-cells` semantics and can distinguish source DTS, compiled DTB and runtime tree.

## P3.6 — Buildroot build pipeline and propagation

**Repository orientation**

- [`../fundamentals/linux/10-shallow-buildroot/`](../fundamentals/linux/10-shallow-buildroot/)

**PRIMARY**

- Buildroot manual — https://buildroot.org/downloads/manual/manual.html — use the named sections **Project-specific customization**, **Root filesystem overlays**, **Adding new packages to Buildroot**, **Rebuilding packages**, and **BR2_EXTERNAL** when each becomes relevant.

**COURSE**

- Bootlin **Embedded Linux development with Buildroot** — https://bootlin.com/training/buildroot/

**ACTION**

Create a small config/overlay/package, then deliberately edit the wrong layer (`output/build`, source, target, image) and trace why a change did or did not propagate.

**EXIT**

You can explain `output/build`, `output/target`, `output/images` and package stamp/rebuild behavior without treating Buildroot as a black box.

## P3.7 — ARMv7 privilege, SVC, address translation and memory attributes

**Repository orientation / verified source guide**

- [`../fundamentals/linux/11-architecture-spine/README.md`](../fundamentals/linux/11-architecture-spine/README.md)
- [`../fundamentals/linux/11-architecture-spine/SOURCE_LEDGER.md`](../fundamentals/linux/11-architecture-spine/SOURCE_LEDGER.md)

**PRIMARY**

- Arm Architecture Reference Manual Armv7-A/R, **DDI 0406C.d**: exception/SVC and short-descriptor VMSA sections.
- Cortex-A Series Programmer's Guide for ARMv7-A, **DEN0013D**: privilege/MMU/cache/memory-system walkthrough material.

**SOURCE — Linux version used by the module**

- `arch/arm/kernel/entry-common.S` and related entry code for SVC dispatch.
- `arch/arm/kernel/head.S` for early MMU setup.
- `arch/arm/include/asm/pgtable.h`, `pgtable-2level.h`, hardware-definition headers.
- `arch/arm/mm/proc-v7-2level.S` for the frozen non-LPAE TTBR/page-table behavior.

**MODEL**

- OSTEP **Chapters 13–20** selectively: address spaces, address translation, paging and TLBs. Use for concepts, not ARM-specific truth.

**ACTION**

Inspect `/proc/<pid>/maps`, disassemble and execute one explicit `svc #0` syscall path, cause one controlled userspace access fault, and decode one short-descriptor fixture. Keep observation and interpretation separate.

**EXIT**

You can explain why a userspace VA, a kernel VA, a physical address and an MMIO address are not interchangeable concepts.

## P3.8 — Integrated QEMU appliance

**Before looking at the reference project**

Build your own minimal integration with:

- one pinned kernel;
- one rootfs;
- known DT source (explicit or QEMU-provided);
- exact launch command;
- one small diagnostic utility;
- input/version manifest;
- one boot fault and one userspace-environment fault.

**Reference after first attempt**

- [`../projects/qemu-embedded-linux-appliance/`](../projects/qemu-embedded-linux-appliance/)

**EXIT**

You can bind a boot log to the artifact set that actually produced it and can explain the limits of that evidence.

---

# Phase 4 — Linux kernel drivers

## P4.1 — External modules, Kbuild and first kernel-debug loop

**PRIMARY**

- Kernel docs **Building External Modules** — https://docs.kernel.org/kbuild/modules.html
- Kernel coding style — https://docs.kernel.org/process/coding-style.html
- Dynamic debug HOWTO — https://docs.kernel.org/admin-guide/dynamic-debug-howto.html

**COURSE / LAB**

- Bootlin Linux kernel and driver development — https://bootlin.com/training/kernel/
- Linux Kernel Labs **Kernel Modules** lab — https://linux-kernel-labs.github.io/

**ACTION**

Build/load/unload one tiny module, inspect `modinfo`, module symbols and logs. Stop there; this unit exists to establish the build/debug loop.

**EXIT**

You can rebuild only the module under test, load it, retrieve logs and remove it cleanly.

## P4.2 — Linux device model: device / driver / bus / match / probe

**PRIMARY**

- **The Linux Kernel Device Model — Overview** — https://docs.kernel.org/driver-api/driver-model/overview.html
- Driver infrastructure — https://docs.kernel.org/driver-api/infrastructure.html
- Platform devices/drivers — https://docs.kernel.org/driver-api/driver-model/platform.html

**SOURCE**

- `drivers/base/` with emphasis on the files implementing core device/driver binding; inspect the kernel version you are running.
- `drivers/base/platform.c` for the platform bus implementation.

**ACTION**

For one existing device, locate its `/sys/bus/.../devices`, `/sys/bus/.../drivers`, bound driver link and modalias/OF identity. Correlate that with the driver's registration/match table.

**EXIT**

You can answer separately: who created the device, who registered the driver, what matched them, and what successful `probe()` means.

## P4.3 — Platform driver + Device Tree + MMIO/IRQ resources

**PRIMARY**

- Platform driver docs — https://docs.kernel.org/driver-api/driver-model/platform.html
- Device resource management (`devres`) — https://docs.kernel.org/driver-api/driver-model/devres.html
- Devicetree binding guidance — https://docs.kernel.org/devicetree/bindings/writing-bindings.html and `writing-schema.html`.

**SOURCE**

- `drivers/base/platform.c` for platform resource plumbing.
- Search current upstream for small drivers using `devm_platform_ioremap_resource()` and `platform_get_irq()`; read one from the subsystem you plan to use rather than copying an arbitrary tutorial driver.

**ACTION**

Create one small platform device/driver pair or QEMU/DT-backed fixture. Require `compatible` matching and at least one managed resource. Prove binding through sysfs and logs.

**EXIT**

You can distinguish match failure, probe entry, resource lookup failure and hardware-access failure.

## P4.4 — Generic IRQ, threaded IRQ, workqueues and locking

**PRIMARY**

- Generic IRQ subsystem — https://docs.kernel.org/core-api/genericirq.html
- Workqueues — https://docs.kernel.org/core-api/workqueue.html
- Kernel locking guide — https://docs.kernel.org/kernel-hacking/locking.html

**COURSE**

- Bootlin kernel/driver course sections on interrupts, sleeping, locking and deferred work.

**ACTION**

Trace one interrupt from registration to handler. Move sleepable work to a threaded handler or workqueue and document which context can sleep and which cannot.

**EXIT**

You can justify the context and synchronization mechanism chosen for each shared object.

## P4.5 — GPIO descriptor consumer API

**PRIMARY**

- GPIO consumer interface — https://docs.kernel.org/driver-api/gpio/consumer.html
- GPIO board/firmware mappings — https://docs.kernel.org/driver-api/gpio/board.html

**SOURCE**

- Search current upstream for `devm_gpiod_get` in a small device driver and trace DT/firmware property → descriptor acquisition → value/direction use.

**ACTION**

Convert one simple GPIO consumer to descriptor-based APIs and prove the firmware mapping is the one actually consumed.

**EXIT**

You do not need legacy integer GPIO numbers to explain a modern consumer driver.

## P4.6 — I2C client-driver pattern and regmap orientation

**PRIMARY**

- Linux I2C docs **Writing I2C Clients** — https://docs.kernel.org/i2c/writing-clients.html
- I2C device instantiation — https://docs.kernel.org/i2c/instantiating-devices.html
- Regmap API reference/orientation via kernel driver-api docs/source for the version used.

**SOURCE examples**

- `drivers/hwmon/lm75.c` — representative small I2C sensor-family driver with subsystem integration.
- `drivers/misc/eeprom/at24.c` — useful for I2C client matching and a mature, real device family; read selected paths, not linearly.

**ACTION**

Read two upstream drivers before writing/adapting one. Trace bus discovery/match, register I/O and subsystem registration.

**EXIT**

You can explain the distinction between an I2C adapter/controller driver and an I2C client/device driver.

## P4.7 — SPI device/driver pattern

**PRIMARY**

- SPI documentation index and summary — https://docs.kernel.org/spi/
- Read the current SPI core/device-driver API pages linked there for `struct spi_driver`, message/transfer and controller/device roles.

**SOURCE**

- Choose a small current upstream SPI peripheral driver in the subsystem relevant to your project and trace probe → `spi_*` transfers → subsystem registration.

**ACTION**

Contrast the same simple register-oriented peripheral idea over I2C and SPI. Document what the bus core abstracts and what remains device-specific.

**EXIT**

You can distinguish SPI controller, SPI device and SPI protocol/device-driver responsibilities.

## P4.8 — pinctrl, clocks, regulators and reset controls

**PRIMARY**

- Pinctrl — https://docs.kernel.org/driver-api/pin-control.html
- Common Clock Framework — https://docs.kernel.org/driver-api/clk.html
- Regulator API — https://docs.kernel.org/power/regulator/
- Reset controller API — https://docs.kernel.org/driver-api/reset.html

**SOURCE**

- Read one real upstream peripheral driver that acquires at least two of these resources. Trace the probe order and cleanup/managed lifecycle.

**ACTION**

Draw a dependency diagram for your chosen device: power → reset → clock → pin state → MMIO/IRQ. Compare your diagram with probe/runtime-PM code.

**EXIT**

A deferred-probe message no longer looks mysterious; you can identify which provider dependency is missing.

## P4.9 — DMA mapping and DMAEngine client orientation

**PRIMARY**

- DMA API HOWTO — https://docs.kernel.org/core-api/dma-api-howto.html
- DMAEngine client documentation — https://docs.kernel.org/driver-api/dmaengine/client.html

**Knowledge boundary**

Learn CPU virtual address vs physical address vs DMA address, coherent vs streaming mapping, masks, ownership/synchronization, and basic DMAEngine client flow. Defer IOMMU/SMMU internals.

**ACTION**

Take a driver/data path using DMA and annotate each buffer with owner, CPU address, DMA address, synchronization point and lifetime.

**EXIT**

You never use “physical address” as a casual synonym for DMA address.

## P4.10 — Runtime PM and system sleep

**PRIMARY**

- Runtime PM framework — https://docs.kernel.org/power/runtime_pm.html
- Device power-management documentation index — https://docs.kernel.org/power/
- Device links/dependencies — https://docs.kernel.org/driver-api/device_link.html

**ACTION**

Read a small driver's runtime suspend/resume path. Identify which clocks/regulators/state are disabled and restored and what prevents access while suspended.

**EXIT**

You can distinguish runtime idleness from system-wide suspend and can explain the device's power-state invariant.

## P4.11 — Driver capstone

Build/adapt one small real driver with:

```text
DT/binding
→ match/probe
→ managed resources
→ one subsystem interface
→ IRQ or polling
→ clean remove/PM path
→ one deliberate binding/resource/IRQ fault
```

**COURSE cross-check**

Use Bootlin's kernel/driver labs as a sequence reference; Bootlin's current course explicitly develops an I2C device driver and a serial-port-controller driver, which makes it useful as a mechanism-oriented comparison rather than a vendor-specific recipe.

**EXIT**

You can explain every important line and debug a changed failure variant without copying the known fix.

---

# Phase 5 — BSP / U-Boot / Buildroot / Yocto

## P5.1 — BSP layer mental model

**PRIMARY / SOURCE**

Choose one board with a public upstream/vendor stack and inventory, at minimum:

```text
firmware/ROM assumptions
bootloader
DT
kernel config + patches
rootfs packages/config
build-system metadata
image layout
```

**ACTION**

Draw the ownership boundary of each layer and identify which repositories/artifacts are generated versus source-controlled.

**EXIT**

You can explain why “vendor SDK” and “kernel tree” are not synonyms for BSP.

## P5.2 — U-Boot standard boot, environment, FDT and driver model

**PRIMARY**

- U-Boot documentation — https://docs.u-boot.org/en/latest/
- Read by section title: **Standard Boot**, **Environment Variables**, **Devicetree Control in U-Boot**, **Driver Model**, and the boot/image command documentation relevant to your architecture (`bootz`, `booti`, FIT as applicable).

**ACTION**

Interrupt autoboot; inspect environment; manually load kernel/DT/rootfs; inspect the working FDT; change exactly one bootarg; boot and prove what U-Boot passed to Linux.

**EXIT**

You can separate U-Boot's control DT, working FDT, environment state and Linux boot artifacts.

## P5.3 — Buildroot project customization and package model

**PRIMARY**

- Buildroot manual — https://buildroot.org/downloads/manual/manual.html
- Read by heading: **Project-specific customization**, **Root filesystem overlays**, **Adding new packages to Buildroot**, **BR2_EXTERNAL**, **Rebuilding packages**, **Legal notice and source material** / legal-info tooling where applicable.

**COURSE**

- Bootlin Buildroot training — https://bootlin.com/training/buildroot/

**ACTION**

Create a `BR2_EXTERNAL` project with one board defconfig, one package and one overlay. Run a clean build. Then change package source and observe which target/rebuild command actually propagates it into the final image.

**EXIT**

You know which source-controlled input generated each file under `output/build`, `output/target` and `output/images`.

## P5.4 — Yocto/OpenEmbedded metadata, tasks, signatures and sstate

**PRIMARY**

- Yocto Project Overview Manual — https://docs.yoctoproject.org/dev/overview-manual/index.html — read the development-environment/workflow orientation first.
- Yocto Project Concepts Manual — https://docs.yoctoproject.org/dev/concepts.html — focus on **Layers**, **Recipes**, **Tasks**, **Shared State Cache**, and **Checksums (Signatures)** concepts.
- BitBake User Manual — https://docs.yoctoproject.org/bitbake/dev/singleindex.html — focus on **Execution**, task dependency execution, signatures/checksums and setscene/sstate behavior.

**COURSE**

- Bootlin Yocto/OpenEmbedded training — https://bootlin.com/training/yocto/

**ACTION**

Build one reference image. Add one package, one `.bbappend`, and one machine-specific change separately. Use BitBake inspection tools (`bitbake -e`, task graph/signature tools as appropriate) to explain which task reran and why.

**EXIT**

You reason in metadata → task → signature → artifact terms rather than treating `bitbake` as one opaque compile command.

## P5.5 — BSP kernel/DT/config/patch management

**PRIMARY**

- Yocto **Linux Kernel Development Manual** and **BSP Developer's Guide** from the documentation version you actually use — https://docs.yoctoproject.org/
- Buildroot board/kernel customization manual sections if Buildroot is your chosen system.
- Kernel stable/upstream source and target vendor tree for patch comparison.

**ACTION**

Take one vendor BSP patch. Determine whether support exists upstream, which subsystem owns it, whether it is hardware support/bugfix/product policy, and what would happen if it disappeared during an upgrade.

**EXIT**

You can justify each out-of-tree patch instead of carrying a pile of unexplained diffs.

## P5.6 — Image layout, recovery and update architecture

**PRIMARY / MODEL**

- U-Boot image/FIT/verified-boot documentation for boot artifact structure where relevant — https://docs.u-boot.org/en/latest/
- Use your chosen update framework's official docs only after defining product failure/recovery requirements. RAUC/SWUpdate/OSTree are options, not universal prerequisites.

**ACTION**

Draw a development layout and an A/B production layout. For each update step, describe the power-loss outcome and rollback decision.

**EXIT**

You choose an update mechanism from failure semantics, not popularity.

## P5.7 — Licensing, CVE, SBOM and reproducibility

**PRIMARY**

- Buildroot manual sections around `make legal-info`, source/license collection and vulnerability tooling.
- Yocto documentation for license metadata, SPDX/SBOM generation, CVE checking and reproducible-build support in the version used.

**ACTION**

For one built image, produce a source/license inventory and explain at least one known limitation of automated CVE matching.

**EXIT**

You can trace a shipped package to source/version/license metadata and do not treat “scanner says green” as proof of no vulnerabilities.

## P5.8 — BSP integration capstone

Maintain a small source-controlled integration repository containing only inputs:

```text
bootloader config/environment
kernel config fragments / patches
DT changes
Buildroot or Yocto metadata
one application/package
image/update instructions
bring-up notes
```

**EXIT**

A clean clone can reproduce the image, and you can diagnose one deliberately stale/missing-layer change from source metadata through the final boot artifact.

---

# Phase 6 — Bring-up, tracing, performance and real-time

## P6.1 — Reproducible symptom and cheapest observation channel

**COURSE**

- Bootlin **Linux debugging, profiling, tracing and performance analysis** — https://bootlin.com/training/debugging/

**PRIMARY**

- `dmesg`, procfs/sysfs interfaces and tool man-pages relevant to the actual symptom.

**ACTION**

For every problem, write 3–5 hypotheses before enabling advanced tracing. Identify the cheapest observation that can eliminate at least one hypothesis.

**EXIT**

Your first debugging move is driven by discrimination value, not tool novelty.

## P6.2 — Dynamic debug, driver bind/probe and boot diagnosis

**PRIMARY**

- Dynamic debug HOWTO — https://docs.kernel.org/admin-guide/dynamic-debug-howto.html
- Driver model/platform docs from P4.2/P4.3.
- Kernel parameters documentation for probe/initcall/boot-time flags relevant to the case.

**ACTION**

Use dynamic debug on one driver's probe path and correlate logs with sysfs binding state.

**EXIT**

You can determine whether the problem is “driver never matched”, “probe ran and failed”, or “probe succeeded but runtime behavior failed”.

## P6.3 — tracefs, ftrace and tracepoints

**PRIMARY**

- Kernel tracing index — https://docs.kernel.org/trace/
- Start with **ftrace - Function Tracer**, **Event Tracing**, and tracepoint/event filtering documentation linked from that index.

**ACTION**

Trace one interrupt/workqueue/scheduler-to-userspace path. Export a timeline and mark which intervals are directly observed versus inferred.

**EXIT**

You can select event tracing over function tracing when a stable tracepoint already answers the question.

## P6.4 — perf

**PRIMARY / TOOL**

- `perf stat`, `perf record`, `perf report`, `perf top` man pages matching the installed perf/kernel version.
- Kernel `tools/perf/` source/documentation when behavior is version-sensitive.

**COURSE**

- Bootlin debugging/performance course sections on system load, sampling and profiling.

**ACTION**

For one workload, use `perf stat` to characterize it, then `perf record/report` to locate hot execution. Separately inspect whether apparent slowness is CPU execution or blocked/sleeping time.

**EXIT**

You do not call something “CPU-bound” from wall-clock time alone.

## P6.5 — kprobes, eBPF and LTTng orientation

**PRIMARY**

- Kernel kprobes documentation via https://docs.kernel.org/trace/
- Kernel BPF/libbpf docs — https://docs.kernel.org/bpf/
- LTTng official documentation only if whole-system long-duration tracing is needed.

**ACTION**

Start from one question that a stable tracepoint cannot answer. Instrument one function/return path, then remove the instrumentation when the question is answered.

**EXIT**

You can explain why probing an internal function is more version-fragile than using a stable tracepoint.

## P6.6 — Panic/oops, memory bugs and locking diagnostics

**PRIMARY**

- Kernel bug-hunting/debugging documentation under `docs.kernel.org` admin/process/dev-tools sections.
- KASAN — https://docs.kernel.org/dev-tools/kasan.html
- KCSAN — https://docs.kernel.org/dev-tools/kcsan.html
- Lockdep design/docs — https://docs.kernel.org/locking/lockdep-design.html

**ACTION**

In a disposable kernel/test-module environment, trigger one bounded memory or locking bug, collect the diagnostic, map addresses/symbols, fix it, and rerun the same reproducer.

**EXIT**

You can distinguish the symptom report, stack trace, suspected faulty path and actual root cause.

## P6.7 — Latency and PREEMPT_RT

**PRIMARY / COURSE**

- Current kernel real-time/PREEMPT_RT documentation for the kernel used.
- Bootlin **Real-time Linux with PREEMPT_RT** — https://bootlin.com/training/preempt-rt/

**Knowledge**

Latency vs throughput; IRQ/scheduling latency; preemption model; priority inversion; threaded interrupts; timer/wakeup behavior; affinity/isolation only after measurement.

**ACTION**

Measure a latency **distribution** under a declared load, not one best-case number. Record platform, kernel config, load and measurement method.

**EXIT**

You can state what latency source dominates and what PREEMPT_RT can/cannot change about it.

## P6.8 — Boot-time measurement and optimization

**COURSE / PRIMARY PRACTICE**

- Bootlin **Embedded Linux boot time optimization** current materials — https://bootlin.com/docs/ (Boot time course) and https://bootlin.com/doc/training/boot-time/

**ACTION**

Define the endpoint (“application usable”, not vague “boot done”), measure firmware/bootloader/kernel/userspace contributions, identify the critical path, change only a dominant contributor, and measure again.

**EXIT**

Every claimed improvement has a before/after measurement with the same endpoint and environment.

## P6.9 — Memory and I/O performance

**PRIMARY / TOOLS**

- Current `/proc` documentation/man-pages for process/system memory statistics.
- `vmstat`, `pidstat`, `iostat`/block tools and perf man-pages installed on the system.
- Kernel memory-management and block-layer docs only for mechanisms implicated by evidence.

**ACTION**

Pick one real bottleneck. Use at least two independent channels (for example process RSS/PSS + reclaim counters; I/O latency + scheduler/block trace; CPU copy cost + DMA path evidence).

**EXIT**

You can separate leak, page cache, memory pressure/reclaim, CPU copy cost and storage latency rather than collapsing them into “memory is slow”.

## P6.10 — Debug/performance capstone

Deliver a short report:

```text
Symptom
Environment / exact versions
Reproduction
Initial hypotheses
Measurements / traces
Narrowed scope
Root cause
Fix
Before/after evidence
Regression
Remaining uncertainty
```

**EXIT**

Another engineer can understand and challenge your reasoning without rerunning every exploratory command.

---

# Resource selection rule when multiple sources disagree

Use this authority order:

```text
current hardware/vendor specification or TRM
→ current upstream subsystem/API documentation
→ source code for the exact version being executed
→ maintained expert course
→ durable book/model
→ blog/forum
→ AI explanation
```

A course can teach the sequence extremely well without being the authority for a version-sensitive kernel API. A book can give a better mental model than current API docs without defining current behavior. Use each resource for the job it is good at.