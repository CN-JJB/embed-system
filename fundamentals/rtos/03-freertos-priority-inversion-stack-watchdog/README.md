# P2-M06: FreeRTOS Priority Inversion, Priority Inheritance, Stack Watermark & Watchdog

> Target: STM32F103C8T6 (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM)  
> Core Prerequisite: P2-M04 (FreeRTOS Core & Context Switch), P2-M05 (Queue & ISR Boundary)  
> Track: Real-Time Synchronization, Stack Safety & Hardware Watchdog Recovery

---

## 1. Architectural Foundations & Mental Models

In multi-task preemptive real-time systems, resource contention and memory exhaustion are the primary sources of catastrophic failure. Module P2-M06 establishes the mathematical, architectural, and register-level mechanics of synchronization hazards and safety nets under FreeRTOS V11.3.0 and the STM32F103 hardware platform.

```text
+-----------------------------------------------------------------------------------+
|                            TASK PREEMPTION TIMELINE                               |
|                                                                                   |
| Task High   (Prio 3)  ---[RUN]--[BLOCK on Mutex]..................[RUN & FINISH]  |
|                                        ^                                          |
| Task Medium (Prio 2)  ................|...[PREEMPTS LOW in Inversion]             |
|                                        |   (Blocked in Inheritance)               |
| Task Low    (Prio 1)  ---[LOCK]--[CPU WORK (Boosted to Prio 3)]--[UNLOCK]         |
+-----------------------------------------------------------------------------------+
```

### 1.1 The Priority Inversion Pathology

Priority Inversion occurs when a high-priority task is indirectly blocked by a medium-priority task that does not even require the contested shared resource.

Consider three tasks:
1. `Task_High` (Priority 3): Real-time critical response task.
2. `Task_Medium` (Priority 2): Unrelated computation task.
3. `Task_Low` (Priority 1): Background logging task accessing a shared resource `R`.

**The Priority-Inversion Sequence:**
1. `Task_Low` acquires resource `R` (using a synchronization primitive without inheritance).
2. `Task_High` unblocks and preempts `Task_Low`.
3. `Task_High` attempts to acquire `R`, finds it locked, and transitions to the `Blocked` state waiting for `R`.
4. Control returns to `Task_Low`.
5. `Task_Medium` unblocks due to an external event or timer. Because Priority 2 > Priority 1, `Task_Medium` preempts `Task_Low`.
6. `Task_Medium` executes arbitrary computation while `Task_Low` remains paused with `R` locked.
7. Consequently, `Task_High` is delayed by `Task_Medium`. In this course experiment the Medium workload is finite, so the reproduced inversion is **bounded**. In the general case, continuously runnable medium-priority work can extend the high-priority blocking without the mutex inheritance bound.

### 1.2 FreeRTOS Priority Inheritance Mechanics

FreeRTOS implements Priority Inheritance in `tasks.c` and `queue.c` when `configUSE_MUTEXES == 1`.

- **Primitive Type**: Mutexes created via `xSemaphoreCreateMutex()` are queues of type `queueQUEUE_TYPE_MUTEX`. Unlike binary semaphores (`queueQUEUE_TYPE_BINARY_SEMAPHORE`), mutexes maintain a record of ownership in `pxMutexHolder`.
- **Inheritance Trigger (`xTaskPriorityInherit`)**: When `Task_High` calls `xSemaphoreTake()` on a mutex held by `Task_Low`, the kernel executes `xTaskPriorityInherit(pxMutexHolder)`.
  - The kernel checks if `pxMutexHolder->uxPriority < pxCurrentTCB->uxPriority`.
  - If true, `pxMutexHolder->uxPriority` is temporarily boosted to match `Task_High`'s priority (`3`).
  - If `Task_Low` is currently residing in a ready list (`pxReadyTasksLists[1]`), it is moved to `pxReadyTasksLists[3]`.
- **Preemption Block**: When `Task_Medium` (Priority 2) attempts to become ready, it cannot preempt `Task_Low` because `Task_Low` is temporarily executing at Priority 3.
- **Disinheritance (`xTaskPriorityDisinherit`)**: When `Task_Low` calls `xSemaphoreGive()`, the kernel checks `pxTCB->uxBasePriority`. If the task's priority was elevated, it is restored to its original base priority (`1`), and it is repositioned in the appropriate ready list.
- **Critical Architectural Boundary**: Priority inheritance **DOES NOT PREVENT DEADLOCK**. If two tasks acquire mutexes in reverse order ($T_1: M_A \to M_B$; $T_2: M_B \to M_A$), priority inheritance cannot break the circular dependency. Mutex hierarchies or total ordering must be maintained.

