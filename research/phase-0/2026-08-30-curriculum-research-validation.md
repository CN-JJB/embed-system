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

## Revision Changelog — Leader Review v1.2

Review result addressed: **MAJOR REVISION**.

This revision intentionally preserves the existing research/resource/source work and changes only the reviewed scope:

1. **Job-market evidence language:** replaced market-like China/International frequency labels with sampled-role signal labels; explicitly prohibits interpreting them as market percentages.
2. **2027 scope/budget:** introduced MUST / SHOULD / STRETCH; reduced mandatory planned work to **330 h** and preserved **120–150 h (26.7–31.3%)** unscheduled capacity under the 450–480 h gross assumption.
3. **Proficiency claims:** replaced broad L4 claims with scope-aware levels; overall Linux Driver is **L3**, selected device/MMIO/debug chains may earn **L4-local** only under explicit independent-task/fault/debug/trade-off criteria.
4. **Board selection:** removed any early purchase recommendation; BeaglePlay is now only one candidate in a future board-selection research task that must compare existing hardware first.
5. **Gate decoupling:** Zynq capstone, Yocto orientation, upstream patch workflow, C++ L2, additional xv6 labs, deep U-Boot/Buildroot and deep perf/ftrace are non-blocking SHOULD items.

**Source Ledger is retained.** No new runtime/hardware verification is claimed.

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

From 2026-09 to 2027-06, a nominal 2 h/day budget is about 600 hours. For planning, use a conservative **450–480 h gross available capacity**, but schedule only **330 mandatory hours**. This deliberately preserves **120–150 h (26.7–31.3%) unscheduled capacity** for school workload, failed experiments, repeated Gates, hardware faults, project rework and internship activity.

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

## Evidence language

This revision deliberately **does not use market-frequency labels** such as "China Frequency = Very High / High / Medium."

The current official-JD set is a qualitative, purposefully sampled role-family dataset, not a census and not large enough to support market-share or frequency claims. The two evidence columns therefore mean only:

- **Repeated in sampled roles** — explicitly appears as a core/required responsibility in multiple sampled official roles in that geography;
- **Present in sampled roles** — explicitly appears in at least one sampled official role;
- **Role-specific in sample** — appears mainly in a narrower BSP/kernel/SoC/firmware subset;
- **Not established by current sample** — the current sample is insufficient to make even a qualitative repeated-signal claim.

These labels describe **observed sampled evidence only**. They do not represent overall employer percentages, hiring-market prevalence, or probability of being tested in an interview.

