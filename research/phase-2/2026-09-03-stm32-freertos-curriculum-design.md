# Phase 2 — STM32 + FreeRTOS Mechanisms Curriculum Design

> Status: **Research Package — Leader review required**  
> Role: Phase Curriculum Designer + Embedded Systems Researcher  
> Checked date: **2026-09-03**  
> Scope: 4 weeks, **34.5 h mandatory planned work** (strictly bounded within ~34–35 h MUST envelope)  
> Target Hardware: **STM32F103C8T6** ("Blue Pill" / STM32F103 core board) + ST-Link V2 + 2-channel oscilloscope / 8-channel logic analyzer  
> Verification: Curriculum, lab, and project designs are **UNVERIFIED** until physical execution on hardware target; no fabricated register or oscilloscope evidence is presented.  
> Canonical authority: None. This document establishes the technical blueprint for Phase 2; the Leader decides what becomes canonical.

---

# Part 1 — Executive Design & Exit Capability

## 1.1 Context & Purpose

In the target career path:

$$\text{Embedded Systems Engineer} \longrightarrow \text{Embedded Linux / BSP / Driver} \longrightarrow \text{SoC / Platform}$$

Phase 2 closes the critical gap between bare-metal C runtime mechanics and preemptive operating system kernels. Moving into Embedded Linux, U-Boot, and Linux kernel drivers without understanding hardware exceptions, memory-mapped registers, clock configuration, interrupt priority masking, and scheduler context switching leads to severe conceptual deficits. 

Phase 1 established durable foundations in C storage duration, object lifetimes, pointers, ELF linking, POSIX processes, file descriptors, and multithreading invariants. Phase 2 takes those concepts down to bare silicon and across the RTOS kernel boundary.

## 1.2 Bound & Non-Goals

Phase 2 is **strictly mechanism-first**. It is not:
- an STM32 HAL API cookbook or peripheral enumeration course;
- a STM32CubeMX graphical click-and-generate tutorial;
- a full Cortex-M assembly language course;
- a Zephyr OS mainline curriculum;
- an advanced lock-free / multicore SMP RTOS course;
- a network, USB, filesystem, GUI, or bootloader course;
- a Linux/Buildroot/U-Boot course (reserved for Phase 3 and Phase 4).

## 1.3 Target Exit Capability

Upon completing Phase 2, the learner can independently:

1. **Bare-Metal Boot Reasoning (L3 / L4-local link & boot faults):** Explain reset vector fetch, vector table layout, `.data` initialization (LMA to VMA copy), and `.bss` zeroing from linker script symbols (`_sidata`, `_sdata`, `_edata`, `_sbss`, `_ebss`) and assembly startup code (`startup_stm32f103xb.s`).
2. **Cortex-M3 Architectural Model (L3):** Detail Thread vs Handler mode, MSP vs PSP stack pointer usage, CONTROL and PRIMASK/BASEPRI registers, the 8-register hardware exception frame (`{r0-r3, r12, lr, pc, xpsr}`), and `EXC_RETURN` unstacking mechanics.
3. **Register-Level Peripheral & Clock Control (L4-local):** Configure peripheral registers (RCC, GPIO, TIM, ADC, DMA, USART) directly via CMSIS register structs. Distinguish `volatile` access semantics from hardware synchronization; avoid read-modify-write (RMW) bit hazards using atomic bit manipulation (BSRR/BRR); insert appropriate memory barriers (`DSB`/`ISB`) to guard against write-buffering hazards.
4. **NVIC & Exception Priority Model (L3):** Compute timer prescalers and auto-reload values from the clock tree; configure nested NVIC priorities; distinguish preemption priority from subpriority; implement interrupt acknowledge/flag-clear sequences to prevent interrupt storms.
5. **Autonomous DMA Data Paths (L2–L3):** Construct hardware-triggered peripheral-to-memory data transfers (Timer TRGO driving ADC regular conversions streamed into a circular double-buffered DMA buffer) operating autonomously without CPU intervention; reason about buffer lifetime and pointer alignment.
6. **FreeRTOS Core Mechanics (L3):** Trace task state transitions across `pxReadyTasksLists`, `xDelayedTaskList`, and event lists; explain SysTick-driven preemption and the PendSV assembly context switch (`{r4-r11}` software stacking on PSP); audit memory allocation (`heap_4.c` vs static `xTaskCreateStatic`).
7. **Synchronization & ISR Boundary (L3):** Implement queue-based pipelines; audit NVIC interrupt priorities against `configMAX_SYSCALL_INTERRUPT_PRIORITY`; enforce correct usage of `FromISR` APIs and `portYIELD_FROM_ISR()`.
8. **Concurrency, Priority Inversion & Safety (L3 / L4-local RTOS faults):** Distinguish binary semaphores from mutexes; reproduce unbounded priority inversion and resolve it using priority inheritance; monitor task stack watermarks (`uxTaskGetStackHighWaterMark`); catch stack overflows via hook functions; integrate an Independent Watchdog (IWDG).
9. **Measurable HW/SW Debugging (L4-local):** Diagnose complex faults using GPIO timing markers, oscilloscopes/logic analyzers, and SWD live register/memory inspection following the disciplined hypothesis-driven framework:
   $$\text{Symptom} \longrightarrow \text{Own Description} \longrightarrow \text{Hypotheses} \longrightarrow \text{Evidence} \longrightarrow \text{Narrow Scope} \longrightarrow \text{Root Cause} \longrightarrow \text{Fix} \longrightarrow \text{Regression}$$

---

# Part 2 — Dependency Map from Phase 1 to Phase 2

```mermaid
graph TD
    subgraph Phase 1 Foundations
        P1_MEM[C Lifetime, Extent & Ownership]
        P1_LAYOUT[Struct Layout, Endian & Bytes]
        P1_ELF[Translation, Symbols, Linker & ELF]
        P1_CTX[Callbacks & void *ctx API Boundary]
        P1_CONC[pthread Mutex, Predicates & Invariants]
        P1_DEBUG[Hypothesis Framework & GDB/Evidence]
    end

    subgraph Phase 2 MCU Bare-Metal
        P2_BOOT[P2-M01: Startup, Linker Script & Vector Table]
        P2_MMIO[P2-M02: MMIO, Clock Tree, Timers & NVIC]
        P2_DMA[P2-M03: Peripheral Acquisition & DMA Data Path]
    end

    subgraph Phase 2 FreeRTOS Mechanisms
        P2_SCHED[P2-M04: Scheduler, Task Lists & PendSV Context Switch]
        P2_SYNC[P2-M05: Queue, Mutex & ISR-Safe Boundaries]
        P2_INV[P2-M06: Priority Inversion, Stack Watermark & Faults]
    end

    subgraph Integration & Gate
        P2_PROJ[P2-M07: STM32 FreeRTOS Acquisition Node Project]
        P2_GATE[P2-GATE: Phase 2 Final Gate Assessment]
    end

    P1_ELF -->|LMA/VMA, sections, symbols| P2_BOOT
    P1_MEM -->|Stack/Static memory model| P2_BOOT
    P1_LAYOUT -->|CMSIS register structs, bitfields| P2_MMIO
    P1_CTX -->|Hardware vector -> ISR jump| P2_MMIO
    P1_MEM -->|Buffer lifetime, DMA pointer safety| P2_DMA
    P1_LAYOUT -->|ADC raw sample serialization| P2_DMA

    P2_BOOT -->|MSP/PSP, stack frame| P2_SCHED
    P2_MMIO -->|SysTick, PendSV, NVIC BASEPRI| P2_SCHED
    P1_CONC -->|Compare pthread mutex with RTOS queue/mutex| P2_SYNC
    P2_MMIO -->|ISR flag clearing & priority| P2_SYNC
    P2_SCHED -->|Task lists, event lists| P2_SYNC

    P2_SYNC -->|Mutex ownership vs semaphore| P2_INV
    P1_MEM -->|Stack watermark vs stack overflow| P2_INV
    P1_DEBUG -->|Register & memory evidence| P2_INV

    P2_DMA -->|Autonomous sample stream| P2_PROJ
    P2_SYNC -->|ISR-to-Task handoff queue| P2_PROJ
    P2_INV -->|Stack monitoring & watchdog| P2_PROJ
    P2_PROJ -->|Integration proof| P2_GATE
```

### Direct Transfer Mechanisms:
- **Phase 1 Linker/ELF $\to$ Phase 2 Startup:** In Phase 1 (M03), learners used `readelf -S` and `nm` to inspect `.text`, `.data`, and `.bss`. In P2-M01, learners write the linker script assigning `.text` to FLASH (`0x08000000`) and `.data` to SRAM (`0x20000000`), implementing the startup assembly loop that copies initialized variables from LMA in FLASH to VMA in SRAM.
- **Phase 1 Memory Extent $\to$ Phase 2 DMA Buffers:** In Phase 1 (M01/M05), lifetime bugs manifested as dangling pointers on the host stack. In P2-M03, allocating a DMA destination buffer on a local task stack demonstrates hardware memory corruption when the function returns while DMA continues streaming.
- **Phase 1 Concurrency $\to$ Phase 2 RTOS Mutexes:** In Phase 1 (M09), learners investigated POSIX mutexes and condition variable predicate loops. In P2-M05/M06, learners compare the OS mutex (futex-based) with the FreeRTOS embedded mutex (priority-inheritance queue) and contrast cooperative blocking against preemptive ISR-driven wakeups.

---

# Part 3 — Architecture Spine Inside Phase 2

Phase 2 incorporates only the architectural mechanisms of the ARM Cortex-M3 (ARMv7-M) that directly govern bare-metal execution and RTOS context switching. Full cache hierarchies, TLBs, and virtual memory (MMU) are deliberately excluded and deferred to Phase 3/4.

```text
+--------------------------------------------------------------------------------+
|                         CORTEX-M3 EXECUTION MODEL                              |
+--------------------------------------------------------------------------------+
| Mode:      Thread Mode (Tasks)              | Handler Mode (Exceptions / ISRs) |
| Stack:     PSP (Process Stack Pointer)      | MSP (Main Stack Pointer)         |
| Privilege: Privileged / Unprivileged (nPRIV)| Always Privileged                |
+--------------------------------------------------------------------------------+
                                       |
                 Exception / Interrupt Entry (Hardware)
                                       v
+--------------------------------------------------------------------------------+
| HARDWARE STACK FRAME (Pushed onto current SP: PSP in Thread Mode)              |
|   SP + 0x00: R0                                                                |
|   SP + 0x04: R1                                                                |
|   SP + 0x08: R2                                                                |
|   SP + 0x0C: R3                                                                |
|   SP + 0x10: R12                                                               |
|   SP + 0x14: LR (Link Register / R14)                                          |
|   SP + 0x18: PC (Return Address / Program Counter)                             |
|   SP + 0x1C: xPSR (Program Status Register, Thumb bit must be 1)               |
+--------------------------------------------------------------------------------+
                                       |
                   PendSV Handler (FreeRTOS Context Switch)
                                       v
+--------------------------------------------------------------------------------+
| SOFTWARE STACK FRAME (Pushed by PendSV assembly onto task's PSP)               |
|   PSP - 0x20: R4, R5, R6, R7, R8, R9, R10, R11                                 |
|   Update pxCurrentTCB->pxTopOfStack = PSP                                      |
|   Select next pxCurrentTCB = vTaskSwitchContext()                              |
|   Load PSP = pxCurrentTCB->pxTopOfStack                                        |
|   Pop R4-R11 from PSP                                                          |
|   Execute: BX 0xFFFFFFFD (EXC_RETURN: Return to Thread mode, restore from PSP) |
+--------------------------------------------------------------------------------+
```

### 1. Register Set, PC, and Stack Pointers (MSP vs PSP)
- **General Purpose Registers:** R0–R12, SP (R13), LR (R14), PC (R15), xPSR.
- **Dual Stack Pointers:** Cortex-M3 physically separates the Main Stack Pointer (MSP) and Process Stack Pointer (PSP). The active pointer is selected by `CONTROL[1]` (`SPSEL`).
- **Reset State:** Upon reset, the core enters Privileged Thread mode using MSP. MSP initial value is fetched directly from address `0x08000000`.
- **RTOS Division of Labor:** FreeRTOS configures the kernel and all exception handlers (ISRs, SysTick, PendSV, SVCall) to use MSP. User tasks run in Thread mode using PSP. Consequently, task stack sizes need only accommodate the task's own call tree and context frame—not worst-case nested interrupt stacks!

