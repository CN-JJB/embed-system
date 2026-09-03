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

- reason about MCU reset, vector table fetch, `.data` copy, `.bss` zeroing, and startup-to-`main()` execution from linker script and assembly source;
- explain Cortex-M3 privilege, Thread vs Handler mode, MSP vs PSP, exception entry/exit stacking (`{r0-r3, r12, lr, pc, xpsr}`), and `EXC_RETURN` codes;
- configure and diagnose peripheral memory-mapped registers (MMIO) using direct CMSIS register structs, reason about `volatile` semantic limits, avoid read-modify-write (RMW) hazards using atomic bit registers (BSRR/BRR), and handle memory ordering/write-buffering barriers (`DSB`/`ISB`);
- calculate timer prescalers/periods from the internal clock tree, configure NVIC interrupt priorities, explain preemption vs subpriority, and prevent interrupt storms;
- construct an autonomous hardware data acquisition path using Timer TRGO, ADC, and DMA circular double-buffering without CPU polling;
- explain FreeRTOS kernel scheduling mechanics: ready/blocked/suspended task state lists, tick processing (`xTaskIncrementTick`), and the PendSV context switch mechanism (`{r4-r11}` software stacking);
- implement robust ISR-to-task handoffs using queues and task notifications, audit NVIC priority settings against `configMAX_SYSCALL_INTERRUPT_PRIORITY`, and use `portYIELD_FROM_ISR`;
- distinguish mutexes from binary semaphores, reproduce and resolve unbounded priority inversion using priority inheritance, and audit code for deadlock;
- monitor task runtime health using stack watermarks (`uxTaskGetStackHighWaterMark`), configure stack overflow hooks, and integrate an independent watchdog (IWDG);
- capture physical evidence of system timing (ISR latency, jitter, context switch duration) using GPIO toggles, oscilloscope/logic analyzer probes, and live SWD/GDB register inspection;
- debug complex MCU/RTOS faults using the disciplined hypothesis-driven framework: `Symptom -> Own Description -> Hypotheses -> Evidence -> Narrow Scope -> Root Cause -> Fix -> Regression`.

**Mastery Target**: FreeRTOS mechanisms at **L3**, MMIO/register interaction at **L4-local** on selected MCU/peripherals, interrupt handling at **L3**, basic DMA at **L2–L3**, and debugging at **L4-local** on practiced MCU/RTOS fault families.

---

## Course shape

MCU bare-metal foundations and FreeRTOS mechanisms are tightly sequenced to ensure that no RTOS abstraction is introduced before its underlying architectural mechanism is fully mastered:

```text
reset / startup / linker script  <-> memory layout, vector table, MSP initialization
MMIO / clock tree / timers       <-> NVIC priority model, exception entry/return
ADC / DMA circular path          <-> autonomous data movement, buffer ownership
FreeRTOS scheduler / task lists  <-> PendSV, PSP swapping, context switch frame
queue / mutex / ISR handoff      <-> synchronization, priority inheritance, BASEPRI mask
stack watermark / overflow hook  <-> memory safety, task sizing, watchdog recovery
Acquisition Node project         <-> integrated, verifiable embedded sensor subsystem
```

Hardware-software debugging begins in Module 1. There is no isolated "RTOS debugging" topic.

---

## Module sequence