| Skill | Observed Signal in Sampled China Roles | Observed Signal in Sampled International Roles | Typical Depth Signal from Sample | Career Value for Target Path | Recommended Pre-internship Scope |
|---|---|---|---|---|---|
| C | Repeated in sampled roles | Repeated in sampled roles | implementation + debugging | 5/5 | **L3 overall; L4-local for memory/debug scope** |
| C++ | Repeated in sampled roles | Repeated in sampled roles | role-dependent | 4/5 | **L1 MUST; L2 SHOULD** |
| Linux userspace | Repeated in sampled roles | Repeated in sampled roles | use + system debugging | 5/5 | **L3** |
| Git/build workflow | Present in sampled roles | Repeated/present in sampled roles | normal engineering workflow | 4/5 | **L3** |
| Debugging/root cause | Repeated in sampled roles | Repeated in sampled roles | independent fault isolation | 5/5 | **L3 -> L4-local on defined fault classes** |
| RTOS | Repeated in firmware/embedded sampled roles | Present in sampled firmware roles | scheduler/sync/interrupt/timing | 4/5 | **L3 mechanism scope** |
| OS fundamentals | Repeated in sampled roles | Repeated in sampled roles | explain execution mechanisms | 5/5 | **L3 selected mechanisms** |
| Linux Kernel | Repeated in target sampled roles | Repeated in target sampled roles | source navigation, build, debug, APIs | 5/5 | **L2-L3 overall** |
| Linux Driver | Repeated in target sampled roles | Repeated in target sampled roles | real subsystem/device integration | 5/5 | **L3 overall; L4-local on one selected device chain** |
| BSP | Present/repeated in target sample | Repeated in BSP/platform sample | boot/integration/bring-up | 5/5 | **L2-L3** |
| Board bring-up | Present in sampled low-level roles | Repeated in BSP/platform sample | HW/SW boundary debugging | 5/5 | **L3 on scoped board tasks** |
| Device Tree | Present in Linux/BSP sample | Present/repeated in Linux/BSP sample | describe resources + driver matching | 4.5/5 | **L3** |
| Bootloader / U-Boot | Present in BSP sample | Repeated in BSP sample | boot-chain understanding; porting at higher levels | 4/5 | **L2 MUST; deeper work SHOULD** |
| ARM architecture | Repeated/present in sampled roles | Repeated in sampled roles | architecture + low-level integration | 5/5 | **L2-L3 essential spine** |
| RISC-V | Role-specific in sample | Role-specific in sample | architecture/platform specialization | 4/5 strategic | **L2 selected concepts** |
| MMIO/registers | Repeated in embedded/low-level sample | Repeated in low-level sample | implementation + fault isolation | 5/5 | **L4-local** |
| Interrupt/exception | Repeated/present in low-level sample | Repeated in low-level sample | mechanism + debug | 5/5 | **L3** |
| DMA | Present in sampled embedded roles | Present/role-specific in platform sample | device/data-path integration | 4.5/5 | **L2-L3; advanced DMA post-gate** |
| Cache/MMU/TLB | Present in kernel/platform sample | Repeated/present in kernel/platform sample | mechanism + performance reasoning | 5/5 | **L2-L3** |
| Memory ordering/coherency | Role-specific in sample | Role-specific/repeated in SoC sample | advanced platform reasoning | 5/5 long-term | **L1-L2 MUST concepts; deeper SHOULD/STRETCH** |
| I2C/SPI/UART | Repeated in sampled embedded roles | Present/repeated in embedded roles | use + debug + driver integration | 4/5 | **L3 overall; selected chain may be L4-local** |
| USB/Ethernet | Present in sampled embedded roles | Present in sampled roles | role-dependent driver/BSP work | 4/5 | **L1-L2** |
| PCIe | Role-specific in sample | Role-specific in platform/AI sample | advanced platform/driver work | 4.5/5 | **STRETCH** |
| DDR | Role-specific in sample | Role-specific in platform sample | bring-up/performance specialization | 4/5 | **STRETCH** |
| JTAG/SWD | Present in sampled roles | Present/repeated in BSP sample | bring-up/debug | 4.5/5 | **L3 on available hardware** |
| Scope/logic analyzer | Present in sampled roles | Present in sampled embedded roles | HW/SW evidence collection | 4.5/5 | **L3** |
| perf/ftrace/trace tools | Not established as repeated | Present/role-specific in kernel/perf sample | performance/kernel debugging | 4/5 | **basic exposure SHOULD; depth post-gate** |
| Buildroot | Not established as repeated | Role-specific in embedded Linux ecosystem | image/build integration | 3.5/5 | **L2-L3 shallow MUST** |
| Yocto/OpenEmbedded | Not established as repeated | Repeated/present in BSP vendor sample | production BSP/distribution engineering | 4/5 | **SHOULD orientation; deeper post-gate** |
| Upstream workflow | Present as differentiator | Repeated/present in Linux vendor sample | patch/review/mainline collaboration | 5/5 differentiator | **SHOULD** |
| FPGA / HW-SW co-design | Role-specific in sample | Role-specific in SoC sample | differentiation for platform roles | 4.5/5 | **SHOULD** |
| Secure Boot | Not established by current sample | Role-specific in platform sample | security/platform specialization | 4/5 later | **STRETCH** |
| Virtualization | Not established by current sample | Role-specific in platform sample | advanced platform software | 4/5 later | **STRETCH** |
| Testing/static analysis/CI | Often implicit; present | Present/repeated as engineering expectation | engineering quality | 4/5 | **L3 within projects** |
| Data structures/algorithms | Repeated/present in campus sample | Common interview foundation; sample not census | interview implementation/reasoning | 4/5 | **L2-L3 selected set** |
| Technical English | Not directly measurable from China sample | Implicitly required by international roles | documentation/collaboration | 4.5/5 | **L2-L3** |

### Interpretation

The matrix is a curriculum-alignment instrument, not labor-market statistics.

Before internship season, prioritize the dependency chain:

`C -> Linux fundamentals -> debugging -> ABI/exception/MMIO -> RTOS mechanisms -> Linux boot chain -> kernel fundamentals -> one real subsystem driver -> interview fundamentals`.

High-value topics such as Yocto, Zynq co-design, upstream contribution, PCIe and DDR must not become mandatory merely because they appear in valuable roles.

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
- **Scope before internship:** Zynq AXI4-Lite + interrupt is **SHOULD**, not an Internship Gate requirement; AXI DMA/coherency is STRETCH.

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

# Part 7 — Roadmap v1.2

## 7.1 Scope classes

This revision separates curriculum value from **Internship Gate criticality**.

### MUST — Internship Gate

If these outcomes are not completed, the learner is not considered ready for serious 2027 Linux/BSP/Driver internship applications.

| MUST area | Minimum pre-internship scope | Mandatory planned hours |
|---|---|---:|
| System C + toolchain | pointer/lifetime, memory, UB, struct/layout/endian, callbacks, compilation/linking/ELF, GDB/sanitizers | 45 |
| Linux fundamentals | files/FD, process, pipe, signal, pthread basics, `/proc`, `/sys`, `strace`, basic socket/IPC | 45 |
| Debugging methodology | repeated AI-Free/AI-limited root-cause exercises across C, Linux, RTOS and driver faults | 30 |
| Essential architecture spine | calling convention/ABI, privilege, exception/trap, MMIO, cache/TLB/VM basics, ordering concepts | 30 |
| STM32 + FreeRTOS mechanisms | startup/vector/IRQ/timer/DMA basics; scheduler/context switch/sync/inversion/stack/timing | 35 |
| Embedded Linux boot chain | cross-build, kernel, BusyBox/rootfs/init, QEMU/real-board boot, basic DT, shallow Buildroot use | 30 |
| Linux Kernel fundamentals | configure/build, module/Kbuild, source navigation, driver model, resources, kernel logs/oops | 30 |
| One real Linux subsystem driver | one bounded I2C/SPI/GPIO-class device chain with DT, probe/resources, sync/error path, verification | 55 |
| Interview + portfolio fundamentals | selected DSA, C/OS/Linux/driver review, technical explanation, project evidence cleanup | 30 |
| **Total MUST planned** |  | **330 h** |

### SHOULD — Differentiator

These are valuable but **must not block the Internship Gate**. They are a prioritized backlog, not an additional committed 2027-06 schedule.

| SHOULD item | Recommended scope before internship if schedule is healthy |
|---|---|
| Zynq AXI capstone | AXI4-Lite + IRQ + DT + Linux driver v1; no DMA requirement |
| Yocto orientation | understand layer/recipe/BitBake model; optionally build or modify one small recipe |
| Upstream patch workflow | perform one realistic patch/PR/mail-format workflow; merge/acceptance not required |
| C++ L2 | references, lifetime/RAII, basic STL, reading/modifying system C++ |
| Additional xv6 work | beyond the two MUST selected mechanism exercises |
| Deeper U-Boot | source reading, board porting, driver-model exploration |
| Deeper Buildroot | custom package/board integration beyond basic image/config workflow |
| perf/ftrace depth | trace analysis/performance investigation beyond basic kernel logs/debug |
| Additional subsystem driver | second device/subsystem to broaden transferability |
| Zynq/FPGA measurement polish | ILA/tracing/benchmark work after the driver Gate is safe |

**Scheduling rule:** before June 2027, select SHOULD work only when the rolling unscheduled buffer remains at or above 20%. Do not attempt to "complete all SHOULD items."

### STRETCH — Post-gate

Default to 2027 summer or later:

- AXI DMA and deeper Linux DMAengine;
- cache-coherency experiments beyond essential concepts;
- deep Yocto/OE BSP engineering;
- PCIe;
- DDR bring-up/tuning;
- secure boot;
- virtualization/hypervisor;
- deep Zephyr ecosystem work;
- CAQA advanced chapters;
- advanced kernel performance engineering;
- large SoC-generator ecosystems.

## 7.2 Explicit decisions on disputed pre-internship items