### 2. Exception Entry and Return Mechanics
- **Hardware Stacking:** When an exception is accepted, the processor hardware automatically pushes 8 registers `{r0-r3, r12, lr, pc, xpsr}` onto the currently active stack (PSP for tasks). If 8-byte stack alignment is configured (`SCB->CCR[STKALIGN]`), the hardware adds padding if necessary.
- **`EXC_RETURN`:** The hardware loads a special magic value into LR:
  - `0xFFFFFFF1`: Return to Handler mode, use MSP.
  - `0xFFFFFFF9`: Return to Thread mode, use MSP.
  - `0xFFFFFFFD`: Return to Thread mode, use PSP (the standard FreeRTOS task return).
- **Hardware Unstacking:** Executing `BX LR` with an `EXC_RETURN` value triggers hardware unstacking: the 8 registers are restored from the stack indicated by `EXC_RETURN`, and execution resumes at the restored PC.

### 3. NVIC Priority Model & Preemption
- **Priority Bits:** Cortex-M allows up to 256 priority levels (8 bits). STM32F103 implements **4 bits** (upper nibble of `IPRx[7:4]`), yielding 16 distinct priority levels (`0x00`, `0x10`, `0x20`, ..., `0xF0`).
- **Inverted Logic:** Lower numerical value represents higher priority. Level `0x00` is the highest configurable priority; `0xF0` is the lowest.
- **Priority Grouping (`SCB->AIRCR[PRIGROUP]`):** Splits priority into preemption priority and subpriority. In FreeRTOS Cortex-M ports, `PRIGROUP` must be set to `NVIC_PRIORITYGROUP_4` (all 4 bits assign preemption priority, 0 bits for subpriority) to ensure deterministic preemption.
- **`BASEPRI` and Critical Sections:** Cortex-M3 includes the `BASEPRI` register. Writing a non-zero value to `BASEPRI` masks all exceptions with priority equal to or lower (numerically $\ge$) than that value, while higher-priority (numerically $<$) interrupts continue to fire. FreeRTOS sets `BASEPRI` to `configMAX_SYSCALL_INTERRUPT_PRIORITY` inside critical sections (`portENTER_CRITICAL()`), achieving microsecond-bounded zero-jitter execution for hard real-time ISRs that do not call RTOS APIs.

### 4. Memory-Mapped I/O (MMIO), Volatile, and RMW Hazards
- **MMIO Architecture:** Peripherals reside in the 512 MB peripheral region (`0x40000000`–`0x5FFFFFFF`). Registers are accessed via standard 32-bit load/store instructions.
- **The Semantics of `volatile`:** 
  - `volatile` informs the compiler that the memory location can change outside the compiler's knowledge (by hardware) and that writes have external side effects.
  - `volatile` forces the compiler to emit a load or store on every access, preventing dead-store elimination and register caching across sequence points.
  - `volatile` does **not** make multi-byte access atomic, does **not** prevent CPU out-of-order write buffering, and does **not** insert bus barriers.
- **Read-Modify-Write (RMW) Hazards:**
  ```c
  /* Non-atomic RMW sequence: compiles to LDR, ORR, STR */
  GPIOC->ODR |= (1 << 13);
  ```
  If an interrupt fires between the `LDR` and `STR` and modifies `ODR`, the interrupt's write is overwritten and lost when the interrupted code completes its `STR`.
  - **The Atomic Hardware Fix:** STM32 GPIOs provide dedicated atomic set/reset registers: `BSRR` (Bit Set/Reset Register) and `BRR` (Bit Reset Register). Writing a `1` to `BSRR` bit `n` sets pin `n`; writing to bit `n+16` resets pin `n`. This is a single atomic bus write requiring no lock or interrupt disabling.

### 5. Memory Ordering and Barrier Concepts
- Cortex-M3 utilizes an internal write buffer between the core and the AHB bus matrix.
- **Write-Buffer Delay Hazard:** When software writes to disable an interrupt flag in a peripheral register, the write may sit in the write buffer while the processor executes the next instructions. If the ISR executes `BX LR` immediately, the interrupt controller (NVIC) may still see the active interrupt line from the peripheral, triggering an unwanted tail-chained re-entry into the same ISR.
- **Barriers:**
  - `DSB` (Data Synchronization Barrier): Ensures all explicit memory transfers complete before subsequent instructions execute.
  - `ISB` (Instruction Synchronization Barrier): Flushes the pipeline, ensuring following instructions are refetched from memory/cache.
  - In CMSIS: `__DSB()` is placed immediately following peripheral interrupt flag clears before ISR exit.

---

# Part 4 — Bounded FreeRTOS Source Walkthrough Plan

Rather than reading large source files linearly, learners perform targeted source audits of specific functions and structures in `FreeRTOS-Kernel` V11.3.0 (`9b777ae`).

```mermaid
graph LR
    subgraph Kernel Core
        TCB[TCB_t in tasks.c]
        READY[pxReadyTasksLists in tasks.c]
        EVENT[xEventListItem in tasks.c]
    end

    subgraph Synchronization
        QUEUE[Queue_t in queue.c]
        MUTEX[Mutex & Priority Inheritance]
    end

    subgraph Cortex-M Port
        PORT[port.c & portmacro.h]
        PENDSV[xPortPendSVHandler ASM]
        BASEPRI[portSET_INTERRUPT_MASK]
    end

    TCB --> READY
    TCB --> EVENT
    EVENT --> QUEUE
    QUEUE --> MUTEX
    PORT --> PENDSV
    PORT --> BASEPRI
    PENDSV -->|Swaps| TCB
```

| Source File | Line / Function Focus | Pedagogical Question Answered |
|---|---|---|
| **`FreeRTOS-Kernel/tasks.c`** | `struct tskTaskControlBlock` (TCB) | Where is task execution state saved? How are stack bounds, priority, and list links organized in memory? |
| **`FreeRTOS-Kernel/tasks.c`** | `prvAddNewTaskToReadyList()` | How does a newly created or unblocked task link into `pxReadyTasksLists[uxPriority]`? |
| **`FreeRTOS-Kernel/tasks.c`** | `vTaskSwitchContext()` | How does the scheduler select the highest priority ready task (`taskSELECT_HIGHEST_PRIORITY_TASK`)? |
| **`FreeRTOS-Kernel/tasks.c`** | `xTaskIncrementTick()` | What happens on each timer tick? How are delayed tasks in `pxDelayedTaskList` audited and woken up? |
| **`FreeRTOS-Kernel/tasks.c`** | `vTaskPlaceOnEventList()` | How does a blocked task remove itself from the ready list and sleep on a queue's event list? |
| **`FreeRTOS-Kernel/tasks.c`** | `uxTaskGetStackHighWaterMark()` | How does the kernel inspect stack memory to calculate the minimum unused stack space since task creation? |
| **`FreeRTOS-Kernel/portable/GCC/ARM_CM3/port.c`** | `xPortStartScheduler()` | How are PendSV and SysTick interrupt priorities configured in the NVIC before launching the first task? |
| **`FreeRTOS-Kernel/portable/GCC/ARM_CM3/port.c`** | `prvPortStartFirstTask()` & `vPortSVCHandler()` | How does SVC 0 kick off the first task, configure PSP, and transition from privileged handler mode to thread mode? |
| **`FreeRTOS-Kernel/portable/GCC/ARM_CM3/port.c`** | `xPortPendSVHandler()` | Exactly which registers are pushed by hardware vs software? How does `pxTopOfStack` get swapped? |
| **`FreeRTOS-Kernel/portable/GCC/ARM_CM3/port.c`** | `vPortValidateInterruptPriority()` | How does the kernel assert that an ISR calling RTOS APIs has a priority $\ge$ `configMAX_SYSCALL_INTERRUPT_PRIORITY`? |
| **`FreeRTOS-Kernel/portable/GCC/ARM_CM3/portmacro.h`** | `portSET_INTERRUPT_MASK_FROM_ISR()` | How does writing to `BASEPRI` implement nestable, zero-jitter critical sections? |
| **`FreeRTOS-Kernel/queue.c`** | `struct QueueDefinition` | What are the physical components of a queue (storage buffer, head/tail pointers, waiting senders/receivers lists)? |
| **`FreeRTOS-Kernel/queue.c`** | `xQueueGenericSend()` & `Receive()` | How does a task copy data into the queue, unblock a waiting receiver, or block itself if the queue is full? |
| **`FreeRTOS-Kernel/queue.c`** | `xQueueGenericSendFromISR()` | Why can't an ISR block? How does `xQueueGenericSendFromISR` signal `*pxHigherPriorityTaskWoken` without calling the scheduler? |
| **`FreeRTOS-Kernel/queue.c`** | `xTaskPriorityInherit()` & `Disinherit()` | Where does priority inheritance modify `pxCurrentTCB->uxPriority` when a high-priority task contends for a mutex? |
| **`FreeRTOS-Kernel/list.c`** | `vListInsertEnd()`, `vListInsert()`, `uxListRemove()` | How do circular doubly-linked lists provide $O(1)$ ready-list insertion and priority-ordered event list queuing? |
| **`FreeRTOS-Kernel/portable/MemMang/heap_4.c`** | `pvPortMalloc()` & `vPortFree()` | How does first-fit block coalescing prevent memory fragmentation? Contrast with static allocation (`xTaskCreateStatic`). |

---

# Part 5 — Complete Module Sequence

## P2-M01 — Reset, Startup, Linker Script, and Vector Table

- **Module ID:** `P2-M01`
- **Title:** Reset, Startup, Linker Script, and Vector Table
- **Why Now:** Firmware engineers must not treat MCU startup as vendor black-box magic. Understanding how the CPU transitions from power-on reset to `main()` connects C variables with physical memory and demystifies the vector table before introducing interrupts.
- **Prerequisites:** Phase 1 M03 (ELF, sections, symbols, Make).
- **Mental Model:** Flash memory holds the cold immutable image; RAM is volatile scratchpad. Startup code is the physical bridge that loads the initial stack pointer, configures vector addresses, copies initialized data from Flash to RAM, zeroes uninitialized variables, and jumps into compiled C code.
- **Minimal Theory:**
  - Armv7-M boot sequence: CPU reads 32-bit initial MSP value from `0x08000000`, then reads initial PC (Reset Vector address) from `0x08000004`.
  - Bit 0 of vector addresses must be `1` to indicate Thumb state; loading an even address into PC triggers an immediate `UsageFault` (INVSTATE).
  - Linker script `MEMORY` and `SECTIONS` commands: defining `FLASH (rx)` and `RAM (rwx)`.
  - Section placement: `.isr_vector` at Flash origin; `.text` and `.rodata` in Flash; `.data` loaded in Flash (LMA) but executed in RAM (VMA); `.bss` allocated in RAM.
  - Startup runtime initialization: using linker exported symbols (`_sidata`, `_sdata`, `_edata`, `_sbss`, `_ebss`) to perform memory loops.
- **Official Source:**
  - ST RM0008, Section 3.3 (Embedded SRAM) & Section 3.4 (Flash memory).
  - ST PM0056, Section 2.1 (Processor modes and stacks) & Section 2.2 (Memory model).
  - Armv7-M Architecture Reference Manual (DDI 0403E.e), Section B1.5.3 (Reset behavior).
  - GNU Binutils LD Manual (Linker Scripts: Memory Layout & Section Placement).
- **Exact Upstream Source Path:**
  - `cmsis_device_f1/Source/Templates/gcc/startup_stm32f103xb.s` (Lines 45–140: `g_pfnVectors` & `Reset_Handler`).
  - `cmsis_device_f1/Source/Templates/gcc/linker/stm32f103xb_flash.ld` (Lines 35–110).
