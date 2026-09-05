# P2-M04: FreeRTOS V11.3.0 Kernel Core, Task Lifecycle, and Context Switching

> Module ID: **P2-M04**  
> Target Silicon: **STM32F103C8T6** (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM)  
> Upstream Kernel: **FreeRTOS V11.3.0** (Commit `9b777ae5c5b8e9e456065a00294d1e5f5f9facf5`)  
> Planned Load: **5.0 h MUST** (Coursework cumulative: **9.5 h MUST** with P2-M03)  
> Target Mastery: **L2–L3** RTOS kernel internals, **L4-local** context switch & stack frame debugging  
> Pedagogical Baseline: **Bare-metal CMSIS / Pure FreeRTOS upstream / Zero CubeMX / Zero CMSIS-RTOS wrappers**

---

## 1. Pedagogical Mission

In bare-metal superloops, software is trapped in sequential execution where long-running operations inevitably delay time-critical actions. A Real-Time Operating System (RTOS) solves this by decoupling concurrent concerns into independent threads of execution called **Tasks**, arbitrated by a deterministic, priority-preemptive **Scheduler**.

In this module, you integrate the upstream **FreeRTOS V11.3.0** kernel directly into a bare-metal Arm Cortex-M3 runtime from first principles:
```text
CMSIS Bare-Metal Startup (startup_stm32f103c8.s)
  │
  ├──► Vector 11 (SVCall)   ──► vPortSVCHandler (Launch first task from MSP -> PSP)
  ├──► Vector 14 (PendSV)   ──► xPortPendSVHandler (Tail-chained atomic context switch)
  └──► Vector 15 (SysTick)  ──► xPortSysTickHandler (Dynamic 1 kHz timebase: SystemCoreClock)
```

You will disassemble the PendSV assembly handler instruction-by-instruction, examine synthetic task stack initialization, analyze why bit 24 of `xPSR` (the Thumb bit) must be set, and audit SRAM memory budgets under `heap_4.c` first-fit block coalescing.

---

## 2. Core Mental Models

### 2.1 The Dual Stack Pointer Architecture (MSP vs PSP)
The Arm Cortex-M3 processor features two physical stack pointers:
- **MSP (Main Stack Pointer)**: Used after reset and by Handler mode. In the standard FreeRTOS ARM_CM3 port, exception handler code executes on MSP.
- **PSP (Process Stack Pointer)**: Used by FreeRTOS tasks in Thread mode after scheduler startup.

If an exception is taken while a task is running in Thread mode on PSP, hardware stacks the 8-word exception frame (`R0-R3, R12, LR, PC, xPSR`) onto that task's PSP. Handler mode then executes using MSP. The FreeRTOS PendSV path additionally saves/restores `R4-R11` on the task's PSP.

### 2.2 The PendSV Tail-Chaining Context Switch
Context switches must never execute at high interrupt priority, as doing so would block hardware interrupts and introduce unbounded jitter.
FreeRTOS solves this using **PendSV**:
1. When a task delays, yields, or is preempted, the kernel sets `SCB->ICSR |= SCB_ICSR_PENDSVSET_Msk`.
2. PendSV is programmed to the **lowest possible interrupt priority** (`0xF0`).
3. The Cortex-M NVIC defers executing PendSV until all higher-priority ISRs have completed.
4. When the last ISR returns, the NVIC immediately **tail-chains** into `PendSV_Handler` without intermediate unstacking:
   - Saves `R4-R11` to the outgoing task's PSP.
   - Saves `PSP` to `pxCurrentTCB->pxTopOfStack`.
   - Saves `&pxCurrentTCB` and handler exception LR (`EXC_RETURN`) onto MSP (`stmdb sp!, {r3, r14}`).
   - Calls `vTaskSwitchContext()` under `BASEPRI = 0x50` protection.
   - Restores `&pxCurrentTCB` and handler `EXC_RETURN` from MSP (`ldmia sp!, {r3, r14}`).
   - Restores `PSP` from incoming `pxCurrentTCB->pxTopOfStack`.
   - Restores `R4-R11` from incoming task's PSP.
   - Executes `bx lr` (`0xFFFFFFFD`), triggering hardware unstacking into the new task.

### 2.3 Dynamic Core Clock Coherence
The SysTick 24-bit downcounter reloads from `SysTick->LOAD`:
$$\text{LOAD} = \left( \frac{\text{configCPU\_CLOCK\_HZ}}{\text{configTICK\_RATE\_HZ}} \right) - 1$$
If `configCPU_CLOCK_HZ` is statically hardcoded to 72 MHz and an external crystal fails (forcing fallback to 64 MHz HSI), the tick rate dilates by 12.5%, corrupting real-time delays.
In this module, `configCPU_CLOCK_HZ` dynamically tracks `SystemCoreClock`, guaranteeing an exact 1000 Hz tick across all clock transitions.

