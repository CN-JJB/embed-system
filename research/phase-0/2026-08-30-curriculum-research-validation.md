# Phase 0 — Curriculum Research & Validation

> Status: **Research Package — Leader review required**  
> Role: Researcher + Curriculum Analyst  
> Checked date: **2026-08-30**  
> Scope: 2026-09 → 2027-06 pre-internship curriculum validation  
> Verification: source/version research checked; proposed labs/projects are **UNVERIFIED** until executed by the learner/reviewer.  
> Editorial authority: none. This document proposes evidence-based changes; it does not redefine the canonical curriculum by itself.

## Research Method and Confidence

This package uses an evidence hierarchy consistent with the repository policies:

1. official specifications / manuals / upstream source;
2. official project documentation;
3. official employer job pages;
4. university/professional teaching material;
5. classic books;
6. community material only as secondary evidence.

Job-market "frequency" below is **qualitative role-family frequency**, not a statistically representative percentage of the entire market. The sample deliberately weights Embedded Linux, BSP, Linux Driver, Linux Kernel, Firmware/RTOS, and SoC/Platform roles. Current primary examples include 2027 Mainland China campus roles from Kylinsoft and OPPO, plus current NXP, Apple, Tesla, and MediaTek system-software roles. Senior roles are used to infer long-term depth, not undergraduate entry requirements.

---

# Part 1 — Executive Findings

## Verdict

The current career direction is correct, but the strict serial ordering of Phase 1 → Phase 5 is not.

The strongest evidence from current target roles is that valuable BSP/Kernel/Platform work connects:

`C/C++ -> OS fundamentals -> architecture -> bring-up -> kernel/driver -> hardware interfaces -> debugging -> performance -> upstream/large-codebase workflow`.

Examples:

- Kylinsoft's 2027 embedded and Linux-kernel campus roles explicitly combine C/C++, Linux, kernel/driver, ARM, RTOS/BSP, SPI/I2C/UART/USB/Ethernet/PCIe, GDB, logic analyzer/oscilloscope, bring-up, performance and open-source experience.
- OPPO's 2027 low-level software campus role explicitly combines Linux kernel optimization, MCU/platform work, embedded software, C/C++, data structures/algorithms and OS fundamentals.
- NXP's current Linux Kernel/BSP role spans U-Boot, firmware, hypervisor, kernel, device drivers, SoC bring-up, Yocto, JTAG, upstream and complex HW/SW-boundary debugging.
- Current Apple low-level roles combine drivers/firmware, SoC blocks, memory management and performance.
- Current Tesla and MediaTek role families reinforce embedded Linux/firmware/platform integration, bring-up and performance.

### What is already strong

1. The roadmap does not reduce embedded engineering to HAL/API usage.
2. It treats C, RTOS, OS, kernel, BSP and SoC as one systems continuum.
3. The Zynq path can turn existing hardware/RTL experience into differentiated hardware-software co-design.
4. `Lab + Challenge + Debug + Project + Gate` is aligned with real engineering work.
5. The explicit debugging loop `Symptom -> Hypothesis -> Evidence -> Experiment -> Root Cause` should remain a core grading model.

### Largest risk

The roadmap currently delays the highest-value Linux BSP/Driver practice until too much prerequisite material has been "completed."

From 2026-09 to 2027-06, a nominal 2 h/day budget is about 600 hours, but a realistic scheduled curriculum budget should be closer to **430–480 hours** after school workload, exam periods, failed experiments, repeated Gates and project-debug time.

That budget cannot support deep completion of all of the following before internship season:

- full System C rebuild;
- full Linux system programming;
- deep RTOS + Zephyr;
- full OSTEP/xv6;
- full architecture sequence;
- Linux-from-scratch;
- Buildroot + deep Yocto;
- U-Boot;
- full driver coverage;
- Zynq;
- AXI DMA/coherency;
- PCIe;
- DDR;
- secure boot;
- virtualization;
- advanced performance engineering.

The curriculum must optimize for capability and evidence, not content coverage.

## Five highest-priority changes

1. **Move architecture fundamentals earlier.** ABI, stack/calling convention, privilege, exception, MMIO, cache and TLB basics must begin in Phase 1/2 rather than wait for a later architecture phase.
2. **Move Embedded Linux and Linux Driver earlier.** Start QEMU/kernel/rootfs/Buildroot by 2026-12; start modules/platform driver/DT by 2027-01.
3. **Introduce Device Tree twice.** First at Linux boot as hardware description; later at driver stage for bindings/schema/resources.
4. **Compress RTOS to mechanism-focused depth.** FreeRTOS is required; Zephyr is high-value optional material and must not block the Linux main line.
5. **Separate real-device Linux Driver work from the Zynq flagship.** First prove subsystem-driver competence on a normal I2C/SPI/GPIO device; then use Zynq for co-design differentiation.

Additional underweighted skills: testing/validation, static/dynamic analysis, tracing, C++ reading literacy, upstream workflow, interview DSA and technical English.

---

# Part 2 — Job Market Skill Matrix