- **Labs:**
  - **Objective:** Build a complete, bootable bare-metal firmware image from an empty directory using only a custom linker script, minimal assembly startup, and `main.c` that toggles an LED via register addresses.
  - **Prerequisites:** GNU Arm toolchain (`arm-none-eabi-gcc`), Make, OpenOCD, GDB.
  - **Environment:** Linux host or WSL2, STM32F103C8T6 target, ST-Link V2 SWD debugger.
  - **Estimated Time:** 2.0 h.
  - **AI Mode:** AI-Hint (only for linker script syntax reference).
  - **Build:** `arm-none-eabi-gcc -mcpu=cortex-m3 -mthumb -nostdlib -T link.ld startup.s main.c -o firmware.elf`.
  - **Procedure:**
    1. Write `link.ld` declaring Flash at `0x08000000` (64K) and RAM at `0x20000000` (20K).
    2. Write `startup.s` with vector table containing `_estack` and `Reset_Handler`.
    3. Implement `.data` copy loop and `.bss` clear loop in assembly or early C.
    4. Write `main()` configuring GPIOC pin 13 to turn on the on-board LED.
    5. Flash target with OpenOCD; inspect registers in GDB before and after `Reset_Handler`.
  - **Expected Observation:** GDB halts at `Reset_Handler`; registers `r0` and `r1` hold `_sdata` and `_edata`; stepping through the copy loop initializes global variables in RAM; target boots cleanly into `main()`.
  - **Actual Verification Status:** `UNVERIFIED` (curriculum design baseline).
  - **Questions:** Why does the PC register in GDB display an even address when the vector table contains an odd address? What occurs if `.bss` is not zeroed?
  - **Failure Modes:** Target enters infinite `HardFault_Handler` due to missing Thumb bit; global variables evaluate to zero because `.data` copy loop bounds are inverted.
  - **Debug Strategy:** Connect GDB; issue `x/8wx 0x08000000` to inspect vector table; verify SP and PC match ELF symbols via `arm-none-eabi-nm`.
  - **Challenge:** Implement a stack canary in the linker script (`_stack_canary`) and verify in `main()` that initial stack allocation has not overflowed.
  - **Cleanup:** Erase Flash via `openocd -f interface/stlink.cfg -f target/stm32f1x.cfg -c "init; reset halt; stm32f1x mass_erase 0; exit"`.
  - **Sources:** PM0056 Section 2.1; RM0008 Section 3.
- **Expected Evidence:** Disassembly listing showing vector table at `0x08000000`, `arm-none-eabi-readelf -l firmware.elf` showing LMA vs VMA addresses, GDB register dump at `main()`.
- **Challenge:** Reconstruct a working startup file and linker script entirely from memory in a blank directory within 25 minutes.
- **Deliberate Fault:** Vector alignment fault: place `.isr_vector` with misaligned address or clear bit 0 of the Reset Vector function pointer.
- **Gate:** AI-Free: Diagnose an unknown non-booting ELF image that jumps directly to `HardFault`, extract the vector table and linker map, identify the offset error, fix the linker script, and achieve clean execution of `main()`.
- **Mastery Target:** L3 Linker/Startup reasoning, L4-local boot fault debugging.
- **AI Mode:** AI-Hint for lab; AI-Free for Gate.
- **Estimated Hours:** 3.5 h MUST, 1.0 h SHOULD.
- **Career Relevance:** Essential for BSP bring-up, custom bootloader development, and memory partitioning in production firmware.

---

## P2-M02 — MMIO, Clock Tree, Hardware Timers, and NVIC Mechanism

- **Module ID:** `P2-M02`
- **Title:** MMIO, Clock Tree, Hardware Timers, and NVIC Mechanism
- **Why Now:** Preemptive RTOS scheduling requires hardware timers and interrupt handling. Before using an RTOS tick, learners must understand peripheral bus clocks, NVIC interrupt grouping, and the hazards of manipulating shared hardware registers.
- **Prerequisites:** P2-M01 (bare-metal boot and register access).
- **Mental Model:** The MCU is a synchronized clock distribution network feeding independent memory-mapped peripheral state machines. Interrupts are hardware-invoked subroutines prioritized by the NVIC; failing to acknowledge an interrupt in the peripheral register results in an infinite execution lockup (interrupt storm).
- **Minimal Theory:**
  - Clock Tree: HSI (8 MHz internal RC) vs HSE (8 MHz crystal) $\to$ PLL multiplier ($\times 9$) $\to$ SYSCLK (72 MHz) $\to$ AHB divider (/1, 72 MHz) $\to$ APB1 divider (/2, 36 MHz max) and APB2 divider (/1, 72 MHz max).
  - APB Peripheral Clock Gating: Peripherals cannot be read or written until their clock is enabled in `RCC->APB1ENR` or `RCC->APB2ENR`.
  - Timers: Counter (`CNT`), Prescaler (`PSC`), Auto-Reload (`ARR`).
    $$f_{\text{update}} = \frac{f_{\text{timer\_clock}}}{(\text{PSC} + 1) \times (\text{ARR} + 1)}$$
  - NVIC Architecture: Interrupt Set-Enable (`NVIC->ISER`), Clear-Enable (`NVIC->ICER`), Priority Registers (`NVIC->IP`), and Application Interrupt and Reset Control Register (`SCB->AIRCR`).
  - Read-Modify-Write (RMW) Hazards: Why bitwise operations on `GPIOx->ODR` fail under concurrent interrupt preemption, and how atomic `GPIOx->BSRR` resolves it.
- **Official Source:**
  - ST RM0008, Section 6 (RCC), Section 9 (GPIO), Section 10 (Interrupts and Events), Section 14 (TIM2/3/4).
  - ST PM0056, Section 4.3 (NVIC) & Section 4.4 (SCB).
  - Armv7-M Architecture Reference Manual (DDI 0403E.e), Section B3.4 (NVIC).
- **Exact Upstream Source Path:**
  - `cmsis_device_f1/Include/stm32f103xb.h` (Peripheral structure typedefs: `RCC_TypeDef`, `GPIO_TypeDef`, `TIM_TypeDef`).
  - `CMSIS_5/CMSIS/Core/Include/core_cm3.h` (Lines 1500–1650: `NVIC_SetPriority()`, `NVIC_EnableIRQ()`).
- **Labs:**
  - **Objective:** Configure the PLL clock tree to 72 MHz; configure TIM2 to generate an interrupt exactly every 1.0 ms; toggle a GPIO marker pin inside `TIM2_IRQHandler`; observe timing on an oscilloscope or logic analyzer; verify RMW race conditions.
  - **Prerequisites:** P2-M01.
  - **Environment:** STM32F103C8T6, ST-Link V2, oscilloscope or logic analyzer connected to PA1 and PA2.
  - **Estimated Time:** 2.5 h.
  - **AI Mode:** AI-Hint.
  - **Build:** `make clean && make`.
  - **Procedure:**
    1. Configure Flash latency to 2 wait states for 72 MHz operation (`FLASH->ACR`).
    2. Enable HSE, wait for `HSERDY`; configure PLL multiplier to 9; switch SYSCLK to PLL.
    3. Enable TIM2 clock in `RCC->APB1ENR`. Set `TIM2->PSC` and `TIM2->ARR` for 1000 Hz.
    4. Enable TIM2 update interrupt (`TIM2->DIER |= TIM_DIER_UIE`).
    5. Set NVIC priority for `TIM2_IRQn` and enable it in `NVIC->ISER`.
    6. In `TIM2_IRQHandler`, toggle PA1 using `BSRR` and clear `TIM2->SR = ~TIM_SR_UIF`.
    7. In `main()`, rapidly toggle PA2 using non-atomic `ODR |= ...; ODR &= ...;` while TIM2 interrupts preempt it.
  - **Expected Observation:** PA1 generates a stable 500 Hz square wave (1.0 ms toggle interval) verified on oscilloscope; PA2 exhibits occasional missing edges or glitches due to RMW preemption.
  - **Actual Verification Status:** `UNVERIFIED` (curriculum design baseline).
  - **Questions:** What occurs if the Flash wait state is set to 0 before switching SYSCLK to 72 MHz? Why must `TIM2->SR` be cleared before exiting the ISR?
  - **Failure Modes:** CPU enters infinite ISR loop because `UIF` flag was not cleared; timer runs at half expected speed because APB1 prescaler clock doubling rule was overlooked.
  - **Debug Strategy:** Read `RCC->CFGR` in GDB to confirm active clock source; read `TIM2->SR` to verify interrupt flag clearing; inspect `SCB->ICSR` for pending interrupt status.
  - **Challenge:** Configure TIM3 with a higher preemption priority than TIM2; measure interrupt nesting latency using two oscilloscope channels.
  - **Cleanup:** Reset peripheral clocks via `RCC->APB1RSTR` and `RCC->APB2RSTR`.
  - **Sources:** RM0008 Sections 6, 9, 14; PM0056 Section 4.3.
- **Expected Evidence:** Oscilloscope capture of 1.0 ms timer pulse on PA1; GDB printout of `RCC->CR`, `RCC->CFGR`, `TIM2->PSC`, `TIM2->ARR`.
- **Challenge:** Implement a software PWM on 4 pins using a single timer channel and output compare registers without HAL libraries.
- **Deliberate Fault:** Omit clearing `TIM2->SR = ~TIM_SR_UIF` in the ISR; observe target execution hanging in the ISR with main thread starved.
- **Gate:** AI-Free: Given a system where the timer interrupt fires at an erratic frequency and the main loop halts, inspect peripheral registers in GDB, diagnose clock tree misconfiguration and missing flag acknowledgment, and restore deterministic 1 kHz timing.
- **Mastery Target:** L4-local register & MMIO interaction, L3 NVIC interrupt handling.
- **AI Mode:** AI-Hint for lab; AI-Free for Gate.
- **Estimated Hours:** 4.5 h MUST, 1.0 h SHOULD.
- **Career Relevance:** Directly maps to writing Linux peripheral drivers, setting up hardware interrupt handlers, and diagnosing hardware lockups in production.

---

## P2-M03 — Peripheral Acquisition & DMA Data Path

- **Module ID:** `P2-M03`
- **Title:** Peripheral Acquisition & DMA Data Path
- **Why Now:** Real embedded nodes cannot waste CPU cycles polling ADC samples or copying serial bytes. DMA is the standard hardware mechanism for high-throughput, low-jitter data acquisition.
- **Prerequisites:** P2-M02 (clocks, peripherals, and interrupts).
- **Mental Model:** Direct Memory Access (DMA) is an autonomous bus master coexisting with the CPU. It moves data blocks between peripheral registers and SRAM across the AHB bus matrix. The CPU initiates the transaction and configures circular boundaries; the DMA controller handles data transfers silently in the background, signaling the CPU only when half-buffer or full-buffer milestones are reached.
- **Minimal Theory:**
  - STM32F103 DMA1 Architecture: 7 independent channels; fixed hardware request mapping (DMA1 Channel 1 is dedicated to ADC1).
  - DMA Channel Registers: Peripheral Address (`CPAR`), Memory Address (`CMAR`), Number of Data items (`CNDTR`), Configuration (`CCR`).
  - Transfer Configuration: Data direction (Peripheral-to-Memory), Circular mode (`CIRC`), Memory increment (`MINC`), Peripheral/Memory data size (16-bit to 16-bit matching ADC resolution).
  - Timer Triggered ADC Acquisition: TIM2 Update event (TRGO) triggers ADC regular conversion $\to$ ADC conversion completion automatically asserts DMA request $\to$ DMA transfers sample to SRAM array and decrements `CNDTR`.
  - Ping-Pong (Double) Buffering: Buffer split into two halves:
    $$\text{Buffer} = [\text{Half 0} \mid \text{Half 1}]$$
    - DMA Half-Transfer Complete (HT) interrupt fires when Half 0 is full; CPU processes Half 0 while DMA autonomously fills Half 1.
    - DMA Transfer Complete (TC) interrupt fires when Half 1 is full; CPU processes Half 1 while DMA wraps around to overwrite Half 0.
  - Buffer Lifetime Hazard: Declaring a DMA buffer with automatic storage duration (on a local stack) leads to memory corruption if the function returns while DMA continues. DMA buffers must have static storage duration or persistent heap lifetime.
