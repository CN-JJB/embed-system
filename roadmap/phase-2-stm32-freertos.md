# Phase 2 — STM32 + FreeRTOS Mechanisms

> Status: **Execution blueprint — Leader review required**  
> Recommended duration: **4 weeks** (3-week Fast Track / 5-week remediation variants)  
> Core modules + project: **~31.0 h MUST**  
> Final Gate: **~3.5 h MUST**  
> Total mandatory planned load: **~34.5 h MUST** (strictly bounded within the canonical ~34–35 h envelope)  
> Weekly planned load: **~8.5–9.5 h average**, preserving meaningful unscheduled buffer for hardware/probe debugging  
> Full research/evidence: `research/phase-2/2026-09-03-stm32-freertos-curriculum-design.md`

---

## Exit capability

Phase 2 is complete when the learner can independently:

- reason about MCU reset, vector table fetch, `.data` copy, `.bss` zeroing, runtime initialization (`__libc_init_array()`), and startup-to-`main()` execution from linker script and assembly source;
- explain Cortex-M3 execution states, Thread vs Handler mode, MSP vs PSP, exception entry/exit stacking (`{r0-r3, r12, lr, pc, xpsr}`), and `EXC_RETURN` codes;
- configure and diagnose peripheral memory-mapped registers (MMIO) using direct CMSIS register structs, reason about `volatile` semantic limits, avoid read-modify-write (RMW) hazards using atomic bit registers (BSRR/BRR), and handle memory ordering/write-buffering barriers (`DSB`/`ISB`);
- calculate timer prescalers/periods from the internal clock tree, configure NVIC interrupt priorities, distinguish CMSIS logical priority from encoded hardware priority bytes, and prevent interrupt storms;
- construct an autonomous hardware data acquisition path using Timer 3 TRGO update triggers, calibrated ADC1 regular external triggering (`EXTSEL = 0b100`), valid ADC clock prescaling (`ADCPRE = /6` yielding 12 MHz ADCCLK $\le 14\text{ MHz}$), sample-time selection matched to source impedance, and DMA1 Channel 1 circular double-buffering without CPU polling;
- explain FreeRTOS kernel scheduling mechanics: ready/delayed/pending-ready task state lists, tick processing (`xTaskIncrementTick`), and the PendSV context switch mechanism (`{r4-r11}` software stacking on PSP);
- implement robust ISR-to-task handoffs using queues, audit NVIC priority settings against `configMAX_SYSCALL_INTERRUPT_PRIORITY`, and use `portYIELD_FROM_ISR`;
- distinguish mutexes from binary semaphores, reproduce and resolve priority inversion using priority inheritance in a controlled 3-task experiment with identical CPU workloads, and audit code for deadlock;
- monitor task runtime health using stack watermarks (`uxTaskGetStackHighWaterMark`), configure stack overflow hooks (`taskCHECK_FOR_STACK_OVERFLOW`), enforce FreeRTOS `heap_4` as the sole dynamic memory manager (excluding libc heap/`malloc`), and integrate an independent watchdog (IWDG);
- capture physical evidence of system timing (ISR latency, jitter, context switch duration) using GPIO toggles, oscilloscope/logic analyzer probes, and live SWD/GDB register inspection;
- debug complex MCU/RTOS faults using the disciplined hypothesis-driven framework: `Symptom -> Own Description -> Hypotheses -> Evidence -> Narrow Scope -> Root Cause -> Fix -> Regression`.

**Mastery Target**: FreeRTOS mechanisms at **L3**, MMIO/register interaction at **L4-local** on selected MCU/peripherals, interrupt handling at **L3**, basic DMA at **L2–L3**, and debugging at **L4-local** on practiced MCU/RTOS fault families.

---

## Course shape

MCU bare-metal foundations and FreeRTOS mechanisms are tightly sequenced to ensure that no RTOS abstraction is introduced before its underlying architectural mechanism is fully mastered:

```text
reset / startup / linker script  <-> memory layout, vector table, MSP initialization, __libc_init_array
MMIO / clock tree / timers       <-> NVIC priority model, exception entry/return, ADCCLK prescaler
ADC / DMA circular path          <-> autonomous data movement, buffer ownership, ADC calibration
FreeRTOS scheduler / task lists  <-> PendSV, PSP swapping, context switch frame
queue / mutex / ISR handoff      <-> synchronization, priority inheritance, BASEPRI mask
stack watermark / overflow hook  <-> memory safety, task sizing, watchdog recovery, heap_4 exclusivity
Acquisition Node project         <-> integrated, verifiable embedded sensor subsystem
```

Hardware-software debugging begins in Module 1. There is no isolated "RTOS debugging" topic.

---

## Module sequence

| ID | Module | Target | MUST hours | SHOULD hours | Principal Gate |
|---|---|---|---:|---:|---|
| **P2-M01** | Reset, Startup, Linker Script, and Vector Table | L3 / L4-local link & boot faults | 3.5 | 1.0 | Reconstruct minimal startup & linker; execute `__libc_init_array`; diagnose vector table fault |
| **P2-M02** | MMIO, Clock Tree, Hardware Timers, and NVIC Mechanism | L3 / L4-local register & IRQ faults | 4.5 | 1.0 | Bring up timer/clock from RM; diagnose nested IRQ priority & RMW hazards |
| **P2-M03** | Peripheral Acquisition & DMA Data Path | L2–L3 DMA / L4-local peripheral path | 4.5 | 1.0 | Build TIM3-TRGO+ADC+DMA circular buffer; configure ADCPRE & calibration; diagnose DMA stall |
| **P2-M04** | FreeRTOS Scheduler, Task Lifecycle, and Context Switch | L3 FreeRTOS core / L3 Cortex-M port | 5.0 | 1.0 | Walk through `tasks.c` & `port.c`; verify PendSV register stacking in GDB |
| **P2-M05** | Queue, Mutex, and ISR-Safe Synchronization Boundaries | L3 synchronization / L3 ISR handoff | 4.5 | 1.0 | Build ISR-to-Task queue pipeline; audit NVIC vs `configMAX_SYSCALL`; verify mutex vs semaphore |
| **P2-M06** | Priority Inversion, Inheritance, Stack Watermark & Debugging | L3 concurrency / L4-local RTOS faults | 4.0 | 0.5 | Reproduce bounded priority inversion; observe inheritance fix; detect stack overflow |
| **P2-M07** | STM32 FreeRTOS Acquisition Node Integration Project | L3 integrated node | 5.0 | 1.0 | End-to-end multi-task node acceptance; controlled priority inversion test; scope evidence |
| **P2-GATE**| Phase 2 Final Gate Assessment | L3 transfer / L4-local diagnostic | 3.5 | 0.0 | AI-Free 4-part transfer exam (Startup, DMA, Scheduler, Concurrency/HW-SW debug) |

---

## Time Budget Sum Table

| Work Area | Modules Included | MUST Hours | SHOULD Hours | Calendar Allocation |
|---|---|---:|---:|---|
| **MCU Bare-Metal Foundations** | P2-M01, P2-M02, P2-M03 | 12.5 h | 3.0 h | Week 1 & Week 2 (first half) |
| **FreeRTOS Kernel Mechanisms** | P2-M04, P2-M05, P2-M06 | 13.5 h | 2.5 h | Week 2 (second half) & Week 3 |
| **Integrated Project** | P2-M07 (Acquisition Node) | 5.0 h | 1.0 h | Week 4 (first half) |
| **Final Comprehensive Gate** | P2-GATE | 3.5 h | 0.0 h | Week 4 (second half) |
| **Phase 2 Total** | **All 7 Modules + Final Gate** | **34.5 h** | **6.5 h** | **4 Weeks (~8.5–9.5 h/week MUST)** |

> [!NOTE]
> The planned MUST total of **34.5 h** strictly fulfills the ~34–35 h constraint mandated by the Phase 0 curriculum blueprint (2026-11 monthly plan: 34 h). Unscheduled weekly buffer (~4.5–5.5 h/week) protects the schedule against unexpected hardware failures, SWD connection issues, and scope probing setup time.

---

## Mandatory source policy

All curriculum content must derive from primary specifications and authoritative upstream source code:

- **STMicroelectronics Reference Manual RM0008** (DocID 13902 Rev 21, Feb 2021) — Authoritative register definitions, clock tree, NVIC table, Timer 3 TRGO, ADC regular trigger mapping (EXTSEL=0b100), ADC prescaler ($f_{\text{ADC}} \le 14\text{ MHz}$, ADCPRE=/6), ADC calibration sequence (Section 11.4), sample-time vs $R_{\text{AIN}}$ (Section 11.3.11), and DMA1 channel mappings.
- **STMicroelectronics Programming Manual PM0056** (DocID 15491 Rev 7, Dec 2024) — Cortex-M3 processor programming model, core registers (CONTROL, PRIMASK, BASEPRI), NVIC register interface, and SysTick.
- **STMicroelectronics Datasheet DS5319** (DocID 13587 Rev 20, 31 Jul 2025) — STM32F103x8/xB electrical characteristics, pin multiplexing, ADC electrical limits ($f_{\text{ADC}} \le 14\text{ MHz}$, $R_{\text{AIN}}$ table), and memory mapping.
- **Armv7-M Architecture Reference Manual** (ARM DDI 0403E.e) — Exception model, stack alignment, instruction execution states, memory barriers (`DSB`, `ISB`, `DMB`).
- **FreeRTOS-Kernel Upstream** (Release V11.3.0, commit `9b777ae`, MIT License) — Official kernel source for task scheduling, queues, and Cortex-M3 port.
- **CMSIS Core / Device Headers** (CMSIS_5 v5.9.0 / `cmsis_device_f1` v4.3.5; Apache-2.0 component licenses, retaining per-file notices) — core/device register definitions (`core_cm3.h`, `stm32f103xb.h`).
- **Original 64 KB Linker Script Policy:** The teaching linker script (`stm32f103c8tx_flash.ld`) is an original pedagogical work written from GNU ld documentation and the physical STM32F103C8 memory map (64 KB Flash, 20 KB SRAM). It explicitly retains `.preinit_array` and `.init_array` via `KEEP` with standard `PROVIDE_HIDDEN` boundary symbols. The vendor template in ST repositories carries an Ac6 non-redistribution notice and specifies 128 KB Flash; it is strictly a read-only comparison reference and is not redistributed.
- **Runtime & Memory Ownership Policy:** Standardizes on newlib-nano (`--specs=nano.specs --specs=nosys.specs`) with explicit course entry point (`-Wl,-e,Reset_Handler`). Original assembly startup calls `SystemInit()` (which must not depend on initialized writable global/static C state), copies `.data`, zeroes `.bss`, executes `__libc_init_array()`, and calls `main()`. FreeRTOS `heap_4` is the sole dynamic memory manager in mandatory coursework; libc `malloc/free` is strictly forbidden to prevent dual-heap memory hazards; `_sbrk` is absent when unused; USART telemetry uses direct register I/O without `printf`/host syscall dependency.

---

## Required source-reading objects

### FreeRTOS Upstream Source Walkthrough (`FreeRTOS-Kernel` V11.3.0)

1. **`tasks.c`**:
   - `prvAddNewTaskToReadyList()` — Task entry into `pxReadyTasksLists[uxPriority]`.
   - `vTaskSwitchContext()` — Highest-priority ready task selection (`taskSELECT_HIGHEST_PRIORITY_TASK`).
   - `xTaskIncrementTick()` — Tick counter update, unblocking delayed tasks from `pxDelayedTaskList`, and preemption decision.
   - `vTaskPlaceOnEventList()` — Moving tasks from ready lists to event lists (queue wait lists).
   - `uxTaskGetStackHighWaterMark()` in `tasks.c` and `taskCHECK_FOR_STACK_OVERFLOW()` in `include/stack_macros.h` — complementary stack-usage and overflow-detection mechanisms.
2. **`portable/GCC/ARM_CM3/port.c` & `portmacro.h`**:
   - `xPortStartScheduler()` — NVIC priority configuration for PendSV/SysTick and SVC 0 kickoff.
   - `prvPortStartFirstTask()` & `vPortSVCHandler()` — Starting the first task in Thread mode on PSP; standard non-MPU ARM_CM3 port runs tasks with privileged Thread mode.
   - `xPortPendSVHandler()` — Assembly context switch: saving `{r4-r11}` on PSP, swapping `pxCurrentTCB->pxTopOfStack`, restoring `{r4-r11}`, and returning with `0xFFFFFFFD`.
   - `vPortValidateInterruptPriority()` — Assertion checking ISR priority against `configMAX_SYSCALL_INTERRUPT_PRIORITY`.
   - `portSET_INTERRUPT_MASK_FROM_ISR()` / `portCLEAR_INTERRUPT_MASK_FROM_ISR()` — Masking interrupts via `BASEPRI`.