| Skill | China Frequency | International Frequency | Depth Expected | Career Value | Recommended Level by 2027-06 |
|---|---|---|---|---|---|
| C | Very high | Very high | L4 | 5/5 | **L4** |
| C++ | High | High | L2-L4 by role | 4/5 | **L2 reading/modification** |
| Linux userspace | Very high | Very high | L3-L4 | 5/5 | **L4** |
| Git/build workflow | High | High | L3 | 4/5 | **L3** |
| Debugging/root cause | Very high | Very high | L4 | 5/5 | **L4** |
| RTOS | High in firmware/embedded OS | Medium-high | L3-L4 | 4/5 | **L3** |
| OS fundamentals | High | Very high | L3-L4 | 5/5 | **L3** |
| Linux Kernel | High in target family | Very high in target family | L3-L4 | 5/5 | **L3, moving toward L4** |
| Linux Driver | Very high | Very high | L4 for driver roles | 5/5 | **L4 for at least one real device** |
| BSP | High | Very high | L3-L4 | 5/5 | **L3** |
| Board bring-up | High | Very high | L4 in platform roles | 5/5 | **L3 pre-internship** |
| Device Tree | High in Linux BSP | High in Linux BSP | L3 | 4.5/5 | **L3** |
| Bootloader / U-Boot | High in BSP | High in BSP | L3 | 4/5 | **L2-L3** |
| ARM architecture | Very high | Very high | L3-L4 | 5/5 | **L3** |
| RISC-V | Medium / strategic | Medium / strategic | L3 | 4/5 | **L2-L3** |
| MMIO/registers | Very high | Very high | L4 | 5/5 | **L4** |
| Interrupt/exception | Very high | Very high | L4 | 5/5 | **L4** |
| DMA | High | High | L3-L4 | 4.5/5 | **L3** |
| Cache/MMU/TLB | High | High | L3-L4 | 5/5 | **L3** |
| Memory ordering/coherency | Medium-high | High in SoC/platform | L3-L4 | 5/5 long-term | **L2-L3** |
| I2C/SPI/UART | Very high | High | L3-L4 | 4/5 | **L4 use/debug** |
| USB/Ethernet | High | High | L3+ | 4/5 | **L2** |
| PCIe | Medium-high in AI/SoC | High in platform/AI | L3-L4 | 4.5/5 | **L2** |
| DDR | Medium | Medium-high | L3-L4 | 4/5 | **L2** |
| JTAG/SWD | High | High | L3-L4 | 4.5/5 | **L3** |
| Scope/logic analyzer | High | High | L3 | 4.5/5 | **L3-L4** |
| perf/ftrace/trace tools | Medium-high | High | L3 | 4/5 | **L2-L3** |
| Buildroot | Medium | Medium | L3 | 3.5/5 | **L3** |
| Yocto/OpenEmbedded | Medium-high in BSP vendors | High in BSP vendors | L3+ | 4/5 | **L2 initially** |
| Upstream workflow | Medium | High | L3-L4 | 5/5 differentiator | **L2: complete patch workflow** |
| FPGA / HW-SW co-design | Medium | Medium-high in SoC | L3+ | 4.5/5 | **L3** |
| Secure Boot | Low-medium entry | Medium | L3+ | 4/5 later | **L1-L2** |
| Virtualization | Low-medium entry | Medium-high platform | L3+ | 4/5 later | **L1** |
| Testing/static analysis/CI | High but often implicit | High | L3 | 4/5 | **L3** |
| Data structures/algorithms | High for interviews | High | L2-L3 | 4/5 | **L2-L3** |
| Technical English | High | Very high | L3+ | 4.5/5 | **L3** |

### Interpretation

Do not translate high career value directly into early curriculum priority.

PCIe, DDR, Yocto, secure boot and virtualization are valuable. However, before internship season the higher-return dependency chain is:

`C -> ABI -> MMIO -> IRQ -> DT -> Driver -> userspace -> debug/measurement`.

The learner should be able to **explain and debug that chain** before collecting advanced-topic familiarity.

---

# Part 3 — Canonical Resource Map

## C

- **Official:** GCC manuals; GNU binutils documentation; GDB documentation; ABI documents.
- **Open Source:** avoid starting with a huge C codebase. Begin with small self-written programs, then selected FreeRTOS source and small Linux drivers.
- **Book:** CS:APP selected chapters; TLPI selected chapters.
- **Course:** Berkeley CS61C selected C, RISC-V calling convention, compiler/assembler/linker/loader, cache and VM material.
- **Lab idea:** compile the same program at different optimization levels; use `nm/readelf/objdump`; fix undefined/multiple-definition failures; explain stack frames in GDB.
- **Depth:** tools must become evidence instruments, not manuals to read cover-to-cover.

## Linux

- **Official:** Linux man-pages; `/proc`, `/sys`, glibc/system-call documentation.
- **Open Source:** BusyBox for rootfs context, not as first large source-reading project.
- **Book:** TLPI primary; APUE secondary/reference.
- **Course:** Bootlin Embedded Linux material for system construction; custom system-programming labs for userspace.
- **Lab idea:** `fork/exec/pipe/dup2/waitpid` mini pipeline; deliberate FD leak; debug using `strace` and `/proc/<pid>/fd`.

## OS

- **Official/real system reference:** Linux kernel documentation.
- **Open Source:** xv6-riscv.
- **Book:** OSTEP.
- **Course:** MIT 6.1810 selected labs.
- **Lab idea:** trace syscall → trap → kernel → return; page tables; COW; race/lock.
- **Use extent:** do not complete all 6.1810 labs before 2027. Select syscall/trap/page-table/concurrency labs.

## RTOS

- **Official:** FreeRTOS Kernel source/documentation; Zephyr documentation.
- **Open Source:** FreeRTOS-Kernel first; Zephyr second.
- **Book:** no additional mandatory thick RTOS book.
- **Course/Lab:** custom measured scheduler/interrupt/synchronization labs.
- **Lab idea:** GPIO/scope context timing; priority inversion; ISR→task; queue blocking; stack overflow; jitter.
- **Use extent:** selected `tasks.c`, `queue.c`, `list.c`, Cortex-M `port.c`, `heap_4.c`.

## Kernel

- **Official:** Linux Kernel Documentation and upstream source.
- **Baseline:** pin a 6.18.y LTS release for course reproducibility; track current mainline separately.
- **Book:** use OSTEP/CS:APP for stable mechanisms, not old kernel books for current APIs.
- **Course:** Bootlin Linux kernel/driver training.
- **Lab idea:** configure/build/boot, Kbuild/module, oops, dynamic debug, ftrace.

## Driver

Use real upstream drivers as reading targets.

| Path (Linux v6.18) | Teaching value | Recommended order |
|---|---|---|
| `drivers/char/hw_random/timeriomem-rng.c` | compact platform/MMIO/resource flow | first |
| `drivers/leds/leds-gpio.c` | GPIO descriptor + subsystem integration | first group |
| `drivers/gpio/gpio-74x164.c` | SPI + GPIO subsystem + mutex | SPI stage |
| `drivers/hwmon/tmp102.c` | real I2C sensor + regmap + hwmon + regulator/PM | I2C stage |
| `drivers/uio/uio_pdrv_genirq.c` | platform + IRQ + userspace I/O boundary | IRQ stage |
| `drivers/tty/serial/uartlite.c` | Xilinx UART Lite; useful before Zynq capstone | later |
| DMAengine/Xilinx DMA drivers | descriptor/channel/concurrency complexity | stretch / post-internship |

A short `cdev/file_operations` module is still useful to expose the fd→syscall→file_operations path, but **character-device boilerplate must not become the driver curriculum's final model**. Real projects should move into existing kernel subsystems (IIO, hwmon, GPIO, LED, input, tty, netdev, regulator, etc.).