| Item | Classification | Decision |
|---|---|---|
| Zynq AXI capstone | **SHOULD** | strong differentiator, but schedule/tool risk makes it non-blocking |
| Yocto orientation | **SHOULD** | useful BSP signal; not needed to prove the core driver chain |
| upstream patch workflow | **SHOULD** | high-value differentiator; not a Gate prerequisite |
| C++ L2 | **SHOULD** | C++ reading literacy is useful; C/kernel fundamentals take priority |
| xv6 labs | **MUST: two selected mechanism exercises only** | one trap/syscall-oriented + one VM/concurrency-oriented exercise; more is SHOULD |
| U-Boot depth | **MUST shallow / SHOULD deep** | MUST explain boot stages and operate basic boot/env flow; source/porting depth is optional |
| Buildroot depth | **MUST shallow / SHOULD deep** | MUST create/modify a reproducible embedded image; custom package/board depth optional |
| perf/ftrace depth | **SHOULD** | MUST can use kernel logs/oops/dynamic debug; deeper tracing/perf analysis is optional |

## 7.3 Capacity and buffer

Use a conservative **450–480 h gross available capacity** for 2026-09 → 2027-06.

Do **not** schedule all of it.

- MUST planned: **330 h**
- Unscheduled capacity at 450 h gross: **120 h = 26.7%**
- Unscheduled capacity at 480 h gross: **150 h = 31.3%**
- SHOULD work: consume only from buffer that remains healthy after Gate rework, school load and project slips.

This satisfies the minimum 20–25% buffer requirement and leaves enough room for a **2–3 week major-project delay (~25–35 h)** without automatically sacrificing the core Gate.

Buffer is intentionally reserved for:

- Gate failure/retry;
- debugging;
- school exams/deadlines;
- hardware failure;
- project rework;
- documentation;
- internship applications/interviews.

## 7.4 Monthly MUST schedule

| Month | MUST focus | Planned MUST hours | Non-blocking SHOULD only if ahead |
|---|---|---:|---|
| **2026-09** | Baseline; System C memory/lifetime/UB; GDB/sanitizers; ABI/calling-convention start | 36 | none |
| **2026-10** | Linux FD/process/pipe/signal; `/proc`/`strace`; compile/link/ELF; compact systems program | 38 | C++ reading warm-up |
| **2026-11** | STM32 startup/vector/IRQ/timer/DMA basics; FreeRTOS scheduler/context/sync/inversion/stack | 34 | none |
| **2026-12** | QEMU/kernel/rootfs/BusyBox; basic DT; shallow Buildroot; privilege/exception/MMIO spine | 32 | extra architecture reading |
| **2027-01** | two selected xv6 mechanism exercises; module/Kbuild; driver model/platform resources; kernel logs/oops | 34 | deeper xv6 |
| **2027-02** | real-driver core: DT/matching, I2C/SPI or GPIO path, resources, synchronization, error paths | 38 | basic ftrace exposure |
| **2027-03** | Project 3 real subsystem driver implementation, fault injection, userspace verification | 42 | second driver only if P3 Gate is green |
| **2027-04** | Project 3 hardening/rework; boot-chain review; shallow U-Boot/Buildroot operation; portfolio evidence | 32 | Yocto orientation / upstream workflow |
| **2027-05** | internship interview fundamentals + reserved Project 3 spill/retry capacity | 24 | **Zynq v1 may start only if MUST Gates are green** |
| **2027-06** | final Internship Gate, project documentation, applications/interviews | 20 | continue Zynq/C++ only if non-blocking |
| **Total** |  | **330 h** |  |

### Acceptance criterion for schedule robustness

A 2–3 week delay in Project 3 must be absorbable by April/May buffer without:

- deleting the real subsystem-driver Gate;
- skipping C/Linux/debugging fundamentals;
- compressing final interview preparation to near zero;
- requiring Zynq/Yocto/C++/upstream work to be completed first.

If that condition stops being true, **SHOULD work is dropped before MUST work is compressed**.

## 7.5 Scope-aware proficiency matrix

Levels are scoped to a defined task family. A successful project does **not** imply global L4 mastery of a field.