### 1.3 Stack Watermark & Memory Sizing

Each FreeRTOS task operates within a private stack frame allocated from `heap_4`.

- **Initialization Pattern**: At task creation (`prvInitialiseNewTask`), FreeRTOS fills the entire allocated stack memory with the byte pattern `0xA5` (defined as `tskSTACK_FILL_BYTE`).
- **Growth Direction**: On ARM Cortex-M3, the stack grows downwards towards lower addresses (`portSTACK_GROWTH < 0`).
- **Watermark Scanning (`uxTaskGetStackHighWaterMark`)**:
  - The function starts from the lowest valid stack address (`pxTCB->pxStack`) and increments upwards word-by-word until it finds the first value that is not `0xA5A5A5A5`.
  - **CRITICAL SIZING CONTRACT**: `uxTaskGetStackHighWaterMark` returns the remaining stack headroom in **WORDS** (`UBaseType_t`), **NOT BYTES**.
  - On a 32-bit Cortex-M3 processor, remaining bytes are:
    $$\text{Bytes Remaining} = \text{uxTaskGetStackHighWaterMark}(xTask) \times 4$$
  - A return value of `32` indicates $32 \times 4 = 128$ bytes of headroom remaining, NOT 32 bytes!

### 1.4 Stack Overflow Detection Hooks

FreeRTOS provides two stack check algorithms enabled via `configCHECK_FOR_STACK_OVERFLOW`:

1. **Method 1 (`configCHECK_FOR_STACK_OVERFLOW == 1`)**:
   - Compares the task's saved stack pointer (`pxTopOfStack`) against the stack limit (`pxStack`).
   - Weakness: Only triggers if the stack pointer is actively out-of-bounds at the exact moment a context switch occurs. It fails to catch deep momentary call stacks that overflowed and returned within bounds before the tick/yield.
2. **Method 2 (`configCHECK_FOR_STACK_OVERFLOW == 2`)**:
   - In addition to Method 1, inspects the last 16 bytes of the stack (the lowest 4 words).
   - If any of these 16 bytes differ from `0xA5`, the kernel assumes the stack has overflowed and jumps to `vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName)`.
   - Limitation: Software hooks cannot prevent memory corruption while the task executes. For hardware-enforced protection, an MPU (Memory Protection Unit) is required.

### 1.5 Independent Watchdog (IWDG) Architecture

The STM32F103 IWDG is clocked from an internal low-speed RC oscillator (LSI) with nominal frequency $f_{\text{LSI}} \approx 40\text{ kHz}$ (datasheet range 30 kHz to 60 kHz).

- **Key Registers**:
  - `IWDG->KR`: Key register. Writing `0x5555` unlocks access to `PR` and `RLR`. Writing `0xCCCC` starts the watchdog timer. Writing `0xAAAA` reloads the counter from `RLR`.
  - `IWDG->PR`: Prescaler divider ($4, 8, 16, 32, 64, 128, 256$).
  - `IWDG->RLR`: 12-bit reload value ($0$ to $4095$).
  - `IWDG->SR`: Status register containing `PVU` (Prescaler Value Update) and `RVU` (Reload Value Update) flags.
- **Formula for Timeout Period**:
  $$T_{\text{IWDG}} = \frac{4 \times 2^{\text{PR\_VAL}} \times (\text{RLR} + 1)}{f_{\text{LSI}}}$$
  With Prescaler 64 (`PR = 4`) and `RLR = 624`:
  $$T_{\text{IWDG}} \approx \frac{64 \times 625}{40000\text{ Hz}} = \frac{40000}{40000} = 1.0\text{ s}$$