### 2.4 SRAM Memory Budgeting & `heap_4` Exclusivity
The STM32F103C8 provides exactly 20 KB of SRAM (`0x20000000` to `0x20005000`):
- Course binary statically provisions **10 KB (`configTOTAL_HEAP_SIZE`)** for `heap_4.c`.
- `heap_4` implements 8-byte alignment, first-fit searching, and adjacent block coalescing on `vPortFree()`, eliminating heap fragmentation.
- Standard C library `malloc()` is strictly prohibited due to non-reentrancy, unbounded worst-case latency, flash bloat, and heap-stack collision risks.

---

## 3. Module Structure

```text
fundamentals/rtos/01-freertos-scheduler-context-switch/
├── Makefile                          # Cross-compilation targets (all, clean, asm, size)
├── SOURCE_LEDGER.md                  # Detailed provenance and pinning for FreeRTOS V11.3.0
├── README.md                         # This architecture and curriculum document
├── include/
│   ├── FreeRTOSConfig.h              # Pure FreeRTOS kernel configuration
│   ├── clock.h                       # Clock tree contract header
│   ├── gpio.h                        # GPIO diagnostic pin configuration header
│   └── system_stm32f1xx.h            # SystemCoreClock export
├── src/
│   ├── main.c                        # Dual-task demonstration firmware
│   ├── clock.c                       # 72 MHz HSE / 64 MHz HSI clock tree implementation
│   ├── gpio.c                        # PA1, PA2, PC13 diagnostic output drivers
│   ├── runtime_glue.c                # Newlib C hooks and FreeRTOS assert/malloc hooks
│   ├── startup_stm32f103c8.s         # Vector table with FreeRTOS exception bindings
│   └── system_stm32f1xx.c            # SystemCoreClock variable definition
├── linker/
│   └── stm32f103c8tx_flash.ld        # Linker script (64 KB Flash, 20 KB RAM)
├── scripts/
│   └── verify_m04.sh                 # Automated static, memory, and disassembly test harness
├── labs/
│   ├── 01-freertos-kernel-integration/README.md  # 60 min: Exception vectors & priority setup
│   ├── 02-clock-systick-coherence/README.md      # 60 min: SysTick math & clock fallback
│   ├── 03-task-scheduling-preemption/README.md   # 60 min: Stack initialization & Thumb bit
│   ├── 04-pendsv-context-switch/README.md        # 60 min: Assembly context switch & tail-chain
│   └── 05-heap4-sram-budget/README.md            # 60 min: heap_4 coalescing & SRAM budgeting
├── faults/
│   ├── f1/                           # Missing exception vector remapping
│   ├── f2/                           # Static clock mismatch under HSI fallback
│   ├── f3/                           # Undersized task stack allocation
│   ├── f4/                           # Missing Thumb bit in xPSR (UsageFault INVSTATE)
│   └── f5/                           # Heap exhaustion during kernel task creation
├── challenge/
│   ├── app_tasks.h                   # Challenge interface specification
│   ├── app_tasks.c                   # Student starter implementation
│   ├── validate.sh                   # Automated challenge grading script
│   └── verify_challenge.sh           # Challenge test runner
├── reviewer/
│   ├── README.md                     # Reviewer-side isolated documentation index
│   ├── challenge-reference/          # Golden reference implementation
│   ├── mutations/                    # 8 negative mutations evaluating validate.sh
│   ├── test_m04_validator_mutations.sh # Automated mutation regression test runner
│   ├── verify_gate_regression.sh     # Module gate automated verification harness
│   ├── challenge_solution.md         # Challenge design and reference breakdown
│   ├── fault_analysis.md             # Learner fault hypothesis trees and solutions
│   ├── gate_solution.md              # Module gate root-cause diagnosis and patch
│   └── hints.md                      # Progressive Socratic hints
├── gate/
│   └── gate_fault_firmware/          # Candidate challenge: unshifted BASEPRI defect
└── diagrams/
    ├── context_switch_frame.mmd      # Cortex-M3 stack frame memory layout
    └── scheduler_state_machine.mmd   # Task lifecycle and scheduling state machine
```

---

## 4. Build and Verification Instructions

### Build Module Firmware:
```bash
make -C fundamentals/rtos/01-freertos-scheduler-context-switch clean all
```

### Run Static & Linker Verification:
```bash
bash fundamentals/rtos/01-freertos-scheduler-context-switch/scripts/verify_m04.sh
```

### Run Reviewer Test Suites:
```bash
# Verify challenge validator against 8 negative mutations:
bash fundamentals/rtos/01-freertos-scheduler-context-switch/reviewer/test_m04_validator_mutations.sh

# Verify module gate regression test:
bash fundamentals/rtos/01-freertos-scheduler-context-switch/reviewer/verify_gate_regression.sh
```

---

## 5. Physical Hardware Observation Disclosure

> **VERIFICATION DISCLOSURE**:  
> In accordance with course integrity standards, **all builds, symbol tables, stack offsets, register math, and memory limits are VERIFIED** using host cross-compilation and static binary analysis.  
> **Physical logic analyzer waveforms, cycle-accurate context switch traces, and live GDB step executions are explicitly designated UNVERIFIED** as this environment operates headlessly without physical hardware attached. No register values or oscilloscope traces have been fabricated.