| Skill area | Pre-internship target | Scope boundary |
|---|---|---|
| System C overall | **L3** | explain and use core C/toolchain mechanisms across normal systems tasks |
| C pointer/lifetime/memory debugging | **L4-local** | bounded native-C memory faults and ownership/lifetime reasoning |
| Linux userspace | **L3** | process/FD/IPC/signal/debug workflow; not full POSIX breadth |
| Debug methodology | **L3 -> L4-local** | defined C/Linux/RTOS/driver fault families |
| Essential computer architecture | **L2-L3** | ABI, privilege, exception, MMIO, cache/TLB/VM essentials; not full microarchitecture |
| FreeRTOS overall | **L3** | scheduler/context/synchronization/interrupt/timing mechanisms |
| Embedded Linux boot chain | **L3** | kernel/rootfs/init/DT/basic Buildroot boot path; not distribution engineering |
| Linux Kernel architecture | **L2-L3** | build/navigation/modules/driver model/basic debug; not broad subsystem internals |
| Linux Driver overall | **L3** | can implement/explain one subsystem chain and transfer concepts with documentation |
| Selected I2C/hwmon (or equivalent approved) device chain | **L4-local** | one explicitly bounded device + subsystem implementation/debug path |
| Device Tree | **L3** | hardware description, matching/resources, basic binding validation |
| MMIO/register interaction | **L4-local** | selected MCU/SoC/peripheral scope |
| Interrupt handling | **L3** | MCU + selected Linux-driver path; not every interrupt architecture |
| DMA | **L2-L3** | STM32/basic data path; Linux DMAengine depth is post-gate |
| Cache/MMU/TLB | **L2-L3** | explain core mechanism and common implications |
| U-Boot | **L2** | boot flow/env/basic operation; porting is SHOULD |
| Buildroot | **L2-L3** | configure/build/inspect image pipeline; deep package/board work is SHOULD |
| Git | **L3** | branch/commit/rebase/conflict/bisect/review workflow |
| DSA/interview algorithms | **L2-L3** | selected standard data structures/problems |
| Technical English | **L2-L3** | read docs/JDs and explain project; not professional writing mastery |
| C++ | **L1 MUST / L2 SHOULD** | reading literacy first; no C++-heavy project required |
| Zynq co-design | **SHOULD, L2-L3 if completed** | not part of Internship Gate |

### L4 / L4-local qualification criteria

An L4-local label is granted only when **all five** columns below are satisfied.

| L4-local scope | Scope | Independent Task | Fault Scenario | Expected Debug Ability | Design Trade-off Question |
|---|---|---|---|---|---|
| C pointer/lifetime/memory | native C program/component with dynamic/static storage, structs, callbacks | implement and review ownership/lifetime without AI solution generation | delayed heap overwrite, UAF/dangling pointer or alias/lifetime bug | form hypotheses; use GDB/sanitizer/watchpoints as appropriate; identify root cause; add regression | API ownership vs copying; stack vs heap; safety vs complexity |
| MMIO/register interaction | one STM32 peripheral or one approved SoC MMIO block | configure/access the device from documentation and explain accessor/volatile assumptions | wrong clock/reset/bitfield/order/IRQ acknowledgment causing non-operation or repeated IRQ | correlate register state + scope/JTAG/log evidence and isolate HW vs SW configuration | polling vs interrupt; register abstraction vs direct control; ordering/barrier cost |
| Selected Linux subsystem driver chain | one approved I2C/hwmon, SPI/IIO, GPIO or equivalent bounded chain | implement DT + probe/resources + subsystem registration + userspace validation from upstream/docs | bad DT property, bus error, IRQ/sync bug, error-path/resource issue, or incorrect register handling | use kernel logs plus appropriate bus/trace/hardware evidence; localize fault across DT/bus/driver/userspace boundaries | subsystem choice; regmap vs direct access; mutex/spinlock/workqueue; polling vs IRQ |
| Debug methodology on defined fault set | required C/Linux/RTOS/driver diagnostic cases | independently run the full `Symptom -> Hypothesis -> Evidence -> Experiment -> Root Cause -> Fix -> Regression` loop | at least three materially different seeded/real failures, including one concurrency/timing or driver-boundary failure | select evidence tools deliberately, reject weak hypotheses, and produce reproducible root-cause report | observability vs perturbation; fastest test vs strongest discriminating experiment |

**Prohibited inference:** completing one I2C/hwmon driver at L4-local does not justify "Linux Driver = L4." Overall Linux Driver remains L3 until competence transfers across multiple unfamiliar subsystems and design contexts.

## 7.6 Future Board Selection Research Task

**Status:** future research task. This report makes **no canonical purchase decision**.

**Trigger:** run before Project 3 hardware is frozen, after its exact subsystem/device/lab requirements are known.