3. **`queue.c`**:
   - `xQueueGenericSend()` & `xQueueGenericReceive()` — Bounded FIFO ring buffer, copying data, critical sections, and event list task unblocking.
   - `xQueueGenericSendFromISR()` — ISR-safe enqueueing without scheduler invocation: unblocks waiting tasks directly to `pxReadyTasksLists` if the scheduler is active, or defers to `xPendingReadyList` if the scheduler is suspended; communicates preemption requirement via `*pxHigherPriorityTaskWoken`.
   - Mutex vs Semaphore implementation — `xQueueCreateMutex()`, `pxMutexHolder` tracking, and priority inheritance via `xTaskPriorityInherit()` and `xTaskPriorityDisinherit()` in `tasks.c`.
4. **`list.c`**:
   - Circular doubly linked list operations: `vListInsertEnd()`, `vListInsert()`, `uxListRemove()`.
5. **`portable/MemMang/heap_4.c`**:
   - First-fit memory allocation with block coalescing (`BlockLink_t`), contrast with static allocation (`xTaskCreateStatic`).

### Bare-Metal & CMSIS Source Walkthrough

1. **`startup_stm32f103xb.s`**:
   - Vector Table entries (`_estack`, `Reset_Handler`), hardware MSP loading from vector 0, `SystemInit()` execution (under pre-.data/.bss invariant), `.data` copy loop, `.bss` zeroing loop, `__libc_init_array()` call, and jump to `main()`.
2. **`core_cm3.h`**:
   - `NVIC_SetPriority()`, `NVIC_EnableIRQ()`, and SCB register definitions (`SCB->AIRCR`, `SCB->ICSR`).

---

## Fault recurrence contract

The curriculum organizes recurring hardware/software failure modes into **competency families**. Module challenges teach diagnostic discipline within each family; the Phase 2 Final Gate evaluates *unfamiliar variants* within these families under AI-Free examination conditions:

| Fault Competency Family | Introduced In | Final Gate Competency Focus | Root Cause Category |
|---|---|---|---|
| Vector table alignment / Thumb bit missing | P2-M01 | Gate Part A: Startup/runtime reasoning | Reset / Startup |
| Linker script `.data` / `.bss` symbol mismatch | P2-M01 | Gate Part A: Section & LMA/VMA bounds | Linker / Runtime |
| Peripheral clock not enabled in RCC | P2-M02 | Gate Part B: Peripheral register diagnosis | MMIO / Clock Tree |
| RMW bit hazard on GPIO / shared register | P2-M02 | Gate Part D: Concurrency race condition | Concurrency / MMIO |
| Interrupt pending flag unacknowledged (storm) | P2-M02 | Gate Part B: Interrupt lifecycle diagnosis | Interrupt Handling |
| DMA buffer allocated on stack (lifetime bug) | P2-M03 | Gate Part B: Buffer lifetime & memory safety | Memory / DMA |
| DMA data width mismatch (16-bit ADC to 8-bit RAM) | P2-M03 | Gate Part B: Transfer configuration | DMA Configuration |
| Calling task-context API from interrupt handler | P2-M04 | Gate Part C: Execution context audit | FreeRTOS API Boundary |
| ISR priority higher than `configMAX_SYSCALL` | P2-M05 | Gate Part C: Priority & BASEPRI masking | NVIC / RTOS Interaction |
| Bounded priority inversion without inheritance | P2-M06 | Gate Part D: Synchronization architecture | Concurrency / Real-Time |
| Task stack overflow / corruption | P2-M06 | Gate Part D: Stack watermark & memory bounds | Memory Safety |

A fix without verified register, memory, or oscilloscope evidence does not pass any module gate.

---

## Acquisition Node Project milestones