| ID | Module | Target | MUST hours | SHOULD hours | Principal Gate |
|---|---|---|---:|---:|---|
| **P2-M01** | Reset, Startup, Linker Script, and Vector Table | L3 / L4-local link & boot faults | 3.5 | 1.0 | Reconstruct minimal startup & linker; diagnose vector table alignment/offset fault |
| **P2-M02** | MMIO, Clock Tree, Hardware Timers, and NVIC Mechanism | L3 / L4-local register & IRQ faults | 4.5 | 1.0 | Bring up timer/clock from RM; diagnose nested IRQ priority & RMW hazards |
| **P2-M03** | Peripheral Acquisition & DMA Data Path | L2–L3 DMA / L4-local peripheral path | 4.5 | 1.0 | Build Timer+ADC+DMA circular ping-pong buffer; diagnose DMA stall & buffer lifetime |
| **P2-M04** | FreeRTOS Scheduler, Task Lifecycle, and Context Switch | L3 FreeRTOS core / L3 Cortex-M port | 5.0 | 1.0 | Walk through `tasks.c` & `port.c`; verify PendSV register stacking in GDB |
| **P2-M05** | Queue, Mutex, and ISR-Safe Synchronization Boundaries | L3 synchronization / L3 ISR handoff | 4.5 | 1.0 | Build ISR-to-Task queue pipeline; audit NVIC vs `configMAX_SYSCALL`; verify mutex vs semaphore |
| **P2-M06** | Priority Inversion, Inheritance, Stack Watermark & Debugging | L3 concurrency / L4-local RTOS faults | 4.0 | 0.5 | Reproduce unbounded priority inversion; observe inheritance fix; detect stack overflow |
| **P2-M07** | STM32 FreeRTOS Acquisition Node Integration Project | L3 integrated node | 5.0 | 1.0 | End-to-end multi-task node acceptance; GPIO scope timing evidence; fault campaign |
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

All curriculum content must derive from primary specifications and official upstream source code:

- **STMicroelectronics Reference Manual RM0008** (Rev 21, Feb 2021) — Authoritative register definitions, clock tree, NVIC table, Timer TRGO, ADC regular/injected modes, and DMA channel mappings.
- **STMicroelectronics Programming Manual PM0056** (Rev 6, May 2020) — Cortex-M3 processor programming model, core registers (CONTROL, PRIMASK, BASEPRI), NVIC register interface, and SysTick.
- **STMicroelectronics Datasheet DS5319** (Rev 18, Mar 2021) — STM32F103x8/xB electrical characteristics, pin multiplexing, and memory mapping.
- **Armv7-M Architecture Reference Manual** (ARM DDI 0403E.e) — Exception model, stack alignment, instruction execution states, memory barriers (`DSB`, `ISB`, `DMB`).
- **FreeRTOS-Kernel Upstream** (Release V11.3.0, commit `9b777ae`, MIT License) — Official kernel source for task scheduling, queues, and Cortex-M3 port.
- **CMSIS Core / Device Headers** (CMSIS_5 v5.9.0 / `cmsis_device_f1` v4.3.4, Apache-2.0) — Vendor-neutral register structs (`core_cm3.h`, `stm32f103xb.h`).

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
   - `prvPortStartFirstTask()` & `vPortSVCHandler()` — Starting the first task in Thread mode on PSP; the standard non-MPU ARM_CM3 port does not itself introduce unprivileged task execution.
   - `xPortPendSVHandler()` — Assembly context switch: saving `{r4-r11}` on PSP, swapping `pxCurrentTCB->pxTopOfStack`, restoring `{r4-r11}`, and returning with `0xFFFFFFFD`.
   - `vPortValidateInterruptPriority()` — Assertion checking ISR priority against `configMAX_SYSCALL_INTERRUPT_PRIORITY`.
   - `portSET_INTERRUPT_MASK_FROM_ISR()` / `portCLEAR_INTERRUPT_MASK_FROM_ISR()` — Masking interrupts via `BASEPRI`.
3. **`queue.c`**:
   - `xQueueGenericSend()` & `xQueueGenericReceive()` — Bounded FIFO ring buffer, copying data, critical sections, and event list task unblocking.
   - `xQueueGenericSendFromISR()` — ISR-safe enqueueing without scheduler invocation, setting `*pxHigherPriorityTaskWoken`.
   - Mutex vs Semaphore implementation — `xQueueCreateMutex()`, `pxMutexHolder` tracking, and priority inheritance via `xTaskPriorityInherit()` and `xTaskPriorityDisinherit()`.
4. **`list.c`**:
   - Circular doubly linked list operations: `vListInsertEnd()`, `vListInsert()`, `uxListRemove()`.