### Required candidates

Compare at minimum:

1. existing Raspberry Pi 5;
2. existing K230-class board;
3. existing Zynq-7020;
4. BeaglePlay **as a candidate only**;
5. at most 1–2 additional boards, and only when there is a documented reason they may close a specific gap.

### Required comparison fields

| Criterion | Question to answer |
|---|---|
| mainline Linux support | what works in the target mainline/LTS baseline without large downstream dependency? |
| upstream friendliness | can examples map cleanly to upstream kernel APIs/subsystems and normal patch workflow? |
| schematics availability | are complete, usable schematics publicly available? |
| TRM/documentation | is SoC/peripheral documentation sufficient for bring-up/debug? |
| U-Boot | what is upstream support status and boot-path transparency? |
| Device Tree | are upstream DTS/bindings available and understandable? |
| UART/JTAG/debug access | what low-level recovery/debug channels are practically exposed? |
| I2C/SPI/GPIO/IRQ accessibility | can Project 3 attach/debug a real peripheral without awkward expansion hardware? |
| Buildroot support | is there direct or low-friction support? |
| Yocto support | is there a maintained BSP/layer if later needed? |
| Bootlin/course ecosystem | are current high-quality labs/materials available for the board/SoC? |
| cost | total board + required debug/adapter cost |
| overlap with existing hardware | does the new board add capability or mostly duplicate current equipment? |

### Decision rule

Prefer an **existing board** when it satisfies the Project 3 requirements with acceptable upstream/documentation/debug friction.

A purchase may be proposed only if the comparison identifies a concrete capability or teaching-maintenance gap that existing hardware cannot reasonably close. BeaglePlay has no privileged status beyond being one candidate with current teaching ecosystem support.

### Deliverable before any purchase

Produce:

- evidence table with source/date/version for each board;
- known blockers;
- project-specific lab fit;
- maintenance risk;
- cost/overlap analysis;
- recommendation: `use existing`, `purchase justified`, or `defer decision`.

No board purchase is authorized by this Phase 0 package.

---

# Part 8 — Project Ladder

## Original project audit

| Original project | Verdict |
|---|---|
| Linux C telemetry daemon | keep, but make it a systems-engineering project rather than "sensor + socket" |
| STM32 + FreeRTOS data node | keep; require measurable scheduler/concurrency/debug evidence |
| Custom peripheral + Linux Driver | too ambiguous and can duplicate Zynq |
| Zynq AXI + Linux Driver | high value, but risky/too complex as the only driver proof |

## Project 1 — Linux Systems Telemetry Service — MUST (bounded)

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

## Project 2 — STM32 FreeRTOS Acquisition Node — MUST (bounded)

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

## Project 3 — Real Peripheral Linux Driver — MUST / Gate project

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

This is the **primary pre-internship Linux Driver Gate project**. Scope must remain bounded enough that a 2–3 week delay can be absorbed without sacrificing the Internship Gate.

## Project 4 — Zynq AXI Co-design Capstone — SHOULD differentiator

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

This Gate tests only **MUST** scope. SHOULD/STRETCH items may strengthen a portfolio but cannot compensate for a failed MUST Gate and are not required to pass.

## C / Toolchain — overall L3, memory/debug L4-local

AI-Free learner must:

- implement a bounded C component with clear ownership/lifetime;
- correctly use pointers, structs, callbacks and storage duration;
- explain common UB and layout/endian issues;
- debug a memory fault with evidence;
- use `readelf/nm/objdump` on a small program;
- explain compile → assemble → link at mechanism level.

Pass requires the scoped L4-local memory-debug criteria from Part 7; it does **not** claim whole-language L4.

## Linux userspace — L3

Must independently:

- use/debug files and FDs;
- implement `fork/exec/wait`;
- connect processes with pipe/FD redirection;
- handle a signal safely at basic level;
- use pthread synchronization at basic level;
- use `/proc`, `/sys`, `strace`;
- demonstrate one basic IPC/socket path.

Given a hang, FD leak or process-lifecycle bug, the learner must collect evidence and reach root cause without direct AI solution generation.

## Debugging — L3 -> L4-local on required cases

Maintain at least four formal root-cause reports covering:

1. C memory corruption/lifetime;
2. Linux userspace process/FD failure;
3. RTOS concurrency/timing or STM32 peripheral failure;
4. Linux driver/DT/bus/resource failure.

Each report:

`Symptom -> Hypotheses -> Evidence -> Experiment -> Root Cause -> Fix -> Regression`.

At least **two** must be fully AI-Free. At least one must involve concurrency/timing or a HW/SW boundary.

## Essential architecture / OS — L2-L3

Must explain and connect to observed execution:

- function call, PC/SP and ABI basics;
- privilege and exception/trap;
- syscall boundary;
- process/thread;
- virtual address, page table and TLB basics;
- cache/locality basics;
- MMIO;
- interrupt control flow;
- basic ordering/coherency concepts relevant to device access.

### xv6 requirement

Only **two selected mechanism exercises are MUST**:

- one syscall/trap/control-flow exercise;
- one VM **or** concurrency/locking exercise.

Additional xv6 labs are SHOULD.

## STM32 + FreeRTOS — L3

Must:

- explain reset/startup/vector-table path;
- configure or meaningfully modify timer/interrupt/DMA behavior from RM evidence;
- explain preemptive scheduling/context switch;
- build an ISR→task data path;
- choose queue/semaphore/mutex appropriately;
- reproduce and explain priority inversion/inheritance;
- measure stack usage;
- debug one timing/stack/concurrency fault;
- collect at least one physical timing observation with scope/logic instrumentation where practical.

## Embedded Linux boot chain — L3 bounded scope

Must:

- cross-build or use a defined cross toolchain;
- configure/build a kernel baseline;
- boot Linux in QEMU;
- boot one real supported board;
- build/use a BusyBox/rootfs or equivalent minimal userspace;
- explain kernel → rootfs/init flow;
- read and modify a basic Device Tree node;
- use Buildroot to produce/reproduce one image/configuration.

Not required for Gate:

- custom Buildroot board/package depth;
- Yocto;
- full U-Boot porting.

## U-Boot — L2 bounded scope

Must:

- explain where U-Boot sits in the selected board's boot chain when applicable;
- inspect/basic-use boot environment and boot commands;
- connect kernel/DT/rootfs artifacts to the boot flow.

Source-level U-Boot driver/board porting is SHOULD.

## Linux Kernel — L2-L3

Must:

- configure/build a pinned kernel;
- build/load a module;
- use basic Kbuild;
- navigate source/docs to answer an API/mechanism question;
- understand driver-model/platform-resource basics;
- read a kernel oops/backtrace;
- use kernel logs and dynamic debug or equivalent basic debug facility.

Deep perf/ftrace analysis is **not** a Gate requirement.

## Linux Driver — L3 overall; one device chain L4-local

Hard Gate:

complete **one approved real subsystem-driver chain** (for example I2C + hwmon, SPI + IIO, GPIO expander, or equivalent) demonstrating:

- DT description/matching where relevant;
- `probe()` and managed resources;
- bus/MMIO access;
- subsystem registration;
- synchronization/error handling appropriate to the device;
- IRQ path if the selected device meaningfully supports it;
- userspace verification;
- at least one injected/real fault diagnosed to root cause.

Pass requires the Part 7 L4-local driver criteria.

The learner must answer design questions such as:

- why this subsystem instead of a misc/char interface?
- regmap or direct access, and why?
- mutex/spinlock/workqueue/polling/IRQ — what trade-off applies here?
- what belongs in Device Tree versus driver policy?
- how would the design change for a second device with different timing/interrupt constraints?

**Passing this Gate means Linux Driver overall L3 + selected-chain L4-local, not global Linux Driver L4.**

## Hardware/debug instrumentation — L3

Within the selected boards/projects, must:

- read schematic and datasheet/RM;
- identify power/clock/reset/pins relevant to a fault;
- inspect I2C/SPI/UART or interrupt behavior when applicable;
- use multimeter/scope/logic/JTAG/SWD evidence where it discriminates hypotheses;
- trace one HW signal/configuration issue into software behavior.

No requirement to demonstrate broad board-bring-up mastery across multiple SoCs.

## Git / engineering workflow — L3

Must demonstrate actual use of:

- feature branch;
- atomic commits;
- rebase or equivalent history cleanup;
- conflict resolution;
- `git bisect` on a seeded or real regression;
- PR/review revision;
- release/tag or reproducible milestone.