The canonical integration project is the **STM32 FreeRTOS Acquisition Node** (P2-M07). It represents a production-grade embedded subsystem without application bloat:

```text
Normal Acquisition Data Path (Queue-Driven, No Application Mutex):
Timer 3 Trigger (TIM3 TRGO update @ 1 kHz)
   -> ADC1 regular external trigger (EXTSEL = 0b100, ADCPRE = /6 -> 12 MHz, SMP0 >= 55.5 cycles)
   -> DMA1 Channel 1 circular ping-pong buffer (2x64 samples)
   -> Half-Transfer / Transfer-Complete ISR
   -> Acquisition Queue (xAcqQueue)
   -> Processing Task (Task_Process, Priority 3) -> computes min, max, avg, integer isqrt()
   -> Logging Queue (xLogQueue)
   -> Communication Task (Task_Comm, Priority 2) -> USART1 interrupt-driven / polling TX
   -> Health Monitor Task (Task_Health, Priority 1) -> stack watermark check & IWDG refresh

Controlled Diagnostic Priority-Inversion Experiment:
Task_Health (Priority 1) holds xDiagMutex (executing CPU-runnable work, not vTaskDelay)
   -> Task_Process (Priority 3) attempts lock and blocks
   -> Task_Compute (Priority 2) is released to create interference
   -> Compare bounded 20 ms inversion without inheritance vs prompt inheritance resolution
```

- **Milestone 0 (Clock, Pinout & Runtime Harness):** Configure 72 MHz SYSCLK via PLL (or 64 MHz HSI fallback if board lacks HSE), set up GPIO timing markers (PA1–PA4), verify Make build with Arm GNU Toolchain 13.3.rel1 (`startup -> SystemInit -> copy .data -> zero .bss -> __libc_init_array -> main`), with course `Reset_Handler` as sole entry point, and verify OpenOCD SWD flashing.
- **Milestone 1 (Autonomous Calibrated DMA Data Path):** Configure ADCPRE to divide by 6 (yielding 12 MHz ADCCLK $\le 14\text{ MHz}$), configure sample time $\ge 55.5\text{ cycles}$ on PA0 for source impedance compatibility, execute ADC calibration sequence (RSTCAL/CAL), configure TIM3 update event to emit TRGO pulses driving ADC1 regular conversions (`EXTSEL = 0b100`) into a circular ping-pong DMA buffer (`2 * 64` 16-bit samples). Verify autonomous transfer with CPU sleeping (`WFI`).
- **Milestone 2 (FreeRTOS Core & ISR Handoff):** Integrate FreeRTOS kernel with `heap_4` as sole heap manager. In DMA HT/TC ISR, post buffer tokens to `xAcqQueue` via `xQueueSendFromISR()` and yield via `portYIELD_FROM_ISR()`. Processing task unblocks and calculates batch statistics using integer arithmetic (`isqrt()`).
- **Milestone 3 (Logging & Controlled Priority Inversion Experiment):** Implement `Task_Comm` transmitting fixed-size telemetry packets over USART1 via direct register I/O. The normal acquisition path remains queue-driven with no application mutex. Implement a controlled diagnostic experiment with deterministic coordination: `Task_Health` (prio 1) acquires `xDiagMutex`, signals `Task_Process` (prio 3) which attempts the lock and blocks, then signals `Task_Compute` (prio 2) to become runnable. `Task_Health` executes identical CPU-runnable work (~5 ms, measured by cycle counter, no `vTaskDelay()`). Compare bounded 20 ms inversion under a binary semaphore versus prompt completion under a mutex with priority inheritance.
- **Milestone 4 (Health Monitoring & Scope Evidence):** Implement `Task_Health` inspecting `uxTaskGetStackHighWaterMark` across all tasks and refreshing IWDG. Connect oscilloscope/logic analyzer to GPIO markers; capture and document ISR-to-Task latency, context-switch duration, and priority inheritance timing.
- **Final Project Acceptance:** Zero compiler warnings (`-Wall -Wextra -Werror`), static initialization with zero steady-state heap allocation churn, no unhandled exceptions, verified waveform documentation, and concise English `BUILD_RUN_DEBUG.md`.