## Embedded Linux

- **Official:** Linux, U-Boot, Buildroot, Yocto/OE, BusyBox documentation.
- **Open Source:** Buildroot, BusyBox, U-Boot.
- **Course:** Bootlin Embedded Linux / Buildroot.
- **Lab:** toolchain → kernel → rootfs/initramfs → Device Tree → boot → Buildroot automation.

### Buildroot vs Yocto

Recommended order:

`manual boot/rootfs understanding -> Buildroot -> board/package integration -> Linux Driver/BSP -> Yocto orientation -> deeper Yocto later`.

Yocto has real BSP-employer value, but its BitBake/layer/recipe model should not precede understanding of what kernel/rootfs/boot artifacts actually are.

## Architecture

- **Official:** RISC-V Unprivileged/Privileged specs; Arm architecture/ABI manuals; processor TRMs.
- **Open Source:** xv6/OpenSBI for software-side privilege/boot examples.
- **Book:** Computer Organization and Design (RISC-V); selected CS:APP.
- **Course:** CS61C selected.
- **Lab:** C→assembly→ABI; trap; page-table walk; cache microbenchmark; MMIO.
- **Scope:** architecture is a recurring spine, not a delayed standalone block.

## SoC

- **Official:** Zynq-7000 TRM UG585; Arm AMBA AXI documentation; memory-model documentation.
- **Open Source:** Linux/U-Boot integration examples.
- **Lab:** AXI4-Lite register block → IRQ → DT → Linux platform driver → userspace benchmark.
- **Scope before internship:** AXI4-Lite + interrupt required; AXI DMA/coherency is stretch.

## FPGA

- **Official:** AMD/Xilinx and Arm AXI documentation.
- **Open Source:** LiteX as later comparative reference.
- **Lab:** custom register/FIFO/counter peripheral with interrupt.
- **Scope:** exploit existing Verilog ability; do not create a second FPGA curriculum that competes with Linux.

## Debugging

- **Official:** GDB docs; kernel tracing docs; perf/ftrace documentation.
- **Method:** every phase receives deliberate faults.
- **Labs:** segfault, memory corruption, link error, deadlock/race, bad DMA setup, kernel oops, bad DT/IRQ.
- **Gate:** a fix without evidence/root cause is not a pass.

---

# Part 4 — Open Source Project Ranking

## Tier A — Main-line required

| Project | Upstream | License | Activity / Complexity | Suggested baseline | Read/use | Phase | First source read? |
|---|---|---|---|---|---|---|---|
| FreeRTOS-Kernel | https://github.com/FreeRTOS/FreeRTOS-Kernel | MIT | high / medium | V11.3.0 (`9b777ae`) | tasks, queue, list, Cortex-M port, heap_4 | 2 | **Yes** |
| xv6-riscv | https://github.com/mit-pdos/xv6-riscv | MIT | teaching-maintained / medium | pin same commit as selected MIT 6.1810 labs | trap, syscall, VM, locks | 3 | **Yes** |
| Linux kernel | https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git | GPL-2.0-only | very high / very high | **6.18.y LTS**, record exact patch release at lab freeze | selected docs + small drivers | 3-5 | Whole tree: no; small driver: yes |
| Buildroot | https://gitlab.com/buildroot.org/buildroot | GPL-2.0-or-later core; packages retain own licenses | high / medium-high | 2026.05.2 for current research snapshot; freeze exact course release later | config, board, package, rootfs | 3 | Use first |
| U-Boot | https://source.denx.de/u-boot/u-boot.git | GPL-2.0-or-later | high / high | v2026.07 research snapshot | boot flow, env, DT, selected driver model | 3/5 | No |
| QEMU | https://gitlab.com/qemu-project/qemu.git | GPL-2.0 | very high / very high | 11.1.1 research snapshot | heavy use; source reading only later | 3 | No |
| BusyBox | https://git.busybox.net/busybox/ | GPL-2.0 | active / medium | pin transitively with Buildroot course baseline | rootfs/init/shell context | 3 | No |

## Tier B — High-value elective

| Project | License | Why useful | Why not main-line now |
|---|---|---|---|
| Zephyr | Apache-2.0 | modern Kconfig/DT/device-model RTOS engineering | conceptual/tooling overhead competes with Linux main line |
| OpenSBI | BSD-2-Clause | clean RISC-V privilege/boot boundary | valuable but not target-role bottleneck |
| LiteX | BSD-2-Clause | strong co-design/SoC comparison | overlaps Zynq co-design and introduces another framework |
| Ibex | Apache-2.0 | high-quality RISC-V core and verification culture | learner already has CPU/RTL experience; lower marginal return |

## Tier C — Later / currently defer

- Rocket Chip: powerful generator ecosystem, but Chisel/Scala/SoC complexity is too expensive before internship.
- PicoRV32: excellent compact core, but largely repeats an existing strength.
- VexRiscv/VexiiRiscv: useful ecosystem, but not a current bottleneck.
- deep QEMU internals: using QEMU is important; developing QEMU is not a pre-internship Gate.
- BitBake internals: learn Yocto/OE workflow before implementation internals.
- deep Linux DMAengine driver reading: defer until platform/I2C/SPI/IRQ/locking are solid.

### Recommended source-reading progression

`own C -> selected FreeRTOS -> selected xv6 -> 200–400 LOC Linux driver -> subsystem driver -> larger kernel framework`.

Do **not** start kernel reading by following `start_kernel()` linearly.

---

# Part 5 — Classic Book Reading Map

## Computer Systems: A Programmer's Perspective (3e)

Strong recommendation, selected only.

| Chapter | Use | Purpose | Phase |
|---|---|---|---|
| Ch2 Representing and Manipulating Information | core | bits, integers, representation, overflow | 1 |
| Ch3 Machine-Level Representation | selected | stack/call/disassembly; map concepts to ARM/RISC-V too | 1 |
| Ch4 Processor Architecture | mostly skip | existing CPU background; COD/CS61C fit better | — |
| Ch5 Optimizing Program Performance | selected | compiler/performance reasoning | 3/5 |
| Ch6 Memory Hierarchy | core | cache/locality | 2/3 |
| Ch7 Linking | core | ELF/symbol/relocation | 1 |
| Ch8 Exceptional Control Flow | selected core | exception/process/signal | 1/3 |
| Ch9 Virtual Memory | core | address translation/VM | 3 |
| Ch10 System-Level I/O | selected core | fd model | 1 |
| Ch11 Network Programming | mostly skip | project/TLPI can cover enough | — |
| Ch12 Concurrent Programming | selected | reinforce OSTEP/TLPI | 1/2 |