An upstream Linux/U-Boot/Buildroot contribution is **SHOULD**, not Gate-required.

## Algorithms / interview fundamentals — L2-L3

Must handle a selected set covering:

- array/string;
- linked list;
- stack/queue;
- hash table;
- binary search;
- bit operations;
- basic tree/BFS/DFS;
- Big-O reasoning.

Target roughly **20–30 curated easy/medium problems**, adjusted downward if interview performance is already clearly demonstrated. Problem count is not the Gate by itself.

## Technical English — L2-L3

Must:

- read kernel/device documentation without full translation;
- read an English JD;
- write a concise English README section or root-cause summary;
- explain the selected driver architecture in English for approximately 5 minutes.

Reading mailing-list RFC/patch discussion is useful but belongs to SHOULD/upstream-workflow scope.

## Portfolio minimum

MUST evidence:

1. one Linux systems-programming artifact or compact project showing process/FD/debug capability;
2. one measured STM32/FreeRTOS artifact;
3. **one real Linux subsystem driver project** with root-cause evidence.

Every serious artifact should include:

- build/reproduction instructions;
- architecture/data-flow explanation;
- test or verification plan;
- at least one debug story;
- known limitations;
- clean enough Git history to review.

### Non-blocking differentiators

The following strengthen the portfolio but are **not required to pass**:

- Zynq AXI capstone;
- Yocto orientation;
- upstream contribution workflow;
- C++ L2;
- additional xv6 labs;
- deep U-Boot/Buildroot work;
- deeper perf/ftrace analysis.

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

## 8. Board choice must remain an evidence task, not a purchase conclusion

Do not force Raspberry Pi 5, K230 or Zynq-7020 to serve every lab, but also do not assume a new board is required.

Before Project 3 hardware is frozen, run the **Future Board Selection Research Task** defined in Part 7. It must compare the existing Raspberry Pi 5, K230-class board and Zynq-7020 against BeaglePlay and at most 1–2 justified additional candidates.

BeaglePlay is only a **candidate**. No canonical purchase recommendation is made in this report.

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

C++ L2 is a **SHOULD differentiator**, not an Internship Gate requirement. If schedule health allows, target approximately L2:

- references;
- object lifetime/basic RAII;
- `std::string/vector`;
- smart-pointer concepts;
- basic STL;
- ability to read templates and modify embedded/system C++.

This is enough to reduce job-screening risk without stealing the C/kernel main line.

## 11. Upstream contribution must not become a vanity KPI

A SHOULD-level upstream exercise should demonstrate the workflow:

`find subsystem guidance -> make a justified change -> build/test -> style/checkpatch as applicable -> commit message -> format patch/PR -> review response`.

A merged patch is a bonus. The entire upstream exercise is non-blocking for the Internship Gate.

## 12. Job-sample limitations

The current Mainland China primary-source sample is strong for Kylinsoft and OPPO, but it is not broad enough to claim market-wide percentages across all semiconductor, automotive, robotics and industrial-control employers. Future quarterly refresh should add more official JD samples from mainland chip/AI-chip/automotive/robotics companies when stable, accessible official job pages are available.

Do not convert the qualitative matrix in this report into precise percentages without a larger coded dataset.

---

## Known Unverified Items

- No proposed baseline task has been executed by the learner yet.
- No proposed project has been built from this research package.
- No board purchase is authorized or recommended by this package; BeaglePlay is only one candidate for the future board-selection study.
- Exact Linux 6.18.y **tutorial patch version** remains intentionally unset until lab validation.
- xv6 exact commit remains intentionally unset until the selected 6.1810 labs are frozen.
- License strings above are project-level guidance; each copied code excerpt or vendored component must still receive per-file/per-component license review.
- The job matrix is qualitative and evidence-weighted, not a market census.

## Researcher Recommendation — v1.2

**APPROVE the revised Phase 0 research package for Leader canonicalization work.**

The validated pre-internship main chain is:

`Foundations + architecture spine -> RTOS mechanisms -> Embedded Linux boot chain -> Kernel fundamentals -> one real subsystem driver -> interview/portfolio Gate`.

Zynq co-design remains a high-value **SHOULD** differentiator after the MUST chain is safe.

The pre-internship goal remains **verified capability across a small number of deep chains**, not completion of every advanced embedded topic.