**Explicit Non-Goals:** No secondary DMA path in MUST (USART DMA is SHOULD); no USB stack; no TCP/IP; no FatFS; no graphical UI; no cloud/MQTT; no dynamic task creation/destruction after startup; no libc heap allocation.

---

## Spaced review strategy

- **D+1:** 5–8 min closed-book architectural recall (e.g. draw the Cortex-M exception stack frame; write the mathematical relation between SYSCLK, prescaler, and timer period).
- **D+3:** 10–15 min changed-context code question (e.g. given a specific NVIC priority configuration, determine if an ISR is allowed to invoke `xQueueSendFromISR`).
- **D+7:** 20–30 min AI-Free reconstruction from a blank file (e.g. write a complete, working vector table and reset handler in assembly; or configure a timer interrupt from bare registers).
- **Phase End:** Complete Phase 2 Final Gate transfer assessment under isolated exam conditions.

---

## 4-week execution map

| Week | MUST Modules | SHOULD Activities | Weekly Gate / Milestones | Weekly Planned Load |
|---|---|---|---|---:|
| **Week 1** | **P2-M01** (3.5 h) + **P2-M02** (4.5 h) | Disassemble startup file; inspect CMSIS headers | Bare-metal boot, timer ISR bring-up & RMW fix | 8.0 h MUST |
| **Week 2** | **P2-M03** (4.5 h) + **P2-M04** (5.0 h) | Test DMA transfer error ISR; trace SysTick tickless hook | TIM3-TRGO ADC+DMA circular buffer & PendSV verification | 9.5 h MUST |
| **Week 3** | **P2-M05** (4.5 h) + **P2-M06** (4.0 h) | Test counting semaphore; experiment with `heap_1` vs `heap_4` | ISR handoff validation & priority inversion reproduction/fix | 8.5 h MUST |
| **Week 4** | **P2-M07** Project (5.0 h) + **P2-GATE** (3.5 h) | USART DMA transmit exploration | Acquisition Node acceptance & Final Gate Pass | 8.5 h MUST |

If personal or work schedules slip, drop SHOULD activities immediately to preserve the 34.5 h MUST envelope and protect Gate review time.

---

## AI policy progression

- **AI-Free (Strict):**
  - All Module Gates and D+7 blank-file reconstructions.
  - Initial unknown-fault diagnostic sessions (learner must articulate hypotheses and identify evidence channels independently).
  - Phase 2 Final Gate Assessment.
  - *Official Reference Manuals, Programming Manuals, Datasheets, and upstream source are fully permitted.*
- **AI-Hint (Socratic Only):**
  - Allowed during lab exploration after learner documents initial hypotheses.
  - Navigation of complex upstream source files (e.g. pointing to relevant functions in `tasks.c`).
  - Troubleshooting obscure toolchain/OpenOCD connectivity issues.
- **AI-Assisted:**
  - Post-verification code review, stylistic improvements, and English documentation polish after lab code is functioning and passing tests.

> [!CAUTION]
> Copying and pasting compiler/runtime errors directly into AI without independently inspecting GDB registers or hardware state is strictly prohibited.

---

## Phase 2 Final Gate overview

The Phase 2 Final Gate is an **AI-Free**, hands-on, transfer-oriented assessment (estimated **3.5 h**). It evaluates whether the learner can independently reason, configure, and debug MCU hardware and RTOS mechanisms across four core ability families:

- **Part A — Bare-Metal Startup & Linker Reasoning (25% / Floor 60%):** Reconstruct memory sections, analyze a vector table and linker script from scratch, and resolve an unfamiliar fault in the startup/linker/memory-initialization family.
- **Part B — Peripheral Register & DMA Data-Path Diagnosis (25% / Floor 60%):** Diagnose a non-functioning peripheral data path from live GDB register dumps. Correct configuration bits in the clock/trigger/DMA family (e.g. TIM3 TRGO, ADCPRE, ADC calibration, or DMA), compute sampling frequencies, and verify circular buffer operation.
- **Part C — FreeRTOS Scheduling & Context Switch Mechanics (25% / Floor 60%):** Walk through a live GDB breakpoint trace at `xPortPendSVHandler`, calculate PSP vs MSP stack locations, inspect TCB list nodes, and audit an unfamiliar NVIC priority assignment against `configMAX_SYSCALL_INTERRUPT_PRIORITY`.
- **Part D — Concurrency, Priority Inversion & HW/SW Debugging (25% / Floor 70%):** Given a seeded system fault exhibiting timing jitter, starvation, or watchdog resets, formulate 3–5 hypotheses, collect register/memory/waveform evidence, identify the root cause in the synchronization/stack/timing family, and implement an evidence-backed fix.