Important limitation: CS:APP 3e machine-code teaching is x86-64 centric, so architecture/calling-convention learning must be cross-checked with Arm/RISC-V ABI/course material.

## The Linux Programming Interface

Primary Linux system-programming book.

Prioritize:

- fundamental concepts/system calls/file I/O;
- process memory/allocation;
- process information and `/proc`;
- signals/timers selected;
- process creation/execution;
- POSIX threads and synchronization selected;
- pipes/FIFOs;
- memory mapping;
- sockets selected.

Use ACLs, terminals, locale and exhaustive administration details as reference unless needed by a project.

## APUE

Classic, but **not** a second cover-to-cover Linux main text.

Use selected material on:

- File I/O;
- Process Control;
- Signals;
- Threads;
- Advanced I/O;
- IPC;
- Network IPC.

Prefer TLPI for Linux-specific depth.

## OSTEP

Excellent OS mental-model book; select by mechanism.

Prioritize:

- Process / Process API;
- CPU scheduling basics;
- Address Spaces;
- Address Translation;
- Paging / TLB / Page Tables;
- Threads;
- Locks;
- Condition Variables;
- Semaphores;
- Concurrency Bugs;
- I/O Devices;
- selected file-system implementation.

Pair concepts with xv6/Linux experiments. Do not complete every scheduling/persistence/distributed section before internship.

## Computer Organization and Design — RISC-V

Use:

- instruction/ABI review;
- processor/exceptions selected;
- **memory hierarchy as core**;
- selected parallelism later.

Purpose: convert previous "built a CPU" experience into a systematic architecture model connected to software.

## Computer Architecture: A Quantitative Approach

Excellent but currently too deep as a main text.

Before internship, at most use selected:

- quantitative/performance methodology;
- memory hierarchy.

Defer deep ILP/TLP/GPU/advanced architecture to the 2027–2028 SoC/Platform stage.

### Book set verdict

Recommended main reading set:

`TLPI selected + OSTEP selected + CS:APP selected + COD selected`.

APUE = reference.  
CAQA = later advanced text.

---

# Part 6 — Baseline Assessment

## Overall design

- Target total: **8 hours**
- Total score: **100**
- Scored tasks: **AI-Free**
- May use: compiler/tool help, `man`, GDB help, supplied source, STM32 datasheet/RM.
- May not use: AI solution generation, answer search, copied solutions.
- After scoring: optional 30-minute AI-assisted review comparing independent reasoning with external suggestions.

Every debugging task must submit:

`Symptom -> Hypotheses -> Evidence -> Experiment -> Root Cause -> Fix -> Regression Test`.

## Module A — System C + Toolchain — 120 min / 25 pts

| Task | Problem | Target | Difficulty | AI-Free | Time | Score / pass | Fail remediation |
|---|---|---|---|---|---:|---|---|
| A1 | inspect a C program containing dangling pointer, OOB access, signed-overflow/shift UB, bad `sizeof`, struct-layout assumption; identify and repair | pointer, memory, UB, layout | D3 | yes | 45m | 10; >=6 | C memory + UB labs |
| A2 | implement callback registry with function pointer + `void *ctx`; explain lifetime | callback/API design | D2 | yes | 25m | 5; >=3 | callback/function pointer |
| A3 | fix undefined-reference / duplicate-symbol errors across `.c/.h`; use `nm/readelf/objdump` to explain symbol/section/relocation | compile/link/ELF | D3 | yes | 50m | 10; >=6 | toolchain/ELF |

A1 only receives full credit when the learner explains **why** the behavior is invalid/undefined or ABI-dependent, not only where the bug appears.

## Module B — Linux — 90 min / 20 pts

| Task | Problem | Target | Difficulty | AI-Free | Time | Score / pass | Remediation |
|---|---|---|---|---|---:|---|---|
| B1 | implement `producer -> filter` using `fork/pipe/dup2/exec/waitpid`; close every FD correctly | process/fd/pipe | D3 | yes | 50m | 12; >=7 | Linux process/FD |
| B2 | diagnose a hanging process whose FD count grows; use `ps`, `/proc`, `strace`, signals | system debugging | D3 | yes | 40m | 8; >=5 | proc/strace/debug |

"Program eventually runs" is insufficient if a pipe endpoint leak prevents proper EOF semantics.

## Module C — Debugging — 120 min / 25 pts

| Fault | Required task | AI-Free | Time | Score |
|---|---|---|---:|---:|
| C1 Segfault | GDB backtrace/frame/local evidence for NULL/UAF-like fault | yes | 25m | 5 |
| C2 Corruption | diagnose delayed heap overwrite; ASan allowed | yes | 35m | 7 |
| C3 Race-like | pthread producer/counter/queue intermittent failure; prove the race or alternative root cause | yes | 40m | 8 |
| C4 Build/link | header/global/static/ABI-like mismatch | yes | 20m | 5 |

Critical rule: changing sleeps/timeouts until a failure disappears is **not** root-cause evidence.

At least 3/4 faults must reach the actual root cause.

## Module D — Computer Systems — 75 min / 15 pts

| Task | Problem | AI-Free | Time | Score |
|---|---|---|---:|---:|
| D1 | compile a small function; use disassembly + GDB to explain call/return, PC/SP and stack state | yes | 25m | 5 |
| D2 | explain control-flow/privilege differences between hardware IRQ and syscall | yes | 15m | 3 |
| D3 | compare two memory access patterns with supplied cache/TLB assumptions and predict behavior | yes | 20m | 4 |
| D4 | given two processes and two threads, identify shared/non-shared resources and explain | yes | 15m | 3 |

Definitions without executable-system reasoning receive partial credit only.

## Module E — STM32 — 75 min / 15 pts

Datasheet/RM use is explicitly allowed and encouraged.

| Task | Problem | AI-Free | Time | Score |
|---|---|---|---:|---:|
| E1 | trace reset vector/startup/linker placement to `main()` | yes | 20m | 4 |
| E2 | configure periodic timer IRQ without depending on HAL; explain key registers | yes | 20m | 4 |
| E3 | analyze MMIO snippet: where `volatile` is needed and what it does **not** guarantee | yes | 10m | 2 |
| E4 | design timer-triggered DMA acquisition; diagnose a deliberately bad configuration with registers + scope evidence | yes | 25m | 5 |