- **Official Source:**
  - ST RM0008, Section 11 (ADC) & Section 13 (DMA controller).
  - ST Datasheet DS5319, Section 5.3.18 (12-bit ADC characteristics).
- **Exact Upstream Source Path:**
  - `cmsis_device_f1/Include/stm32f103xb.h` (DMA structure `DMA_Channel_TypeDef`, ADC structure `ADC_TypeDef`).
- **Labs:**
  - **Objective:** Configure TIM2 TRGO to trigger ADC1 at 10 kHz; configure DMA1 Channel 1 in circular mode to transfer 16-bit ADC samples into a 128-element double buffer (`uint16_t adc_buffer[2][64]`); handle Half-Transfer and Transfer-Complete interrupts; toggle PA3 on HT and PA4 on TC; inspect memory in GDB while CPU sleeps (`__WFI()`).
  - **Prerequisites:** P2-M02.
  - **Environment:** STM32F103C8T6, analog input signal on PA0 (potentiometer or function generator), logic analyzer on PA3 and PA4.
  - **Estimated Time:** 2.5 h.
  - **AI Mode:** AI-Hint.
  - **Build:** `make clean && make`.
  - **Procedure:**
    1. Enable clocks for GPIOA, ADC1, and DMA1 in RCC.
    2. Configure PA0 as analog input (`GPIO_CRL_CNF0 = 00`, `MODE0 = 00`).
    3. Configure TIM2 for 10 kHz TRGO output (`TIM_CR2_MMS = 010` Update).
    4. Configure ADC1: external trigger conversion on TIM2 TRGO (`ADC_CR2_EXTSEL = 001`), DMA mode enabled (`ADC_CR2_DMA = 1`). Calibrate ADC.
    5. Configure DMA1 Channel 1: `CPAR = (uint32_t)&ADC1->DR`, `CMAR = (uint32_t)adc_buffer`, `CNDTR = 128`, `CIRC = 1`, `MINC = 1`, `PSIZE = 01` (16-bit), `MSIZE = 01` (16-bit), `HTIE = 1`, `TCIE = 1`.
    6. Enable `DMA1_Channel1_IRQn` in NVIC. In `main()`, enter low-power sleep `while(1) { __WFI(); }`.
    7. In `DMA1_Channel1_IRQHandler`, toggle PA3 if `HTIF` is set, toggle PA4 if `TCIF` is set; clear flags in `DMA1->IFCR`.
  - **Expected Observation:** Logic analyzer shows alternating pulses on PA3 and PA4 at exactly 78.125 Hz ($\frac{10000\text{ Hz}}{128\text{ samples}} \approx 78.125\text{ Hz}$); GDB memory inspection (`x/128hx adc_buffer`) shows changing analog values without CPU intervention.
  - **Actual Verification Status:** `UNVERIFIED` (curriculum design baseline).
  - **Questions:** What happens if `MSIZE` is configured as 8-bit while `PSIZE` is 16-bit? Why does ADC data become corrupted if DMA circular mode is disabled?
  - **Failure Modes:** DMA transfers zero samples because `ADC_CR2_DMA` bit was not set; DMA transfers corrupt values because peripheral address was set to `&ADC1` instead of `&ADC1->DR`.
  - **Debug Strategy:** Read `DMA1_Channel1->CNDTR` in GDB: if it is decremented, DMA is running; if stalled at 128, check trigger and clock configuration; inspect `DMA1->ISR` for Transfer Error (`TEIF`).
  - **Challenge:** Implement a rolling moving average filter on the inactive half-buffer inside the DMA ISR and measure execution time as a percentage of total buffer period.
  - **Cleanup:** Disable DMA channel (`DMA1_Channel1->CCR &= ~DMA_CCR_EN`) and ADC.
  - **Sources:** RM0008 Sections 11, 13.
- **Expected Evidence:** Logic analyzer capture showing precise periodic toggling of HT and TC marker pins; GDB memory dump of `adc_buffer` showing realistic analog conversions.
- **Challenge:** Modify the DMA configuration to read from two interleaved ADC channels (temperature sensor and PA0) in scan mode and verify channel alignment in memory.
- **Deliberate Fault:** Allocate `adc_buffer` as a local stack array inside an initialization function that exits; observe unpredictable data corruption as subsequent function calls overwrite the buffer while DMA transfers continue.
- **Gate:** AI-Free: Diagnose a stalled DMA data path where `CNDTR` does not decrement; trace the fault through TIM TRGO configuration, ADC trigger selection, and DMA request enabling; fix the register configuration and prove autonomous circular acquisition.
- **Mastery Target:** L2–L3 DMA data path mastery, L4-local peripheral trigger debugging.
- **AI Mode:** AI-Hint for lab; AI-Free for Gate.
- **Estimated Hours:** 4.5 h MUST, 1.0 h SHOULD.
- **Career Relevance:** Direct foundation for Linux Industrial I/O (IIO) drivers, audio ALSA ring buffers, and zero-copy network DMA drivers.

---

## P2-M04 — FreeRTOS Scheduler, Task Lifecycle, Lists, and Cortex-M Context Switch

- **Module ID:** `P2-M04`
- **Title:** FreeRTOS Scheduler, Task Lifecycle, Lists, and Cortex-M Context Switch
- **Why Now:** Having mastered bare-metal exception frames, stack pointers, and timer interrupts, the learner is prepared to understand how an RTOS multiplexes the physical CPU across multiple execution contexts.
- **Prerequisites:** P2-M01 (stack frames, MSP/PSP), P2-M02 (SysTick, PendSV, NVIC).
- **Mental Model:** A task is an infinite loop equipped with a private stack and a Task Control Block (TCB). The scheduler is a state machine moving TCBs between linked lists (Ready, Blocked, Suspended). Context switching is simply the deliberate preservation and restoration of CPU register state across task stacks using the PendSV exception.
- **Minimal Theory:**
  - Task States: Running, Ready, Blocked (delay or event), Suspended.
  - FreeRTOS Task Lists: `pxReadyTasksLists[uxPriority]` (one doubly-linked list per priority level), `xDelayedTaskList1`, `xDelayedTaskList2`, `xPendingReadyList`.
  - The System Tick: SysTick interrupt invokes `xTaskIncrementTick()`. If a blocked task's delay expires and its priority is $\ge$ currently running task, `xSwitchRequired` is flagged.
  - PendSV (Pended Servicing): PendSV is configured with the lowest interrupt priority (`0xFF`). It runs only after all hardware ISRs complete, preventing interrupt latency inflation. Triggered via `SCB->ICSR[PENDSVSET]`.
  - Context Switch Mechanics in `xPortPendSVHandler`:
    1. Read current task's PSP: `mrs r0, psp`.
    2. Hardware has already stacked `{r0-r3, r12, lr, pc, xpsr}` on PSP.
    3. Software manually pushes remaining registers: `stmdb r0!, {r4-r11}`.
    4. Save updated stack pointer into `pxCurrentTCB->pxTopOfStack`.
    5. Call `vTaskSwitchContext()` to select new `pxCurrentTCB`.
    6. Load new `pxCurrentTCB->pxTopOfStack` into `r0`.
    7. Software pops `{r4-r11}`: `ldmia r0!, {r4-r11}`.
    8. Write new stack pointer to PSP: `msr psp, r0`.
    9. Return from exception via `bx r14` (`EXC_RETURN = 0xFFFFFFFD`); hardware automatically unrolls `{r0-r3, r12, lr, pc, xpsr}` from new task's PSP.
- **Official Source:**
  - FreeRTOS-Kernel Upstream V11.3.0 (`tasks.c`, `portable/GCC/ARM_CM3/port.c`, `list.c`).
  - Armv7-M Architecture Reference Manual, Section B1.5 (Exception entry and return).
  - ST PM0056, Section 2.1 (Stack pointers) & Section 4.4.4 (ICSR).
- **Exact Upstream Source Path:**
  - `FreeRTOS-Kernel/tasks.c` (`vTaskSwitchContext`, lines 3200–3350; `xTaskIncrementTick`, lines 3000–3150).
  - `FreeRTOS-Kernel/portable/GCC/ARM_CM3/port.c` (`xPortPendSVHandler`, lines 220–280; `prvPortStartFirstTask`, lines 180–215).
- **Labs:**
  - **Objective:** Integrate the FreeRTOS kernel into the bare-metal project; create two tasks with different priorities that toggle GPIO pins at distinct intervals; set a breakpoint in `xPortPendSVHandler` in GDB; manually inspect the hardware and software stack frames on PSP and verify register restoration.
  - **Prerequisites:** P2-M01, P2-M02.
  - **Environment:** STM32F103C8T6, OpenOCD + GDB, logic analyzer on PA1 and PA2.
  - **Estimated Time:** 3.0 h.
  - **AI Mode:** AI-Hint (for GDB navigation).
  - **Build:** `make clean && make`.
  - **Procedure:**
    1. Add `FreeRTOS-Kernel` sources (`tasks.c`, `list.c`, `queue.c`, `portable/GCC/ARM_CM3/port.c`, `heap_4.c`) to Makefile.
    2. Write minimal `FreeRTOSConfig.h` with `configCPU_CLOCK_HZ = 72000000`, `configTICK_RATE_HZ = 1000`, `configMAX_PRIORITIES = 5`, `configMINIMAL_STACK_SIZE = 128`.
    3. Remap or alias FreeRTOS exception handlers to vector table: `vPortSVCHandler` $\to$ `SVC_Handler`, `xPortPendSVHandler` $\to$ `PendSV_Handler`, `xPortSysTickHandler` $\to$ `SysTick_Handler`.
    4. Create `Task_A` (priority 2, toggles PA1 every 5 ms via `vTaskDelay(pdMS_TO_TICKS(5))`).
    5. Create `Task_B` (priority 1, toggles PA2 continuously with CPU burn loop).
    6. Start scheduler (`vTaskStartScheduler()`).
    7. In GDB: `b xPortPendSVHandler`, step through `mrs r0, psp` and inspect memory at PSP (`x/16wx $r0`); confirm saved PC points to `Task_A` or `Task_B`.
  - **Expected Observation:** Logic analyzer shows PA1 preemption of PA2; GDB confirms that at entry to `xPortPendSVHandler`, PSP points to 16 words containing `{r4-r11}` followed by `{r0-r3, r12, lr, pc, xpsr}`.
  - **Actual Verification Status:** `UNVERIFIED` (curriculum design baseline).
  - **Questions:** Why must `configKERNEL_INTERRUPT_PRIORITY` be set to the lowest priority (`0xFF`)? What happens if `SVC_Handler` is omitted from the vector table?
  - **Failure Modes:** CPU faults immediately upon `vTaskStartScheduler()` because vector table still points to dummy default handlers for SysTick or SVC; system hangs because `configTOTAL_HEAP_SIZE` exceeds available SRAM.
  - **Debug Strategy:** Check `SCB->CFSR` and `SCB->HFSR` in GDB if HardFault occurs; verify `pxCurrentTCB` in GDB to determine which task was running before crash.
  - **Challenge:** Implement a basic task switch execution profiler using DWT cycle counter (`DWT->CYCCNT`) inside `traceTASK_SWITCHED_IN()` and `traceTASK_SWITCHED_OUT()` macros.
  - **Cleanup:** Halt GDB and reset target.
  - **Sources:** FreeRTOS Kernel source; PM0056 Section 2.1.