- **Bounded Status Polling Contract**: Modifying `PR` or `RLR` when `PVU` or `RVU` is high is ignored by hardware. Drivers must poll `SR` with a bounded software timeout. Unbounded `while(IWDG->SR & ...)` loops risk permanent deadlock if the LSI fails.
- **Reset Cause Inspection**: Upon reset, software must inspect `RCC->CSR` for the `IWDGRSTF` flag to detect watchdog-initiated resets, and clear it using `RCC->CSR |= RCC_CSR_RMVF`.
- **System Watchdog Topology**: In a multi-task system, refreshing the watchdog from an unmonitored idle task or a hardware timer ISR defeats the watchdog's purpose. Watchdog refresh must be performed exclusively by a dedicated health monitoring task that audits the progress and watermarks of all critical system threads.

---

## 2. Directory Layout

```text
fundamentals/rtos/03-freertos-priority-inversion-stack-watchdog/
├── include/
│   ├── FreeRTOSConfig.h          # Preemption, Mutexes, Stack Overflow Hook Config
│   ├── clock.h                   # 72 MHz PLL clock configuration
│   ├── gpio.h                    # Timing markers (PA1, PA2, PA3)
│   ├── inversion_app.h           # Deterministic 3-task test harness interface
│   ├── iwdg.h                    # Register-level IWDG driver and reset cause API
│   └── system_stm32f1xx.h        # CMSIS system header
├── src/
│   ├── clock.c                   # HSE / PLL initialization
│   ├── gpio.c                    # GPIO initialization & atomic BSRR/BRR toggles
│   ├── inversion_app.c           # Deterministic priority inversion & inheritance test
│   ├── iwdg.c                    # Direct register IWDG implementation
│   ├── main.c                    # Bringup, health check, stack overflow hook
│   ├── runtime_glue.c            # newlib-nano _init, _fini, _sbrk
│   ├── startup_stm32f103c8.s     # Assembly startup and vector table
│   └── system_stm32f1xx.c        # SystemInit implementation
├── diagrams/
│   ├── priority_inversion_sequence.mmd
│   ├── priority_inheritance_sequence.mmd
│   ├── stack_watermark_model.mmd
│   └── iwdg_state_machine.mmd
├── labs/                         # 7 Structured guided learning labs
├── faults/                       # 5 Reproducible defect fixtures (f1 to f5)
├── challenge/                    # Module challenge starter & validation script
├── reviewer/                     # Reference solution, 12 negative mutations, test suite
├── gate/                         # Unfamiliar defect firmware for transfer assessment
├── scripts/
│   └── verify_m06.sh             # Automated static verification script
├── Makefile                      # Cross-compilation and verification driver
├── README.md                     # This architectural document
└── SOURCE_LEDGER.md              # Provenance ledger
```

---

## 3. Verification & Evidence Disclosure

| Verification Dimension | Assessment Method | Status / Evidence |
| :--- | :--- | :--- |
| **Compilation & Toolchain** | `arm-none-eabi-gcc 13.2.1` `-Wall -Wextra -Werror` | **VERIFIED** (Zero warnings, clean link) |
| **Binary Memory Bounds** | `arm-none-eabi-size` footprint audit | **VERIFIED** (Flash: 9.1 KB / 64 KB, RAM: 11.6 KB / 20 KB) |
| **Symbol Table Audit** | `arm-none-eabi-nm` inspection | **VERIFIED** (`xTaskPriorityInherit`, `uxTaskGetStackHighWaterMark`, `vApplicationStackOverflowHook`, `iwdg_init`, `dwt_init`, `dwt_get_cycles`) |
| **Exclusivity of Heap** | Disassembly inspection | **VERIFIED** (`ucHeap` in heap_4; libc `malloc`/`free` absent) |
| **Direct Peripheral Access** | Disassembly of `iwdg.c` | **VERIFIED** (Direct MMIO to `0x40003000`, zero vendor HAL) |
| **Deterministic CPU Loop** | Disassembly of `inversion_app.c` | **VERIFIED** (Pure integer ALU loop, zero `vTaskDelay` in critical section) |
| **Physical Scope Waveforms** | 25 ms bounded inversion / ~5 ms inheritance | **DESIGN TARGET / UNVERIFIED** (Requires logic analyzer) |
| **Live Hardware Watchdog Reset** | 1.0 s IWDG hardware reset on STM32F103 | **DESIGN TARGET / UNVERIFIED** (Requires physical ST-Link) |

---

## 4. Quick Start

```bash
# Clean and build firmware
make clean
make all

# Run complete static verification suite
make check
```