## Baseline pass rules

Must satisfy all:

- total >= **70/100**;
- System C >= 65%;
- Debugging >= 65%;
- no module below 50%;
- Debugging: >= 3/4 true root causes;
- scored tasks completed AI-Free.

| Result | Action |
|---|---|
| >=85, no weak module | Fast Track |
| 70–84 | Normal roadmap |
| 60–69 | 2–4 week targeted remediation |
| <60 | extend Foundations |
| Debug Gate fail | do not enter Linux Driver main line regardless of total |

---

# Part 7 — Roadmap v1.1

## Planning budget

Schedule approximately **45–50 h/month**, not the full theoretical 2 h/day.

Ten months gives roughly **450–480 scheduled hours**, leaving unscheduled capacity for university work, failures, re-runs, portfolio cleanup and interviews.

| Month | Main work | Approx. hours | Gate/output |
|---|---|---:|---|
| **2026-09** | Baseline; pointer/lifetime/memory; struct/alignment/endian; UB; callbacks; warnings/sanitizers; GDB; Git. Begin stack/PC/SP/calling convention/ABI. | 45 | independently root-cause segfault + corruption |
| **2026-10** | Linux FD/process/fork/exec/pipe/signal/mmap/pthread/socket basics; `/proc`, `/sys`, `strace`; Make; compile/link/ELF. Begin Project 1. | 48 | systems-C/Linux Gate |
| **2026-11** | STM32 startup/vector/linker/NVIC/timer/DMA; FreeRTOS scheduler/context switch/queues/semaphore/mutex/inversion/stack; selected source. Project 2. | 48 | measured RTOS/debug Gate |
| **2026-12** | cross toolchain; QEMU; kernel build; BusyBox/initramfs/rootfs; Buildroot; boot logs; basic DT. Architecture: privilege/exception/syscall/MMIO. | 45 | boot reproducible Linux image |
| **2027-01** | OSTEP+xv6 selected syscall/trap/address-space/page-table/TLB/locks; Linux module/Kbuild/source navigation; driver model/platform driver/DT matching | 48 | first minimal platform driver |
| **2027-02** | MMIO/resources/`devm_*`; DT; IRQ; wait queue; mutex/spinlock; short cdev model; read `timeriomem-rng` and `leds-gpio`. Start Project 3. | 50 | platform/IRQ Gate |
| **2027-03** | real I2C/SPI subsystem driver; regmap; DT YAML binding; `dtbs_check`; error paths; concurrency; PM basics; read `tmp102`, `gpio-74x164`. | 50 | real-device driver portfolio candidate |
| **2027-04** | U-Boot; boot sequence; kernel config; Buildroot board/package integration; BSP hardening. Yocto **orientation only**. Begin applications. | 45 | reproducible BSP demo + resume-ready project |
| **2027-05** | Zynq AXI4-Lite peripheral → MMIO → IRQ → DT → Linux platform driver → userspace → benchmark. ILA/scope/tracing as applicable. | 48 | Project 4 v1 |
| **2027-06** | Internship Gate; root-cause reports; README/diagrams; build reproducibility; interview C/OS/Linux/driver; DSA; English explanation; upstream patch workflow | 40 | full internship Gate |

### Explicitly deferred beyond mandatory pre-internship scope

- AXI DMA as Project 4 v2;
- deep cache coherency;
- PCIe;
- deep DDR tuning;
- secure boot;
- virtualization;
- deep Yocto/OE;
- full Zephyr path;
- CAQA deep study.

## Roadmap audit answers

1. **Sequence reasonable?** Dependencies mostly yes; strict serial execution no.
2. **Too early?** deep Yocto, PCIe, DDR, advanced coherency/security/virtualization.
3. **Too late?** architecture basics, Embedded Linux, DT, Linux Driver.
4. **Missing?** validation/testing, sanitizers/static analysis, tracing, C++ literacy, upstream workflow, interview DSA, English technical output.
5. **Can delete?** before internship: full Zephyr, full APUE, full xv6, advanced PCIe/DDR/security/virtualization.
6. **Finish before summer 2027?** v1.1: plausible; full original scope: not plausible at quality.
7. **2 h/day realistic?** yes for a 450–480 h curated plan, not for exhaustive coverage.
8. **RTOS/Linux/Driver weighting?** reduce RTOS breadth; increase Linux/Driver.
9. **Move DT earlier?** yes: introduce during first Linux boot, deepen during driver work.
10. **Move architecture earlier?** yes: begin in 2026-09 as a recurring spine.
11. **Zynq as flagship before 2027 internship?** yes as capstone, no as the only driver proof.
12. **Raspberry Pi 5 for driver teaching?** useful for Linux/kernel/tracing/modules; not ideal as the single canonical BSP lab platform.
13. **Buy another board?** optional single-board purchase only. Recommend evaluating **BeaglePlay** because current Bootlin kernel-driver labs support it and expose common peripheral interfaces. Purchase should wait until the Project 3 hardware decision.

---

# Part 8 — Project Ladder

## Original project audit

| Original project | Verdict |
|---|---|
| Linux C telemetry daemon | keep, but make it a systems-engineering project rather than "sensor + socket" |
| STM32 + FreeRTOS data node | keep; require measurable scheduler/concurrency/debug evidence |
| Custom peripheral + Linux Driver | too ambiguous and can duplicate Zynq |
| Zynq AXI + Linux Driver | high value, but risky/too complex as the only driver proof |

## Project 1 — Linux Systems Telemetry Service

Required elements:

- `/proc`/`/sys`;
- robust FD lifecycle;
- signals;
- Unix-domain socket or other IPC;
- `poll()`/event-driven I/O;
- config/logging;
- graceful shutdown;
- Make;
- ASan/UBSan;
- GDB + strace;
- automated tests.

Career proof: C + Linux systems programming + engineering hygiene.

## Project 2 — STM32 FreeRTOS Acquisition Node

Suggested flow:

`timer-triggered ADC/SPI -> DMA circular buffer -> ISR -> processing task -> communication task`.

Required experiments:

- scheduler latency;
- queue blocking;
- stack watermark;
- priority inversion;
- priority inheritance;
- deliberate stack overflow;
- watchdog recovery;
- scope-based timing evidence.