5. **`portable/MemMang/heap_4.c`**:
   - First-fit memory allocation with block coalescing (`BlockLink_t`), contrast with static allocation (`xTaskCreateStatic`).

### Bare-Metal & CMSIS Source Walkthrough

1. **`startup_stm32f103xb.s`**:
   - Initial stack pointer (`_estack`), Vector Table entries, `Reset_Handler`, `.data` copy loop, `.bss` zeroing loop, and jump to `main()`.
2. **`core_cm3.h`**:
   - `NVIC_SetPriority()`, `NVIC_EnableIRQ()`, and SCB register definitions (`SCB->AIRCR`, `SCB->ICSR`).

---

## Fault recurrence contract

| Fault | Introduced In | Re-tested In | Root Cause Category |
|---|---|---|---|
| Vector table alignment / Thumb bit missing | P2-M01 | P2-GATE | Reset/Startup |
| Linker script `.data` / `.bss` symbol mismatch | P2-M01 | P2-M07, P2-GATE | Linker / Runtime |
| Peripheral clock not enabled in RCC | P2-M02 | P2-M03, P2-GATE | MMIO / Clock |
| RMW bit hazard on GPIO / shared register | P2-M02 | P2-M05 | Concurrency / MMIO |
| Interrupt pending flag not cleared in ISR (storm) | P2-M02 | P2-M05, P2-GATE | Interrupt Handling |
| DMA buffer allocated on stack (lifetime bug) | P2-M03 | P2-M07 | Memory / DMA |
| DMA data width mismatch (16-bit ADC to 8-bit RAM) | P2-M03 | P2-GATE | DMA Configuration |
| Calling non-ISR API from interrupt handler | P2-M04 | P2-M05, P2-GATE | FreeRTOS API Boundary |
| ISR priority higher than `configMAX_SYSCALL` | P2-M05 | P2-M07, P2-GATE | NVIC / RTOS Interaction |
| Unbounded priority inversion (binary semaphore lock) | P2-M06 | P2-M07, P2-GATE | Concurrency / Synchronization |
| Task stack overflow / corruption | P2-M06 | P2-M07, P2-GATE | Memory Safety |

A fix without verified register, memory, or oscilloscope evidence does not pass any module gate.

---

## Acquisition Node Project milestones

The canonical integration project is the **STM32 FreeRTOS Acquisition Node** (P2-M07). It represents a production-grade embedded subsystem without application bloat:

```text
Timer Trigger (TIM2 TRGO @ 1 kHz)
   -> ADC1 regular conversion
   -> DMA1 Channel 1 circular ping-pong buffer (2x64 samples)
   -> Half-Transfer / Transfer-Complete ISR
   -> Acquisition Queue (xAcqQueue)
   -> Processing Task (Task_Process) -> computes min, max, avg, rms
   -> Logging Queue (xLogQueue)
   -> Communication Task (Task_Comm) -> USART1 DMA/IRQ telemetry
   -> Health Monitor Task (Task_Health) -> stack watermark check & IWDG refresh
```

- **Milestone 0 (Clock & Pinout Harness):** Configure 72 MHz SYSCLK via PLL, set up GPIO timing markers (PA1–PA4), verify basic Make build and OpenOCD SWD flashing.
- **Milestone 1 (Autonomous DMA Data Path):** Configure TIM2 TRGO update triggers to drive ADC1 conversions into a circular ping-pong DMA buffer. Verify autonomous transfer with CPU sleeping (`WFI`).
- **Milestone 2 (FreeRTOS Core & ISR Handoff):** Integrate FreeRTOS kernel. In DMA HT/TC ISR, post buffer tokens to `xAcqQueue` via `xQueueSendFromISR()` and yield via `portYIELD_FROM_ISR()`. Processing task unblocks and calculates batch statistics.
- **Milestone 3 (Logging, Mutex & Priority Inversion Test):** Implement `Task_Comm` serializing telemetry packets. Protect shared telemetry buffer with a mutex. Inject an intentional lower-priority CPU load to verify priority inheritance prevents telemetry jitter.
- **Milestone 4 (Health Monitoring & Scope Evidence):** Implement `Task_Health` inspecting `uxTaskGetStackHighWaterMark` and kicking IWDG. Connect oscilloscope/logic analyzer to GPIO markers; capture and document ISR-to-Task latency and context-switch duration.
- **Final Project Acceptance:** Zero compiler warnings (`-Wall -Wextra -Werror`), zero memory leaks, no unhandled exceptions, verified waveform documentation, and concise English `BUILD_RUN_DEBUG.md`.