- **Expected Evidence:** GDB session transcript showing register values at `xPortPendSVHandler`; logic analyzer capture proving preemptive task switching.
- **Challenge:** Implement a bare-bones 2-task cooperative context switcher in raw assembly without FreeRTOS to prove complete understanding of the mechanism before using the kernel.
- **Deliberate Fault:** Set PendSV priority to `0` (highest); observe that nested hardware interrupts are blocked during context switches, causing timer jitter or missed peripheral events.
- **Gate:** AI-Free: Given a corrupted task stack frame resulting in a `UsageFault` during exception return (`BX LR`), analyze the stack dump in GDB, identify whether software registers `{r4-r11}` or hardware registers `{r0-r3, pc, xpsr}` were corrupted, and pinpoint the root cause.
- **Mastery Target:** L3 FreeRTOS kernel mechanics, L3 Cortex-M port architecture.
- **AI Mode:** AI-Hint for lab; AI-Free for Gate.
- **Estimated Hours:** 5.0 h MUST, 1.0 h SHOULD.
- **Career Relevance:** Fundamental for understanding real-time scheduling guarantees, RTOS porting, Linux process context switching, and debugging task crash dumps.

---

## P2-M05 — Queue, Mutex, and ISR-Safe Synchronization Boundaries

- **Module ID:** `P2-M05`
- **Title:** Queue, Mutex, and ISR-Safe Synchronization Boundaries
- **Why Now:** Real embedded applications require safe, deterministic communication across task-to-task and ISR-to-task boundaries. Misusing synchronization APIs across the interrupt boundary is one of the most common causes of silent firmware corruption.
- **Prerequisites:** P2-M02 (NVIC priorities), P2-M04 (scheduler and task states).
- **Mental Model:** A queue is a protected, bounded ring buffer combined with two wait-lists (tasks blocked waiting to send, tasks blocked waiting to receive). A mutex is a specialized queue of length 1 featuring ownership and priority inheritance. Interrupt handlers must never block; they use non-blocking `FromISR` APIs and request deferred task preemption via `portYIELD_FROM_ISR()`.
- **Minimal Theory:**
  - Queue Memory Model: Storage area allocated contiguously; data is copied by value (`memcpy`), avoiding ownership hazards for small payloads; pointers are sent for large payloads.
  - Blocking & Unblocking: When a task calls `xQueueReceive()` on an empty queue:
    1. It removes itself from `pxReadyTasksLists`.
    2. It adds its `xEventListItem` to `xTasksWaitingToReceive`.
    3. It adds its `xStateListItem` to `pxDelayedTaskList` with the specified timeout.
    4. It triggers a context switch.
  - When an ISR calls `xQueueSendFromISR()`:
    1. It copies data into the queue.
    2. If a task was waiting, it removes the task from `xTasksWaitingToReceive` and places it onto `xPendingReadyList`.
    3. It sets `*pxHigherPriorityTaskWoken = pdTRUE`.
    4. The ISR calls `portYIELD_FROM_ISR(xHigherPriorityTaskWoken)`, which sets the `PENDSVSET` bit in `SCB->ICSR`.
    5. As soon as the ISR exits, PendSV executes immediately, switching context directly to the unblocked task.
  - The `configMAX_SYSCALL_INTERRUPT_PRIORITY` Boundary:
    - Any ISR with an NVIC priority numerically lower (higher urgency) than `configMAX_SYSCALL` **must never** call any FreeRTOS API! Violating this corrupts kernel lists because `portENTER_CRITICAL()` only masks priorities up to `configMAX_SYSCALL` via `BASEPRI`.
  - Mutex vs Binary Semaphore:
    - Binary Semaphore: Signaling mechanism. Can be given by one entity (e.g. ISR) and taken by another (task). No ownership tracking; no priority inheritance.
    - Mutex: Mutual exclusion mechanism. Must be unlocked by the exact task that locked it (`pxMutexHolder`). Implements priority inheritance to prevent unbounded priority inversion.
- **Official Source:**
  - FreeRTOS-Kernel Upstream V11.3.0 (`queue.c`, `tasks.c`).
  - FreeRTOS Official Documentation: "Mastering the FreeRTOS Real Time Kernel" Chapters 4 (Queue Management) & 7 (Interrupt Management).
- **Exact Upstream Source Path:**
  - `FreeRTOS-Kernel/queue.c` (`xQueueGenericSend`, lines 750–900; `xQueueGenericSendFromISR`, lines 1200–1320; `xQueueGenericReceive`, lines 1350–1500).
- **Labs:**
  - **Objective:** Build an ISR-to-Task pipeline: configure a periodic timer ISR to enqueue an incrementing sequence number using `xQueueSendFromISR()`; unblock a consumer task that verifies sequence continuity; test system behavior when ISR priority violates `configMAX_SYSCALL_INTERRUPT_PRIORITY`.
  - **Prerequisites:** P2-M03, P2-M04.
  - **Environment:** STM32F103C8T6, OpenOCD + GDB, logic analyzer on ISR pin (PA1) and Task pin (PA2).
  - **Estimated Time:** 2.5 h.
  - **AI Mode:** AI-Hint.
  - **Build:** `make clean && make`.
  - **Procedure:**
    1. Create a queue `xQueue = xQueueCreate(10, sizeof(uint32_t))`.
    2. Configure TIM2 interrupt with NVIC priority `0x60` (numerical 6, valid syscall priority if `configMAX_SYSCALL` is `0x50`).
    3. In `TIM2_IRQHandler`, call `xQueueSendFromISR(xQueue, &val, &xHigherPriorityTaskWoken)`.
    4. Call `portYIELD_FROM_ISR(xHigherPriorityTaskWoken)`. Toggle PA1.
    5. In `Task_Consumer` (priority 3), block on `xQueueReceive(xQueue, &rx_val, portMAX_DELAY)`. Toggle PA2 upon unblocking.
    6. Measure $\Delta t$ between PA1 falling and PA2 rising on logic analyzer (ISR-to-Task latency).
    7. Intentionally change TIM2 NVIC priority to `0x20` (numerical 2, higher priority than syscall limit) and observe kernel assertion or crash.
  - **Expected Observation:** Logic analyzer shows Task_Consumer unblocking within microseconds of ISR exit; setting invalid priority triggers `configASSERT` in `vPortValidateInterruptPriority()`.
  - **Actual Verification Status:** `UNVERIFIED` (curriculum design baseline).
  - **Questions:** Why cannot `xQueueSend()` (the blocking version) be called inside an ISR? What occurs if `portYIELD_FROM_ISR` is omitted?
  - **Failure Modes:** Task misses packets because queue is full; kernel crashes silently because NVIC priority was configured with wrong priority group bits (`SCB->AIRCR`).
  - **Debug Strategy:** Set breakpoint in `vPortValidateInterruptPriority()`; print `ulCurrentInterrupt` and `ucCurrentPriority` in GDB.
  - **Challenge:** Replace the queue with Direct-to-Task Notifications (`vTaskNotifyGiveFromISR` / `ulTaskNotifyTake`) and compare context switch latency and RAM footprint.
  - **Cleanup:** Reset NVIC priorities to safe defaults.
  - **Sources:** FreeRTOS Kernel `queue.c`; PM0056 Section 4.3.
- **Expected Evidence:** Logic analyzer trace showing exact ISR-to-task handover timing; GDB session capturing priority validation assertion.
- **Challenge:** Implement a thread-safe circular memory pool where only pointers are passed through the queue, with zero dynamic memory allocation after startup.
- **Deliberate Fault:** Call `xQueueSend()` from inside `TIM2_IRQHandler` instead of `xQueueSendFromISR()`; observe immediate HardFault due to PSP/MSP stack context confusion.
- **Gate:** AI-Free: Audit a provided firmware source exhibiting random deadlocks and queue packet corruption; identify two NVIC priority configuration defects and one missing `portYIELD_FROM_ISR` call; verify correct execution with GDB and logic analyzer traces.
- **Mastery Target:** L3 synchronization mechanisms, L3 ISR handoff protocol.
- **AI Mode:** AI-Hint for lab; AI-Free for Gate.
- **Estimated Hours:** 4.5 h MUST, 1.0 h SHOULD.
- **Career Relevance:** Directly transfers to Linux interrupt bottom-half processing (threaded IRQs, workqueues), device driver ring buffers, and real-time audio/telemetry pipelines.

---

## P2-M06 — Priority Inversion, Inheritance, Stack Watermark, and Timing Debugging

- **Module ID:** `P2-M06`
- **Title:** Priority Inversion, Inheritance, Stack Watermark, and Timing Debugging
- **Why Now:** Multi-task systems frequently fail due to timing and concurrency defects: priority inversion starving critical tasks, or undetected stack exhaustion causing silent memory corruption. Engineers must master diagnosis of these failure modes before deploying integrated systems.
- **Prerequisites:** P2-M04 (scheduler), P2-M05 (mutexes and queues).
- **Mental Model:** 
  - *Unbounded Priority Inversion:* A low-priority task holds a shared resource needed by a high-priority task. A medium-priority task preempts the low-priority task (because it needs no lock), indirectly starving the high-priority task for an unbounded duration.
  - *Priority Inheritance:* When a high-priority task blocks on a mutex held by a low-priority task, the kernel temporarily boosts the low-priority task to the high-priority level until the mutex is released.
  - *Stack Watermark:* Stacks grow downward. The kernel fills each allocated stack with a known pattern (`0xA5`). The high-water mark is determined by scanning upward from the stack limit to find the lowest untouched `0xA5` byte.
- **Minimal Theory:**
  - Mars Pathfinder Bug: The textbook real-world priority inversion failure (information bus mutex shared between meteorological task and attitude control task, interrupted by communications task).
  - Priority Inheritance Mechanism in `tasks.c`:
    ```c
    /* Inside xTaskPriorityInherit() */
    if( pxTCB->uxPriority < pxCurrentTCB->uxPriority ) {
        pxTCB->uxPriority = pxCurrentTCB->uxPriority;
        /* Move TCB to appropriate ready list if already ready */
    }
    ```
  - Binary Semaphore vs Mutex for Locking: Why using a binary semaphore for resource mutual exclusion fails: semaphores have no owner, so priority inheritance cannot function!
  - Stack Sizing & Overflow Detection:
    - Method 1: Check if SP is within stack bounds during context switch (`pxCurrentTCB->pxTopOfStack <= pxCurrentTCB->pxStack`).
    - Method 2: Check if the last 16 bytes of the stack still contain `0xA5` (`vApplicationStackOverflowHook`).
    - Stack Watermark API: `uxTaskGetStackHighWaterMark()`.
  - Independent Watchdog (IWDG): Dedicated low-speed internal clock (LSI ~40 kHz). Requires periodic refresh (`IWDG->KR = 0xAAAA`); resets CPU if a deadlock or infinite loop stalls the health monitoring task.
- **Official Source:**
  - FreeRTOS-Kernel Upstream V11.3.0 (`tasks.c`, `queue.c`).
  - ST RM0008, Section 24 (Independent Watchdog - IWDG).
  - "Mastering the FreeRTOS Real Time Kernel", Chapter 8 (Resource Management).
- **Exact Upstream Source Path:**
  - `FreeRTOS-Kernel/tasks.c` (`xTaskPriorityInherit`, lines 4200–4280; `xTaskPriorityDisinherit`, lines 4300–4390; `uxTaskGetStackHighWaterMark`, lines 4400–4450).