Career proof: RTOS mechanism + hardware + measurable debugging.

## Project 3 — Real Peripheral Linux Driver

Prefer a real I2C/SPI device or a small self-designed board.

Required:

- actual Linux subsystem (e.g. IIO/hwmon/GPIO);
- DT node and binding;
- `probe()` and managed resources;
- I2C/SPI/regmap or MMIO as appropriate;
- IRQ if device supports it;
- synchronization;
- error paths;
- fault injection;
- tracing;
- measurement/test.

This should be the **primary pre-internship Linux Driver portfolio item**.

## Project 4 — Zynq AXI Co-design Capstone

v1:

`RTL -> AXI4-Lite -> register map -> IRQ -> ARM PS -> Device Tree -> Linux driver -> userspace -> benchmark`.

Must document:

- register map;
- interrupt semantics;
- memory-ordering assumptions;
- locking;
- measurements;
- failure modes.

v2 stretch:

`AXI DMA -> DMA API/coherency concerns -> throughput/latency analysis`.

### Progression

`P1 OS API -> P2 real-time + hardware -> P3 kernel <-> real device -> P4 self-designed hardware <-> kernel`.

This removes the overlap between the original Projects 3 and 4.

---

# Part 9 — 2027 Internship Gate

## C

AI-Free learner must be able to:

- implement a 500–1000 LOC C component cleanly;
- reason about pointer/lifetime;
- use callbacks/function pointers;
- explain alignment/padding/endian;
- identify common UB;
- use GDB and sanitizer evidence;
- read simple disassembly;
- use `readelf/nm/objdump`;
- explain compile → assemble → link.

## Linux

Must independently implement/use/debug:

- `fork/exec/wait`;
- pipe and FD redirection;
- signals;
- pthread basics;
- Unix/TCP socket basics;
- `mmap` basics;
- `/proc` and `/sys`;
- `strace`.

Given a process that hangs or leaks FDs, the learner must independently find evidence and root cause.

## RTOS

Must:

- explain a preemptive scheduler;
- explain a context switch;
- build an ISR→task data path;
- choose queue/semaphore/mutex correctly;
- reproduce priority inversion;
- demonstrate priority inheritance;
- measure stack usage;
- debug stack overflow;
- measure latency/jitter with a scope or equivalent observable signal.

## OS

Must explain from execution behavior:

- process/thread;
- address space;
- syscall;
- exception/trap;
- page table;
- TLB;
- context switch;
- race;
- locks.

Complete selected xv6 tasks spanning syscall/trap, page-table and concurrency categories.

## Kernel

Must:

- configure/build Linux;
- boot in QEMU;
- boot at least one real board;
- build/load a module;
- understand basic Kbuild;
- navigate source;
- read oops/backtrace;
- use kernel logs/dynamic debug;
- use basic ftrace/perf.

## Driver

Hard Gate for "seriously applying to Linux Driver":

one complete real driver demonstrating:

- DT;
- matching;
- `probe()`;
- resources;
- MMIO or I2C/SPI;
- IRQ when applicable;
- synchronization;
- error handling;
- subsystem integration;
- userspace verification.

The learner must answer, with mechanism-level reasoning:

- why mutex vs spinlock here?
- can this interrupt path sleep?
- why use an MMIO accessor instead of ordinary pointer dereference?
- what should and should not be represented in Device Tree?

## Hardware

Must:

- read schematic;
- identify power/clock/reset/pins;
- use datasheet/RM;
- reason about I2C/SPI/UART signals;
- verify timing/electrical behavior with scope where useful;
- trace an IRQ signal through hardware to kernel handling;
- explain a DMA data path at a basic systems level.

## Debugging

Maintain at least five formal root-cause reports:

1. C memory bug;
2. RTOS concurrency/timing bug;
3. STM32 peripheral/DMA bug;
4. Linux userspace bug;
5. Kernel/Driver bug.

Each report must contain:

`Symptom -> Hypotheses -> Evidence -> Experiment -> Root Cause -> Fix -> Regression`.

At least two reports must be completed fully AI-Free.

## Git

Demonstrate actual use of:

- feature branches;
- atomic commits;
- rebase;
- conflict resolution;
- `git bisect` on a seeded regression;
- patch/PR;
- review revision;
- release tag.

## Algorithms

No competitive-programming requirement.

Required basics:

- array/string;
- linked list;
- stack/queue;
- hash table;
- binary search;
- bit operations;
- simple trees;
- BFS/DFS basics;
- Big-O.

Target roughly 20–30 selected easy/medium problems written cleanly in C/C++.

## English

Must:

- read kernel documentation without full translation;
- read datasheet/TRM;
- interpret English job descriptions;
- read patch/RFC discussion at a basic level;
- write one English README;
- write one English root-cause summary;
- explain a driver architecture orally for 5–10 minutes.

## Portfolio

Minimum:

- Linux systems project;
- STM32/FreeRTOS project;
- real-device Linux driver;
- Zynq capstone completed or at least a stable prototype as differentiator.

Each serious project must contain:

- architecture;
- reproducible build;
- test plan;
- debug story;
- measurements where relevant;
- known limitations;
- demo evidence;
- clean Git history.

---

# Part 10 — Source Ledger

All entries checked **2026-08-30**, unless otherwise noted.