**Explicit Non-Goals:** No USB stack, no TCP/IP, no FatFS, no graphical UI, no cloud/MQTT, no dynamic task creation/destruction after startup.

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
| **Week 2** | **P2-M03** (4.5 h) + **P2-M04** (5.0 h) | Test DMA transfer error ISR; trace SysTick tickless hook | DMA circular ping-pong buffer & PendSV stack verification | 9.5 h MUST |
| **Week 3** | **P2-M05** (4.5 h) + **P2-M06** (4.0 h) | Test counting semaphore; experiment with `heap_1` vs `heap_4` | ISR handoff validation & priority inversion reproduction/fix | 8.5 h MUST |
| **Week 4** | **P2-M07** Project (5.0 h) + **P2-GATE** (3.5 h) | Measure jitter under heavy interrupt load | Acquisition Node acceptance & Final Gate Pass | 8.5 h MUST |

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

The Phase 2 Final Gate is an **AI-Free**, hands-on, transfer-oriented assessment (estimated **3.5 h**). It evaluates whether the learner can independently reason, configure, and debug MCU hardware and RTOS mechanisms:

- **Part A — Bare-Metal Startup & Linker Reasoning (25%):** Reconstruct memory sections, analyze a vector table and linker script from scratch, and resolve an injected boot fault (e.g., misaligned vector table or corrupt `.data` initialization).
- **Part B — Peripheral Register & DMA Data-Path Diagnosis (25%):** Diagnose a non-functioning peripheral data path (Timer TRGO, ADC, or DMA) from live GDB register dumps. Correct configuration bits, compute sampling frequencies, and verify circular buffer operation.
- **Part C — FreeRTOS Scheduling & Context Switch Mechanics (25%):** Walk through a live GDB breakpoint trace at `xPortPendSVHandler`, calculate PSP vs MSP stack locations, inspect TCB list nodes, and audit an NVIC priority assignment against `configMAX_SYSCALL_INTERRUPT_PRIORITY`.
- **Part D — Concurrency, Priority Inversion & HW/SW Debugging (25%):** Given a seeded system fault exhibiting timing jitter or crashes, formulate hypotheses, collect register/memory/waveform evidence, identify the root cause (e.g., unbounded priority inversion or task stack exhaustion), and implement an evidence-backed fix.

**Pass Criteria:** Overall score >= 75%; Part floors: Part A >= 60%, Part B >= 60%, Part C >= 60%, Part D >= 70%. Zero unexplained memory corruption; evidence chain required for all bug fixes.

---

## Leader decision points

- **Hardware Platform:** Confirm **STM32F103C8T6** as the sole mandatory hardware target. It completely fulfills all architectural, peripheral, DMA, FreeRTOS, and timing instrumentation requirements without requiring additional purchases.
- **Toolchain Baseline:** Standardize on GNU Arm Embedded Toolchain (`arm-none-eabi-gcc` 13.x or 12.x) with Make-first workflow. CMake is excluded from Phase 2 to ensure total transparency of compiler/linker flags.
- **CubeMX Policy:** CubeMX is strictly restricted to an offline pinout/clock configuration reference tool; no auto-generated HAL code is used in mandatory coursework.
- **Upstream Kernel Pinning:** Pin `FreeRTOS-Kernel` release `V11.3.0` (`9b777ae`) and ST CMSIS device headers `v4.3.4`.