- **Labs:**
  - **Objective:** Construct a 3-task setup (High, Medium, Low) sharing a resource; demonstrate unbounded priority inversion using a binary semaphore; resolve it using a Mutex with priority inheritance; deliberately trigger a stack overflow and verify hook execution; configure the IWDG.
  - **Prerequisites:** P2-M04, P2-M05.
  - **Environment:** STM32F103C8T6, logic analyzer on Task High (PA1), Task Medium (PA2), Task Low (PA3).
  - **Estimated Time:** 2.5 h.
  - **AI Mode:** AI-Hint.
  - **Build:** `make clean && make`.
  - **Procedure:**
    1. Create `Task_Low` (prio 1), `Task_Med` (prio 2), `Task_High` (prio 3).
    2. Shared lock: `xSemaphoreCreateBinary()`.
    3. `Task_Low` takes lock, starts prolonged computation.
    4. `Task_High` awakens and blocks on lock.
    5. `Task_Med` awakens and executes continuous work.
    6. Observe on logic analyzer: `Task_High` is starved while `Task_Med` runs, despite `Task_High` having higher priority (unbounded priority inversion).
    7. Replace binary semaphore with `xSemaphoreCreateMutex()`.
    8. Observe on logic analyzer: `Task_Low` inherits priority 3, completes its critical section immediately, releases mutex, and `Task_High` runs without delay from `Task_Med`.
    9. In `Task_Low`, allocate a 256-byte local array on a 128-byte stack; verify CPU halts in `vApplicationStackOverflowHook()`.
  - **Expected Observation:** Logic analyzer waveform proves that priority inheritance caps `Task_High` latency to exactly the duration of `Task_Low`'s critical section.
  - **Actual Verification Status:** `UNVERIFIED` (curriculum design baseline).
  - **Questions:** Why can't priority inheritance prevent all latency? What is deadlocking and how does lock ordering prevent it?
  - **Failure Modes:** Priority inheritance fails because a binary semaphore was used; stack overflow silently corrupts adjacent TCB because `configCHECK_FOR_STACK_OVERFLOW` was not set to 2.
  - **Debug Strategy:** Inspect `pxCurrentTCB->uxPriority` and `pxCurrentTCB->uxBasePriority` in GDB during lock contention; check `vApplicationStackOverflowHook` parameters.
  - **Challenge:** Implement priority ceiling protocol manually and compare worst-case blocking time against priority inheritance.
  - **Cleanup:** Reset watchdog and restore safe stack allocations.
  - **Sources:** FreeRTOS `tasks.c`; RM0008 Section 24.
- **Expected Evidence:** Logic analyzer traces capturing both the failure (priority inversion) and the fix (priority inheritance); GDB stack memory dump showing `0xA5` fill pattern.
- **Challenge:** Create a circular deadlock scenario with two mutexes acquired in reverse order; write a lightweight deadlock detector that audits lock acquisition timestamps.
- **Deliberate Fault:** Allocate a local structure larger than the task stack; observe `vApplicationStackOverflowHook` capturing the corrupted task name and TCB pointer.
- **Gate:** AI-Free: Given a firmware image experiencing intermittent system resets, inspect GDB memory dumps, identify a stack watermark violation in one task and a priority inversion hazard on a shared logging resource, and implement the permanent architectural fix.
- **Mastery Target:** L3 concurrency & resource management, L4-local RTOS fault debugging.
- **AI Mode:** AI-Hint for lab; AI-Free for Gate.
- **Estimated Hours:** 4.0 h MUST, 0.5 h SHOULD.
- **Career Relevance:** Essential knowledge for embedded software architecture, functional safety (automotive/aerospace), and resolving concurrency bugs in multithreaded systems.

---

# Part 6 — Time Budget Sum Table & Schedule Protection

| Module / Project ID | Title | MUST Hours | SHOULD Hours | Cumulative MUST | Primary Verification Milestone |
|---|---|---:|---:|---:|---|
| **P2-M01** | Reset, Startup, Linker Script, and Vector Table | 3.5 h | 1.0 h | 3.5 h | Bare-metal boot, memory copy loops, linker map |
| **P2-M02** | MMIO, Clock Tree, Hardware Timers, and NVIC Mechanism | 4.5 h | 1.0 h | 8.0 h | 72 MHz PLL clock, 1 kHz timer ISR, atomic BSRR |
| **P2-M03** | Peripheral Acquisition & DMA Data Path | 4.5 h | 1.0 h | 12.5 h | Timer-ADC-DMA autonomous double-buffer stream |
| **P2-M04** | FreeRTOS Scheduler, Task Lifecycle, and Context Switch | 5.0 h | 1.0 h | 17.5 h | Preemptive task scheduling, PendSV frame audit |
| **P2-M05** | Queue, Mutex, and ISR-Safe Synchronization Boundaries | 4.5 h | 1.0 h | 22.0 h | Queue pipeline, `FromISR` handoff, priority audit |
| **P2-M06** | Priority Inversion, Inheritance, Stack Watermark & Debugging | 4.0 h | 0.5 h | 26.0 h | Priority inversion proof, stack overflow hook |
| **P2-M07** | STM32 FreeRTOS Acquisition Node Integration Project | 5.0 h | 1.0 h | 31.0 h | End-to-end multi-task sensor node acceptance |
| **P2-GATE** | Phase 2 Final Gate Assessment | 3.5 h | 0.0 h | **34.5 h** | AI-Free 4-part transfer examination |
| **Total** | **Phase 2 Complete Curriculum Envelope** | **34.5 h** | **6.5 h** | **34.5 h** | **Comprehensive MCU/RTOS Mechanism Mastery** |

### Schedule Protection Rules:
1. **The 34.5 h Hard Cap:** Total mandatory workload is strictly capped at **34.5 h**, leaving an average of ~4.5–5.5 h/week unscheduled buffer against a nominal 14 h/week capacity.
2. **Buffer Insulation:** Unscheduled hours absorb hardware toolchain installation, OpenOCD driver issues on Windows/WSL2, SWD wiring glitches, and oscilloscope probe calibration.
3. **No Content Creep:** If a learner struggles with timing or interrupts, SHOULD activities (e.g. software PWM, assembly cooperative switcher, heap allocator comparisons) are dropped immediately. MUST modules are never expanded.

---

# Part 7 — Lab Matrix & Verification Integrity

| Lab ID | Module | Lab Title | Target Environment | Build Command | Key Measurable Observation | Verification Status |
|---|---|---|---|---|---|---|
| **L2-01** | P2-M01 | Bare-Metal Startup & Linker Script | STM32F103 + ST-Link | `make -C lab01` | GDB register dump at `main()` matching linker symbols | `UNVERIFIED` |
| **L2-02** | P2-M02 | 72 MHz Clock Tree & 1 kHz Timer ISR | STM32F103 + Oscilloscope | `make -C lab02` | Precise 1.0 ms square wave on PA1; RMW glitch on PA2 | `UNVERIFIED` |
| **L2-03** | P2-M03 | Autonomous ADC + DMA Double Buffer | STM32F103 + Logic Analyzer | `make -C lab03` | 78.125 Hz alternating HT/TC pulses on PA3/PA4 | `UNVERIFIED` |
| **L2-04** | P2-M04 | FreeRTOS Scheduler & PendSV Stacking | STM32F103 + GDB | `make -C lab04` | Inspection of `{r4-r11}` and hardware frame on PSP | `UNVERIFIED` |
| **L2-05** | P2-M05 | ISR-to-Task Queue Pipeline & Priority Audit | STM32F103 + Logic Analyzer | `make -C lab05` | Measured $\Delta t$ ISR-to-task latency; `configASSERT` on bad priority | `UNVERIFIED` |
| **L2-06** | P2-M06 | Priority Inversion & Inheritance Proof | STM32F103 + Logic Analyzer | `make -C lab06` | Waveform proving priority inheritance caps task latency | `UNVERIFIED` |
| **L2-07** | P2-M07 | Integrated Acquisition Node Full System | Full hardware testbench | `make -C project` | Continuous telemetry streaming, 0 dropped frames, scope latency | `UNVERIFIED` |

### Verification Integrity Protocol:
- All labs in this curriculum design document are explicitly marked **`UNVERIFIED`**.
- No fabricated register listings, oscilloscope screen captures, or GDB terminal outputs are included in this design PR.
- In subsequent implementation PRs, a lab or project may be marked **`VERIFIED`** if and only if physical execution on the target hardware produces repeatable, documented evidence.

---

# Part 8 — Required Physical & Debug Evidence

Phase 2 mandates the collection and interpretation of physical hardware signals alongside software debugger state.

```text
[Hardware Event] -----------------------------------------------------> [Oscilloscope / Logic Analyzer]
Timer Update -> ADC Trigger -> DMA Complete ISR (PA1 HIGH)                     |
                                     |                                         |---> Measure Delta-t:
                                     v                                         |     ISR-to-Task Latency
Task Unblocked -> PendSV Context Switch -> Processing Task Starts (PA2 HIGH) --+
                                     |
                                     v
[SWD / GDB Live Inspection] <--------+
  - info registers (MSP, PSP, PRIMASK, BASEPRI)
  - p *pxCurrentTCB
  - x/16wx $psp
  - print uxTaskGetStackHighWaterMark(NULL)
```

### 1. Physical Instrumentation Methods
- **GPIO Timing Markers:** Designate high-speed GPIO pins (PA1–PA4) as debug markers. Use single-cycle atomic bit set/reset instructions (`BSRR`/`BRR`) to minimize marker overhead ($< 30\text{ ns}$ at 72 MHz).
- **Oscilloscope / Logic Analyzer Channels:**
  - Channel 1 (PA1): DMA Half-Transfer / Transfer-Complete ISR entry and exit.
  - Channel 2 (PA2): Acquisition Processing Task entry and exit.
  - Channel 3 (PA3): Logging / USART Communication Task active window.
  - Channel 4 (PA4): Low-priority background / CPU idle indicator.
- **SWD / JTAG Live Inspection:** Halting or live-sampling the target via GDB to inspect peripheral register banks (`x/8wx 0x40012400` for ADC1) and FreeRTOS kernel data structures (`p pxReadyTasksLists`).

### 2. Epistemological Boundaries of Measurement
The curriculum explicitly teaches learners what physical measurements **prove** and what they **do not prove**:

| Measurement | What It Proves | What It Does NOT Prove |
|---|---|---|
| **GPIO pulse width around ISR** | Proves the execution duration of that specific ISR execution on that specific run with the current compiler optimization level. | Does **not** prove Worst-Case Execution Time (WCET); does not account for branch variations, bus contention, or cache misses. |
| **$\Delta t$ from ISR pin to Task pin** | Bounds the observed ISR-to-Task handoff latency under the tested schedule. | Does **not** guarantee bounded latency across all possible schedules or under burst interrupt loading from other peripherals. |
| **Stack High-Water Mark (`0xA5`)** | Proves the maximum stack depth reached up to the moment of sampling. | Does **not** prove the stack will never overflow under worst-case nested interrupt preemption or rare code paths. |
| **GDB register dump at breakpoint** | Proves CPU register and memory state at that exact clock cycle while halted. | Does **not** prove runtime timing correctness; halting with GDB alters real-time peripheral states and timer overflows. |

---

# Part 9 — Seeded Fault Pool & Postmortem Protocol

Every serious debugging exercise in Phase 2 utilizes a controlled, deterministic seeded fault. Learners must follow the mandatory 8-step postmortem protocol:

$$\text{Symptom} \longrightarrow \text{Description} \longrightarrow \text{3–5 Hypotheses} \longrightarrow \text{Evidence} \longrightarrow \text{Narrow Scope} \longrightarrow \text{Root Cause} \longrightarrow \text{Fix} \longrightarrow \text{Regression}$$

### Seeded Fault Pool:

```mermaid
graph TD
    subgraph Startup & Bring-up
        F_BOOT1[F-BOOT-01: Vector Table Misalignment / Missing Thumb Bit]
        F_BOOT2[F-BOOT-02: Linker Script LMA/VMA Boundary Mismatch]
        F_BOOT3[F-BOOT-03: RCC Clock Gate Omission on Target Peripheral]
    end

    subgraph Interrupt & NVIC
        F_IRQ1[F-IRQ-01: Unacknowledged Peripheral Interrupt Flag / Storm]
        F_IRQ2[F-IRQ-02: NVIC Priority Grouping Mismatch with FreeRTOS]
        F_IRQ3[F-IRQ-03: ISR Priority Numerically Higher Than Syscall Limit]
    end

    subgraph DMA & Peripheral
        F_DMA1[F-DMA-01: DMA Buffer Allocated on Local Stack / Lifetime Bug]
        F_DMA2[F-DMA-02: Data Size Mismatch: 16-bit ADC to 8-bit RAM]
        F_DMA3[F-DMA-03: Stalled Trigger Path: Missing ADC DMA Request Enable]
    end

    subgraph RTOS & Concurrency
        F_RTOS1[F-RTOS-01: Unbounded Priority Inversion via Binary Semaphore]
        F_RTOS2[F-RTOS-02: Task Stack Overflow Corrupting Neighboring TCB]
        F_RTOS3[F-RTOS-03: Calling Blocking API Inside Interrupt Handler]
    end
```