| ID | Title | URL | Type | Organization | Version / Date | Relevant section | Used for |
|---|---|---|---|---|---|---|---|
| J01 | 2027 Campus Recruitment — Embedded R&D / Linux Kernel R&D | https://www.kylinos.cn/about/job/campusRecruitment/index.html | Official job | Kylinsoft | posted 2026-08-25 | responsibilities/requirements | Mainland China skill matrix |
| J02 | 2027 Campus — Low-level Software Engineer | https://careers.oppo.com/university/oppo/campus/post/1838?recruitType=Graduate | Official job | OPPO | posted 2026-07-15 | Linux kernel/platform/embedded, C/C++, DSA/OS | Mainland China skill matrix |
| J03 | 2027 Internship — Low-level Software Engineer | https://careers.oppo.com/university/oppo/campus/post/1634?recruitType=Intern | Official job | OPPO | posted 2026-03-06 | Linux kernel/platform/embedded | Internship signal |
| J04 | Software Engineer, Linux Kernel/BSP | https://nxp.wd3.myworkdayjobs.com/en-US/careers/job/Bucharest/Software-Engineer--Linux-Kernel-BSP_R-10063292-1 | Official job | NXP | active 2026-08 | U-Boot, firmware, kernel, drivers, bring-up, Yocto, JTAG, upstream | BSP depth |
| J05 | Linux Software Engineer | https://nxp.wd3.myworkdayjobs.com/en-US/careers/job/Linux-Software-Engineer_R-10065758 | Official job | NXP | active 2026-08 | i.MX BSP, kernel drivers, upstream | Driver/BSP signal |
| J06 | Camera Embedded Software Engineer | https://jobs.apple.com/en-us/details/200679867-3956/camera-embedded-software-engineer | Official job | Apple | posted 2026-08-26 | low-level device drivers, SoC, performance | Embedded/driver depth |
| J07 | GPU Kernel & Firmware Engineer | https://jobs.apple.com/en-us/details/200679763-0836/gpu-kernel-firmware-engineer-graphics-games-ml | Official job | Apple | posted 2026-08-24 | kernel/firmware drivers, memory management | Long-term platform depth |
| J08 | Linux Embedded Engineer, Infotainment Platforms | https://www.tesla.com/careers/search/job/linux-embedded-engineer-infotainment-platforms-vehicle-software-270899 | Official job | Tesla | active 2026-08 | role-family signal | International market |
| J09 | Embedded Software Engineer, Firmware Platforms Internship | https://www.tesla.com/careers/search/job/internship-embedded-software-engineer-firmware-platforms-winter-spring-2027-281102 | Official job | Tesla | active 2026-08 | current internship existence | Internship timing/role family |
| J10 | Automotive Embedded System Software Senior Engineer/Technical Manager | https://careers.mediatek.com/en/jobs/MTK120251121004 | Official job | MediaTek | active 2026-08 | Linux/Android BSP, porting, bring-up, bootloader, C/C++, ARM | Long-term BSP depth |
| J11 | Senior Embedded Power System Software Engineer | https://careers.mediatek.com/en/jobs/MTK120260608001 | Official job | MediaTek | active 2026-08 | C, Linux kernel drivers, electronics, scope/logic analyzer/multimeter, root cause | HW/SW debugging |
| V01 | Linux Kernel Archives | https://www.kernel.org/ | Official release | Linux kernel | mainline 7.2; stable 7.2.2; 6.18.48 longterm on 2026-08-28 snapshot | releases | version strategy |
| V02 | Active kernel releases | https://www.kernel.org/releases.html | Official release policy | Linux kernel | 6.18 LTS, projected EOL Dec 2028 | longterm table | course baseline rationale |
| V03 | FreeRTOS-Kernel Releases | https://github.com/FreeRTOS/FreeRTOS-Kernel/releases | Upstream release | FreeRTOS | V11.3.0, March 2026, `9b777ae` shown on release page | release list | RTOS baseline |
| V04 | Zephyr 4.4.0 release notes | https://docs.zephyrproject.org/latest/releases/release-notes-4.4.html | Official docs | Zephyr Project | 4.4.0 | release overview | RTOS comparison |
| V05 | Buildroot downloads | https://buildroot.org/download.html | Official release | Buildroot | stable 2026.05.2; 2026.08-rc2 candidate | download table | Embedded Linux baseline |
| V06 | Yocto 6.0 (wrynose) release notes | https://docs.yoctoproject.org/6.0/migration-guides/release-notes-6.0.html | Official docs | Yocto Project | 6.0 LTS | release overview | Buildroot/Yocto ordering context |
| V07 | U-Boot release cycle | https://docs.u-boot.org/en/stable/develop/release_cycle.html | Official docs | U-Boot | v2026.07 released 2026-07-06 | current status | bootloader baseline |
| V08 | QEMU download | https://www.qemu.org/download/ | Official release | QEMU | 11.1.1, 2026-08-26 | download list | emulator baseline |
| V09 | GCC 16 release series | https://gcc.gnu.org/gcc-16/ | Official release | GNU | 16.2, 2026-08-07 | release history | toolchain snapshot |
| A01 | RISC-V Ratified Specifications Library | https://docs.riscv.org/reference/home/index.html | Specification | RISC-V International | Unprivileged/Privileged v20260120 | core architecture | architecture source |
| A02 | Zynq-7000 SoC TRM UG585 | https://docs.amd.com/r/en-US/ug585-zynq-7000-SoC-TRM | Official TRM | AMD | v1.15, 2026-02-06 | PS/PL, AXI, memory, boot, peripherals | Zynq capstone |
| K01 | Linux Kernel Documentation | https://docs.kernel.org/ | Official docs | Linux kernel | current | driver model, APIs, tracing, DT | Kernel/Driver |
| K02 | timeriomem-rng.c @ v6.18 | https://github.com/torvalds/linux/blob/v6.18/drivers/char/hw_random/timeriomem-rng.c | Upstream source | Linux kernel | v6.18 | driver source path | first platform/MMIO reading |
| K03 | leds-gpio.c @ v6.18 | https://github.com/torvalds/linux/blob/v6.18/drivers/leds/leds-gpio.c | Upstream source | Linux kernel | v6.18 | driver source path | GPIO/subsystem reading |
| K04 | gpio-74x164.c @ v6.18 | https://github.com/torvalds/linux/blob/v6.18/drivers/gpio/gpio-74x164.c | Upstream source | Linux kernel | v6.18 | driver source path | SPI/GPIO reading |
| K05 | tmp102.c @ v6.18 | https://github.com/torvalds/linux/blob/v6.18/drivers/hwmon/tmp102.c | Upstream source | Linux kernel | v6.18 | driver source path | I2C/regmap/hwmon reading |
| K06 | uio_pdrv_genirq.c @ v6.18 | https://github.com/torvalds/linux/blob/v6.18/drivers/uio/uio_pdrv_genirq.c | Upstream source | Linux kernel | v6.18 | driver source path | platform/IRQ/UIO |
| K07 | uartlite.c @ v6.18 | https://github.com/torvalds/linux/blob/v6.18/drivers/tty/serial/uartlite.c | Upstream source | Linux kernel | v6.18 | driver source path | Xilinx/serial later reading |
| C01 | Embedded Linux kernel and driver development training | https://bootlin.com/training/kernel/ | Professional course/labs | Bootlin | materials current 2026-08 | driver course/labs | teaching sequence + board choice |
| C02 | Embedded Linux training | https://bootlin.com/training/embedded-linux/ | Professional course/labs | Bootlin | materials current 2026-08 | kernel/rootfs/boot labs | Embedded Linux sequence |
| C03 | MIT 6.1810 Fall 2026 | https://pdos.csail.mit.edu/6.S081/2026/ | University course | MIT | Fall 2026 | xv6 labs/schedule | OS selected labs |
| C04 | CS61C Fall 2026 | https://cs61c.org/fa26/ | University course | UC Berkeley | Fall 2026 | C, RISC-V, calling convention, linker/loader, caches, VM | C/architecture sequence |
| B01 | Operating Systems: Three Easy Pieces | https://pages.cs.wisc.edu/~remzi/OSTEP/ | Book/course | Arpaci-Dusseau | v1.10 | process/VM/concurrency/I/O | OS mental model |
| B02 | The Linux Programming Interface | https://man7.org/tlpi/ | Book/reference | Michael Kerrisk | 2010 book; maintained companion site | Linux/UNIX system programming | Linux userspace |
| R01 | Canonical Resources — Initial Registry | ../../resources/CANONICAL_RESOURCES.md | Repository source | embed-system | main @ research start | existing resource direction | cross-check |