**Pass Criteria:** Overall score >= 75%; Part floors: Part A >= 60%, Part B >= 60%, Part C >= 60%, Part D >= 70%. Zero unexplained memory corruption; evidence chain required for all bug fixes. Concrete seeds and fixtures remain isolated in reviewer materials.

---

## Leader decision points

- **Hardware Target & Board Profile Separation:**
  - *MCU Silicon Contract:* STM32F103C8T6 (Cortex-M3, 64 KB Flash, 20 KB SRAM, TIM3 TRGO, ADC1, DMA1, USART1, NVIC, SWD).
  - *Board Profile Layer:* Minimal Development Board ("Blue Pill" / Core board) with documented HSE 8 MHz crystal (and HSI 64 MHz fallback), PC13 User LED, SWD header, PA0 analog input, and PA1–PA4 GPIO timing test points. Alternatively, ST Nucleo-F103RB.
  - *Lab Equipment Requirements:* ST-Link V2 (or CMSIS-DAP / J-Link), 2-channel oscilloscope or 8-channel logic analyzer, and an analog potentiometer/signal source. Learner inventory must be verified against these requirements.
- **Toolchain Baseline:** Standardize on **Arm GNU Toolchain 13.3.rel1** (`arm-none-eabi-gcc` 13.3.1 20240614, Binutils 2.42, GDB 14.2) with Make-first workflow. CMake is excluded from Phase 2 to ensure total transparency of compiler/linker flags.
- **Runtime & Startfile Contract:** Standardize on **Option B (newlib-nano runtime with original startup & transparent linker)**:
  - Original assembly startup explicitly executes: `Reset_Handler -> SystemInit -> copy .data -> zero .bss -> __libc_init_array -> main()`.
  - Startfile policy uses `-Wl,-e,Reset_Handler` to ensure course `Reset_Handler` is the sole entry point, suppressing alternative CRT startup routines.
  - Invariant: `SystemInit()` is called before `.data` copy and `.bss` zeroing; it must **not** depend on initialized writable global or static C state.
  - Linker script explicitly retains `.preinit_array` and `.init_array` using `KEEP` and provides standard `PROVIDE_HIDDEN` boundary symbols.
  - FreeRTOS `heap_4` is the sole dynamic heap (no libc `malloc/free`); `_sbrk` is absent when unused; statistics use integer/fixed-point math (`isqrt()`); direct register USART I/O avoids host syscall/printf dependencies.
- **ADC Clock & Sampling Contract:** In 72 MHz profile, configure `ADCPRE = /6` yielding 12 MHz ADCCLK ($\le 14\text{ MHz}$); select sample time $\ge 55.5\text{ cycles}$ on PA0 for source impedance compatibility ($R_{\text{AIN}} \le 50\text{ k}\Omega$); execute explicit hardware calibration sequence (`RSTCAL`/`CAL`) before conversion enable.
- **Controlled Priority Inversion Architecture:** Normal acquisition pipeline is queue-driven with no application mutex; a dedicated diagnostic telemetry resource `xDiagMutex` provides a real shared-mutex dependency between Low (`Task_Health`), Medium (`Task_Compute`), and High (`Task_Process`). Deterministic sequencing and identical CPU-runnable Low workload (~5 ms, no `vTaskDelay`) demonstrate bounded 20 ms inversion under binary semaphore versus prompt completion under priority inheritance.
- **CubeMX Policy:** CubeMX is strictly restricted to an offline pinout/clock configuration reference tool; auto-generated HAL code is prohibited in mandatory coursework.
- **Upstream Version Pinning:** Pin `FreeRTOS-Kernel` release `V11.3.0` (`9b777ae`), ST CMSIS device headers `cmsis_device_f1 v4.3.5`, and `CMSIS_5 v5.9.0`.