1. **Startup & Bring-up Family:**
   - `F-BOOT-01`: Vector table entry has bit 0 cleared (even address); triggers immediate `UsageFault` (INVSTATE) upon reset.
   - `F-BOOT-02`: Linker script calculates `.data` copy length using incorrect symbol subtraction; initialized globals retain stale Flash contents or zero.
   - `F-BOOT-03`: Peripheral register write has no effect because peripheral clock in `RCC->APB2ENR` was not enabled prior to configuration.
2. **Interrupt & NVIC Family:**
   - `F-IRQ-01`: Timer interrupt handler omits clearing `TIMx->SR = ~TIM_SR_UIF`; CPU executes infinite ISR loops, starving Thread mode.
   - `F-IRQ-02`: NVIC priority grouping configured as subpriority (`PRIGROUP != 3`); causes preemptive interrupt masking failure in FreeRTOS critical sections.
   - `F-IRQ-03`: Peripheral ISR calling FreeRTOS API is assigned priority 2 (numerically higher priority than `configMAX_SYSCALL` = 5); triggers hard memory corruption during list manipulation.
3. **DMA & Peripheral Family:**
   - `F-DMA-01`: DMA buffer declared as local variable in setup function; stack frame reuse causes random data corruption as DMA continues writing.
   - `F-DMA-02`: `DMA_CCR_MSIZE` configured as 8-bit while `ADC_CR2` is 16-bit; samples are truncated and phase-shifted by 1 byte.
   - `F-DMA-03`: Timer runs and ADC converts, but `ADC_CR2_DMA` bit is not asserted; DMA transfer counter (`CNDTR`) remains static.
4. **RTOS & Concurrency Family:**
   - `F-RTOS-01`: Shared telemetry resource protected by binary semaphore; medium-priority compute task starves high-priority telemetry task indefinitely.
   - `F-RTOS-02`: Local buffer allocation in task exceeds `configMINIMAL_STACK_SIZE`; stack pointer crosses into adjacent TCB, causing crash during context switch.
   - `F-RTOS-03`: ISR calls `xQueueSend()` instead of `xQueueSendFromISR()`; kernel attempts to block on interrupt stack, corrupting MSP.

---

# Part 10 — Phase 2 Integration Project: STM32 FreeRTOS Acquisition Node

The canonical capstone project is the **STM32 FreeRTOS Acquisition Node** (`P2-M07`). It integrates all bare-metal and RTOS mechanisms into a cohesive, evidence-backed embedded subsystem.

```mermaid
graph TD
    subgraph Hardware Layer
        TIMER[TIM2 TRGO @ 1 kHz] -->|Hardware Trigger| ADC[ADC1 Regular Channel PA0]
        ADC -->|DMA Request| DMA[DMA1 Channel 1 Circular Buffer]
    end

    subgraph Interrupt Context
        DMA -->|Half-Transfer / Transfer-Complete IRQ| ISR[DMA1_Channel1_IRQHandler]
        ISR -->|xQueueSendFromISR| ACQ_Q[xAcqQueue: Ping-Pong Buffer Tokens]
        ISR -->|portYIELD_FROM_ISR| SCHED[FreeRTOS Scheduler]
    end

    subgraph Task Context
        ACQ_Q -->|xQueueReceive| TASK_PROC[Processing Task: Priority 3]
        TASK_PROC -->|Batch Statistics: min/max/avg/rms| LOG_Q[xLogQueue: Telemetry Records]
        LOG_Q -->|xQueueReceive| TASK_COMM[Communication Task: Priority 2]
        TASK_COMM -->|Protected by Mutex| USART[USART1 DMA / Interrupt Telemetry @ 115200]
        
        TASK_HEALTH[Health & Watchdog Task: Priority 1] -->|Inspect Watermark| WATERMARK[uxTaskGetStackHighWaterMark]
        TASK_HEALTH -->|Kick| IWDG[Independent Watchdog Timer]
    end
```

### 1. Data Flow & Ownership Architecture
1. **Acquisition Stage:** TIM2 update event generates TRGO pulses at 1.0 kHz. ADC1 converts analog input PA0. DMA1 Channel 1 autonomously streams 16-bit samples into a persistent 128-sample circular buffer (`uint16_t g_adc_pool[2][64]`).
2. **ISR Handoff Stage:** 
   - When Half 0 is filled (64 samples), DMA fires Half-Transfer interrupt. ISR packages `{ buffer_index = 0, count = 64, timestamp = xTaskGetTickCountFromISR() }` into an acquisition message and posts to `xAcqQueue`.
   - When Half 1 is filled, Transfer-Complete interrupt posts `{ buffer_index = 1, ... }`.
   - ISR calls `portYIELD_FROM_ISR()`.
3. **Processing Stage (`Task_Process`, Priority 3):** Blocks on `xAcqQueue`. Upon wakeup, computes batch statistics (minimum, maximum, average, RMS). Formats a fixed-size `TelemetryRecord_t`. Posts record to `xLogQueue`.
4. **Communication Stage (`Task_Comm`, Priority 2):** Blocks on `xLogQueue`. Formats ASCII or binary telemetry frame and transmits via USART1. Access to communication resource is guarded by `xTelemetryMutex`.
5. **Health Stage (`Task_Health`, Priority 1):** Runs every 500 ms. Audits stack watermarks of all tasks. Verifies that acquisition packet counter is incrementing. Refreshes the Independent Watchdog (`IWDG`). If any task deadlocks or starves, IWDG resets the MCU within 1000 ms.

### 2. Concrete Resource & Memory Budget
- **Target Platform:** STM32F103C8T6 (64 KB Flash, 20 KB SRAM).
- **Flash Allocation:**
  - Startup, Vector Table, CMSIS: ~1.5 KB
  - FreeRTOS Kernel (`tasks`, `queue`, `list`, `port`, `heap_4`): ~8.0 KB
  - Application Drivers & Logic: ~4.5 KB
  - Total Flash: ~14.0 KB ($< 22\%$ of 64 KB Flash).
- **SRAM Allocation:**
  - Static variables & DMA buffer (`2 * 64 * 2 = 256` bytes): ~1.0 KB
  - FreeRTOS Heap (`configTOTAL_HEAP_SIZE`): **9.0 KB**
    - `Task_Process` stack (256 words): 1024 bytes + TCB (84 bytes) $\approx$ 1108 bytes
    - `Task_Comm` stack (256 words): 1024 bytes + TCB (84 bytes) $\approx$ 1108 bytes
    - `Task_Health` stack (128 words): 512 bytes + TCB (84 bytes) $\approx$ 596 bytes
    - Timer / Idle task stacks: ~1200 bytes
    - Queues (`xAcqQueue` [4 items], `xLogQueue` [4 items], Mutex): ~500 bytes
  - MSP Main/Interrupt Stack: **1.5 KB**
  - Unused / Safety Headroom: **8.5 KB** ($> 42\%$ headroom).

### 3. Measurable Acceptance Criteria
1. **Throughput & Continuity:** Continuous 1 kHz sampling for 30 minutes without a single dropped buffer token or sequence gap.
2. **ISR Latency:** Measured $\Delta t$ from DMA HT/TC pin high to `Task_Process` pin high is $\le 15~\mu\text{s}$ at 72 MHz.
3. **Stack Safety:** Minimum stack high-water mark across all tasks $\ge 32$ words under full load.
4. **Priority Inversion Resilience:** An injected lower-priority synthetic compute load contending for `xTelemetryMutex` does not delay `Task_Process` execution.
5. **Fault Recovery:** Simulating a task lockup causes IWDG reset; system recovers to clean acquisition state within 1200 ms.

---

# Part 11 — Phase 2 Gate Specification

The Phase 2 Gate is a comprehensive, **AI-Free**, transfer-oriented assessment designed to verify operational mastery before advancing to Embedded Linux.

```text
+--------------------------------------------------------------------------------+
|                         PHASE 2 FINAL GATE SPECIFICATION                       |
+--------------------------------------------------------------------------------+
| Duration:    3.5 Hours                                                         |
| Policy:      AI-Free (Strict). Official Manuals, Datasheets & Source Allowed.  |
| Passing:     Overall >= 75%; Part Floors: Part A/B/C >= 60%, Part D >= 70%.   |
+--------------------------------------------------------------------------------+
                                       |
    +----------------------------------+----------------------------------+
    |                                  |                                  |
    v                                  v                                  v
[Part A: Bare-Metal Boot]       [Part B: Peripheral DMA]       [Part C: FreeRTOS Core]
  - Linker script inspection      - GDB peripheral dump          - PendSV stack walkthrough
  - Vector table alignment        - TIM-ADC-DMA diagnosis        - TCB list traversal
  - .data/.bss memory audit       - Fix stalled trigger          - NVIC priority audit
  - Weight: 25% (Floor: 60%)      - Weight: 25% (Floor: 60%)     - Weight: 25% (Floor: 60%)
                                       |
                                       +----------------------------------+
                                                                          |
                                                                          v
                                                               [Part D: HW/SW Debugging]
                                                                 - Seeded live system bug
                                                                 - Formulate 3-5 hypotheses
                                                                 - Oscilloscope & GDB evidence
                                                                 - Fix priority/stack fault
                                                                 - Weight: 25% (Floor: 70%)
```

### Structure & Scoring:
- **Part A — Bare-Metal Startup & Linker Reasoning (25% / Floor 60%):**
  - Given a custom linker script and assembly startup file containing two subtle defects (e.g. misaligned vector section and incorrect `.bss` loop termination), calculate physical LMA/VMA addresses, identify why the CPU fails to boot, correct the code, and prove clean transition to `main()`.
- **Part B — Peripheral Register & DMA Data-Path Diagnosis (25% / Floor 60%):**
  - Given an active GDB session attached to an MCU with a stalled acquisition pipeline, inspect RCC, TIM, ADC, and DMA register maps. Calculate actual sampling frequency, identify the missing trigger link, fix the configuration bits, and achieve continuous circular DMA acquisition.
- **Part C — FreeRTOS Scheduling & Context Switch Mechanics (25% / Floor 60%):**
  - Given a GDB breakpoint halted at `xPortPendSVHandler`, inspect the CPU registers and memory. Reconstruct the stacked `{r0-r3, r12, lr, pc, xpsr}` and `{r4-r11}` frames on PSP. Inspect `pxCurrentTCB` and traversal of `pxReadyTasksLists`. Audit an assigned NVIC interrupt priority against `configMAX_SYSCALL_INTERRUPT_PRIORITY`.
- **Part D — Concurrency, Priority Inversion & HW/SW Debugging (25% / Floor 70%):**
  - The learner is provided with an integrated firmware build exhibiting erratic timing, dropped packets, and occasional watchdog resets. Using GPIO markers, logic analyzer captures, and GDB, the learner must formulate hypotheses, collect evidence, identify an unbounded priority inversion hazard combined with a marginal stack watermark, implement the fix, and document regression evidence.

### Hard Disqualification Conditions:
- Guess-and-check modification of code without hypothesis-driven justification.
- Any unresolved HardFault or memory corruption.
- Inability to explain register values stacked on PSP during context switch.

### Isolation & Calibration:
- Reference solutions, rubrics, and fault injection fixtures reside strictly in `gates/phase-2-gate/reviewer/`.
- Learner workspace receives only the unassisted problem fixtures and clear acceptance criteria.
- Gate is calibrated during the first learner trial; threshold adjustments require Leader sign-off.

---

# Part 12 — Tooling & Build Strategy

Phase 2 enforces a transparent, standard, Make-first build workflow.

### 1. Toolchain Baseline
- **Cross-Compiler:** GNU Arm Embedded Toolchain (`arm-none-eabi-gcc`, `arm-none-eabi-objdump`, `arm-none-eabi-size`, `arm-none-eabi-gdb`) version 12.x or 13.x.
- **Compiler Flags:**
  ```makefile
  CFLAGS = -mcpu=cortex-m3 -mthumb -O2 -g3 -Wall -Wextra -Werror \
           -ffunction-sections -fdata-sections -nostdlib \
           -DSTM32F103xB
  LDFLAGS = -mcpu=cortex-m3 -mthumb -T link.ld -Wl,--gc-sections \
            -Wl,-Map=$(BUILD_DIR)/output.map --specs=nano.specs
  ```