## Version policy recommendation

Maintain two separate concepts:

- **Research snapshot:** what is current when research is performed.
- **Tutorial baseline:** a deliberately pinned version tested by the repository.

For example, on 2026-08-30 Linux mainline is 7.2 and 6.18 is an LTS branch. The curriculum should not automatically chase 7.2; pin an exact 6.18.y patch release when labs are actually validated.

Every flagship lab/project should eventually record:

```text
Research checked: YYYY-MM-DD
Tutorial baseline: <tag/commit>
Toolchain baseline: <versions>
Board/firmware baseline: <version if relevant>
Last validation: YYYY-MM-DD
Verification status: VERIFIED / PARTIALLY VERIFIED / UNVERIFIED
```

---

# Part 11 — Disagreements / Risks

## 1. "Finish foundations before Kernel/Driver" is the largest scheduling risk

Systems understanding should spiral:

`C/ABI -> bare metal -> OS mechanism -> kernel/driver -> architecture revisit -> deeper debugging`.

Waiting for architecture/OS to feel "complete" will delay the target work indefinitely.

## 2. RTOS can be overlearned for this target

FreeRTOS is mandatory because scheduler/context switch/interrupt/synchronization/timing are foundational. But several months of RTOS ecosystem breadth before Linux Driver would have poor opportunity cost for this career target.

## 3. Architecture is simultaneously too late and at risk of becoming too deep

Move early:

- ABI;
- privilege;
- exceptions;
- MMIO;
- cache;
- TLB;
- basic memory ordering.

Defer:

- deep OoO;
- advanced branch prediction;
- superscalar quantitative design;
- advanced coherency protocols;
- deep DDR-controller tuning.

## 4. Device Tree must appear before the Driver phase

First encounter: Linux boot and hardware description.  
Second encounter: bindings/schema/resources and driver matching.

## 5. Character-device tutorials are not an adequate model of modern driver work

Learn `file_operations` for the userspace/kernel boundary, then move to real subsystems.

A real I2C/SPI device with DT, regmap, IRQ, locking, error paths and IIO/hwmon/GPIO integration produces a stronger capability signal than another "hello cdev" project.

## 6. Yocto career value does not imply Yocto-first teaching

BSP vendors use Yocto, but Buildroot better exposes the full image-building pipeline at lower conceptual overhead. Learn the system first, then the production distribution framework.

## 7. Zynq is both differentiator and schedule trap

Vivado/tool/version/boot-chain/FPGA/Linux integration failures can consume large blocks of time.

Therefore:

- Project 3 must independently prove standard Linux Driver skill.
- Project 4 uses Zynq to differentiate.
- Failure to finish AXI DMA v2 must **not** invalidate internship readiness.

## 8. Raspberry Pi 5 should not be forced to serve every lab

Keep Pi 5 for Linux, kernel build, tracing, modules and general experiments.

For a single additional canonical driver-lab board, evaluate BeaglePlay because current Bootlin driver labs explicitly support it. Do not buy multiple boards without a defined experiment.

## 9. Software-quality engineering is underweighted

Add continuously:

- strict warnings;
- sanitizers;
- static analysis;
- error paths;
- fault injection;
- tests;
- CI;
- regression;
- code review;
- `git bisect`;
- patch discipline.

These distinguish an engineering project from a tutorial reproduction.

## 10. C++ should not remain zero

Do not turn the curriculum into C++-first.

Before internship, target approximately L2:

- references;
- object lifetime/basic RAII;
- `std::string/vector`;
- smart-pointer concepts;
- basic STL;
- ability to read templates and modify embedded/system C++.

This is enough to reduce job-screening risk without stealing the C/kernel main line.

## 11. Upstream contribution must not become a vanity KPI

The Gate should require the workflow:

`find subsystem guidance -> make a justified change -> build/test -> style/checkpatch as applicable -> commit message -> format patch/PR -> review response`.

A merged patch is a bonus, not a course pass condition.

## 12. Job-sample limitations

The current Mainland China primary-source sample is strong for Kylinsoft and OPPO, but it is not broad enough to claim market-wide percentages across all semiconductor, automotive, robotics and industrial-control employers. Future quarterly refresh should add more official JD samples from mainland chip/AI-chip/automotive/robotics companies when stable, accessible official job pages are available.

Do not convert the qualitative matrix in this report into precise percentages without a larger coded dataset.

---

## Known Unverified Items

- No proposed baseline task has been executed by the learner yet.
- No proposed project has been built from this research package.
- No BeaglePlay purchase is authorized by this package; it is a recommendation to evaluate.
- Exact Linux 6.18.y **tutorial patch version** remains intentionally unset until lab validation.
- xv6 exact commit remains intentionally unset until the selected 6.1810 labs are frozen.
- License strings above are project-level guidance; each copied code excerpt or vendored component must still receive per-file/per-component license review.
- The job matrix is qualitative and evidence-weighted, not a market census.

## Researcher Recommendation

**APPROVE the career direction, but require MAJOR REVISION of the schedule before canonicalization.**

The central change is:

`Foundations + architecture spine -> RTOS mechanism -> Embedded Linux early -> Linux Driver early -> real subsystem driver -> BSP -> Zynq co-design`.

The pre-internship goal should be **verified capability across a small number of deep chains**, not completion of every advanced embedded topic.