- **Rationale for Excluding CMake:** Makefiles make every include directory, compiler flag, and linker script invocation 100% visible. CMake abstracts the very compilation and linking steps learners are trying to master.

### 2. Debugging Infrastructure
- **OpenOCD (Open On-Chip Debugger):**
  ```bash
  openocd -f interface/stlink.cfg -f target/stm32f1x.cfg
  ```
- **GDB Client:**
  ```bash
  arm-none-eabi-gdb firmware.elf -ex "target extended-remote :3333" -ex "load" -ex "monitor reset halt"
  ```
- GDB scripts provide convenient shortcuts for inspecting FreeRTOS task lists and peripheral registers.

### 3. STM32CubeMX Isolation Policy
- STM32CubeMX may be consulted **only** as an offline reference tool to verify clock tree multiplication factors or pin multiplexing conflicts.
- **Strict Rule:** Auto-generated HAL code (`stm32f1xx_hal.c`, `main.c` generated with CubeMX comments) is **strictly prohibited** in mandatory coursework. All peripheral interactions must use direct CMSIS register access to preserve transparency.

---

# Part 13 — Hardware Platform & Verification Integrity

### 1. Hardware Suitability Evaluation (STM32F103C8T6)
- **Cortex-M3 Core:** 72 MHz, hardware divider, 3-stage pipeline, NVIC with 16 priority levels, dual stack pointers (MSP/PSP), PendSV, SysTick. Ideal pedagogical vehicle for RTOS fundamentals.
- **Memory:** 64 KB Flash, 20 KB SRAM. Fully sufficient for the ~14 KB Flash and ~11 KB SRAM footprint of the acquisition node project.
- **Peripherals:** Advanced and General-Purpose Timers with TRGO, 12-bit ADC (1 MSPS), 7-channel DMA1, USART1/2, IWDG, atomic GPIO BSRR/BRR.
- **Verdict:** The STM32F103C8T6 completely satisfies all curriculum learning objectives. **No additional microcontroller purchase is required or authorized.**

### 2. Verification Hierarchy
The curriculum distinguishes five distinct levels of verification integrity:
1. **Host Build Verification:** Code compiles cleanly with `-Wall -Wextra -Werror`.
2. **Target Compile/Link Verification:** Image links cleanly against `link.ld`; memory layout verified via `arm-none-eabi-size` and `.map` file.
3. **Target Run Verification:** Image flashes to STM32F103C8T6 via OpenOCD; CPU boots and executes `main()`.
4. **Debugger/Register Verification:** GDB halts target via SWD; live registers, memory addresses, and TCB states match expected values.
5. **Physical Scope/Logic Evidence:** External pins probed with oscilloscope or logic analyzer; physical waveforms confirm timing, jitter, and frequency.

---

# Part 14 — AI Policy Progression

Phase 2 enforces a strict, progressive AI policy designed to transition the learner from guided exploration to complete independent mastery:

| Curriculum Stage | Permitted AI Mode | Authorized Usage Scope | Prohibited Actions |
|---|---|---|---|
| **Early Labs (P2-M01 to P2-M03)** | **AI-Hint / AI-Assisted** | Explaining cryptic linker syntax; navigating peripheral register tables in RM0008; GDB command help. | Copy-pasting boilerplate drivers; asking AI to generate complete startup or DMA code. |
| **RTOS Labs (P2-M04 to P2-M06)** | **AI-Hint** | Explaining FreeRTOS internal macros; clarifying list manipulation logic in `tasks.c`. | Asking AI to analyze GDB crash dumps or identify priority inversion bugs before learner forms hypotheses. |
| **Module Challenges** | **AI-Hint** | Socratic questions only. Learner must formulate 3 hypotheses before prompting. | Requesting direct code solutions or bug diagnoses. |
| **Module Gates** | **AI-Free** | **None.** Full offline independence. Official manuals and upstream source allowed. | Any interaction with AI tools or external forums. |
| **Acquisition Node Project** | **AI-Assisted** (Post-pass only) | Code review, refactoring advice, and English documentation polish after verification. | Generating project architecture or debugging concurrency faults. |
| **Phase 2 Final Gate** | **AI-Free (Strict)** | **None.** Complete offline evaluation under exam conditions. | Any AI usage results in immediate exam failure. |

---

# Part 15 — Source Ledger

All materials in Phase 2 derive strictly from authoritative Tier 0 and Tier 1 specifications:

| ID | Title / Source | Organization | Type | Version / Date | Exact Path / Section | Pedagogical Utility |
|---|---|---|---|---|---|---|
| **S-01** | STM32F10xxx Reference Manual (RM0008) | STMicroelectronics | Primary Vendor Manual | DocID 13902 Rev 21 (Feb 2021) | Sections 3, 6, 9, 10, 11, 13, 14, 24 | Register definitions for RCC, GPIO, NVIC, ADC, DMA, TIM, IWDG. |
| **S-02** | STM32F10xxx Cortex-M3 Programming Manual (PM0056) | STMicroelectronics | Primary Vendor Manual | DocID 15491 Rev 6 (May 2020) | Sections 2.1, 2.2, 4.3, 4.4 | Cortex-M3 core registers, NVIC interface, SysTick, SCB, ICSR. |
| **S-03** | STM32F103x8/xB Datasheet (DS5319) | STMicroelectronics | Primary Datasheet | DocID 13587 Rev 18 (Mar 2021) | Section 2, Section 5.3 | Pinout multiplexing, electrical limits, ADC sampling specs. |
| **S-04** | Armv7-M Architecture Reference Manual | Arm Limited | Primary Architecture Spec | ARM DDI 0403E.e (Issue E.e) | Sections B1.4, B1.5, B3.2, B3.4 | Exception model, stack frame layout, instruction execution states. |
| **S-05** | Cortex-M3 Devices Generic User Guide | Arm Limited | Primary User Guide | ARM DUI 0552A (2010) | Chapter 2 (Processor), Chapter 4 (Cortex-M3 Peripherals) | NVIC priority grouping, EXC_RETURN definitions, CONTROL register. |
| **S-06** | FreeRTOS-Kernel Upstream Source | FreeRTOS / AWS | Upstream Source Code | Release V11.3.0 (`9b777ae`) | `tasks.c`, `queue.c`, `list.c`, `portable/GCC/ARM_CM3/` | Reference implementation of preemptive scheduler, queues, mutexes. |
| **S-07** | CMSIS Core (Cortex-M) | Arm Limited / CMSIS | Upstream Source Code | CMSIS_5 v5.9.0 (Apache-2.0) | `CMSIS/Core/Include/core_cm3.h` | Hardware register structs and NVIC inline helper functions. |
| **S-08** | STM32F1xx CMSIS Device Headers | STMicroelectronics | Upstream Source Code | `cmsis_device_f1` v4.3.4 (Apache-2.0) | `Include/stm32f103xb.h`, `Source/Templates/gcc/` | Peripheral base addresses, bit definitions, reference startup file. |
| **S-09** | Mastering the FreeRTOS Real Time Kernel | Richard Barry / FreeRTOS | Official Guide | 2020 Edition | Chapters 3, 4, 7, 8 | Task management, queue mechanisms, interrupt priorities. |

*All URLs, revisions, and upstream commit hashes re-verified as of 2026-09-03.*

---

# Part 16 — Career Mapping & Linux Driver Transfer Bridge

Phase 2 establishes concrete evidence for firmware internships and builds the architectural bridge to Embedded Linux:

```text
Cortex-M Exception Model ----------> Armv7-A / Armv8-A Exception Levels (EL0/EL1)
Direct Register MMIO --------------> Linux readl() / writel() & ioremap()
Timer TRGO / DMA Data Path --------> Linux Industrial I/O (IIO) & DMA Engine API
FreeRTOS ISR Handoff --------------> Linux Hard-IRQ to Threaded IRQ / Workqueue
FreeRTOS Mutex & Inheritance -------> Linux kernel rt_mutex & futex
Stack High-Water Mark -------------> Linux Kernel Stack Bounds & KASAN
GPIO Oscilloscope Instrumentation --> Hardware bring-up, logic analyzer bus tracing
```

### Internship & Interview Evidence Portfolio:
1. **Bare-Metal Boot Fluency:** Ability to explain every line of a linker script and startup file on a whiteboard; explaining how `.data` and `.bss` are initialized without runtime libraries.
2. **Interrupt & Concurrency Rigor:** Articulating why RMW operations fail on shared registers; demonstrating how `BASEPRI` masking implements microsecond-bounded zero-jitter critical sections.
3. **Autonomous Data Movement:** Demonstrating a working ADC+DMA circular double-buffered acquisition node running at 1 kHz with live oscilloscope timing evidence.
4. **Real-Time Determinism:** Explaining priority inversion, reproducing it on real hardware with a logic analyzer, and demonstrating priority inheritance resolution in FreeRTOS source code.

---

# Part 17 — Implementation Issue Decomposition Plan

To maintain coherent PR sizes and facilitate rigorous code review, implementation of Phase 2 is decomposed into five downstream GitHub issues:

```mermaid
graph TD
    P2_DESIGN[PR: Phase 2 Curriculum Design - Issue #14] --> ISSUE_1[Issue 1: P2-M01 & P2-M02 Bare-Metal Foundations]
    P2_DESIGN --> ISSUE_2[Issue 2: P2-M03 & P2-M04 DMA & FreeRTOS Core]
    P2_DESIGN --> ISSUE_3[Issue 3: P2-M05 & P2-M06 Synchronization & Faults]
    P2_DESIGN --> ISSUE_4[Issue 4: P2-M07 Acquisition Node Integration]
    P2_DESIGN --> ISSUE_5[Issue 5: P2-GATE Final Gate Design & Fixtures]

    ISSUE_1 --> ISSUE_2
    ISSUE_2 --> ISSUE_3
    ISSUE_3 --> ISSUE_4
    ISSUE_4 --> ISSUE_5
```

### Proposed Issue Breakdown:
1. **Issue 1 (`tutorial/p2-m01-m02`): Bare-Metal Foundations (Startup, Linker, MMIO, Clock, NVIC)**
   - Implement `P2-M01` (custom linker script, assembly startup, vector table, memory copy loops).
   - Implement `P2-M02` (72 MHz clock tree, 1 kHz timer interrupt, GPIO atomic BSRR/BRR, RMW fault lab).
   - Estimated Load: 8.0 h MUST.
2. **Issue 2 (`tutorial/p2-m03-m04`): Peripheral DMA & FreeRTOS Core Scheduler**
   - Implement `P2-M03` (Timer-triggered ADC1 + DMA1 circular ping-pong buffer with HT/TC interrupts).
   - Implement `P2-M04` (FreeRTOS kernel Make integration, `tasks.c` walkthrough, PendSV context switch frame verification in GDB).
   - Estimated Load: 9.5 h MUST.
3. **Issue 3 (`tutorial/p2-m05-m06`): Synchronization, Priority Inversion & RTOS Faults**
   - Implement `P2-M05` (Queue pipeline, ISR-to-task handoff, NVIC vs `configMAX_SYSCALL` priority audit).
   - Implement `P2-M06` (Unbounded priority inversion reproduction, priority inheritance fix, stack watermark & overflow hook).
   - Estimated Load: 8.5 h MUST.
4. **Issue 4 (`project/p2-m07-acquisition-node`): Integrated Acquisition Node Project**
   - Implement `P2-M07` full system (TIM-ADC-DMA $\to$ `Task_Process` $\to$ `Task_Comm` $\to$ `Task_Health` + IWDG).
   - Full automated testbench, Makefile, and physical GPIO timing evidence documentation.
   - Estimated Load: 5.0 h MUST.
5. **Issue 5 (`gate/phase-2-final-gate`): Phase 2 Final Gate Assessment Package**
   - Implement `P2-GATE` test fixtures, learner workspace export script, reviewer answer keys, and grading rubric.
   - Estimated Load: 3.5 h MUST.
