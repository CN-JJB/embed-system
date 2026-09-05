# P2-M05: FreeRTOS Queue, Mutex, and ISR-Safe Synchronization Boundaries

> Module ID: **P2-M05**  
> Target Silicon: **STM32F103C8T6** (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM)  
> Upstream Kernel: **FreeRTOS V11.3.0** (Commit `9b777ae5c5b8e9e456065a00294d1e5f5f9facf5`)  
> Planned Load: **4.5 h MUST** (Total cumulative: **14.0 h MUST** with P2-M03/M04)  
> Target Mastery: **L3** Queue and Task Synchronization, **L3** ISR-to-Task Handoff Protocol, **L4-local** NVIC/BASEPRI Fault Debugging  
> Pedagogical Baseline: **Bare-metal CMSIS / Pure FreeRTOS upstream / Zero CubeMX / Zero CMSIS-RTOS wrappers**

---

## 1. Pedagogical Mission

In embedded real-time systems, interrupt service routines (ISRs) execute asynchronously at hardware exception urgency. If an ISR attempts to perform extensive processing, compute complex mathematical algorithms, or block waiting for resources, system responsiveness collapses and deadlines are missed.

The architectural solution is the **Deferred Interrupt Processing Pipeline**:
```text
Peripheral Hardware Event (TIM2 Update @ 100 Hz)
  │
  ├──► Hardware Exception Entry (Handler Mode on MSP)
  │      └──► TIM2_IRQHandler()
  │             ├──► Acknowledge hardware interrupt flag (TIM2->SR = ~TIM_SR_UIF)
  │             ├──► Enqueue fixed payload: xQueueSendFromISR(queue, &val, &xHigherPriorityTaskWoken)
  │             ├──► Conditional Yield: portYIELD_FROM_ISR(xHigherPriorityTaskWoken) -> asserts PENDSVSET
  │             └──► Exception Exit (bx lr)
  │
  └──► Tail-Chained PendSV Context Switch (Lowest Exception Urgency)
         └──► Task_Consumer (Thread Mode on PSP, Priority 3)
                ├──► Unblocks from xQueueReceive(queue, &rx_val, portMAX_DELAY)
                └──► Executes batch data processing and sequence verification
```

In this module, you build a synthetic periodic TIM2 interrupt pipeline to master queue copy mechanics, exact higher-priority task unblocking semantics (`xTaskRemoveFromEventList`), Cortex-M3 NVIC/BASEPRI interrupt masking rules, and diagnostic kernel assertion contracts.

---

## 2. Core Mental Models

### 2.1 The Queue Memory and Ownership Model
A FreeRTOS queue is:
$$\text{Queue} = \text{Bounded Contiguous Storage} + \text{Item Copy Semantics (\texttt{memcpy})} + \text{Sender Wait List} + \text{Receiver Wait List} + \text{Kernel Critical Section}$$

- **Copy Semantics**: When passing small payloads (e.g. `uint32_t sequence_number`), the kernel copies the data byte-for-byte into the queue ring buffer. The sender retains no ownership or lifetime requirements over the source variable.
- **Pointer Semantics**: When enqueuing pointers to large buffers, only the pointer address is copied. The queue does **not** transfer or manage memory lifetime. Lifetime and buffer access concurrency must be managed by the application protocol.
- **No Automatic Ownership**: A queue is a FIFO communication pipe, not a mutex. It does not track ownership and does not provide priority inheritance.

### 2.2 Exact Unblocking Semantics & `xHigherPriorityTaskWoken`
In FreeRTOS V11.3.0, when `xQueueGenericSendFromISR()` posts an item to a queue on which a task is blocked waiting, it invokes `xTaskRemoveFromEventList()`:

1. **Scheduler Running Normally (`uxSchedulerSuspended == 0`)**:
   The unblocked task is removed from `xTasksWaitingToReceive` and placed directly into its corresponding priority bucket in `pxReadyTasksLists[uxPriority]`.
2. **Scheduler Suspended (`uxSchedulerSuspended != 0`)**:
   The unblocked task is placed into **`xPendingReadyList`**, deferring ready list insertion until the scheduler is resumed by `xTaskResumeAll()`.
3. **Strict Priority Wake Comparison**:
   In single-core V11.3.0, `xTaskRemoveFromEventList()` sets preemption requirement (`xReturn = pdTRUE`) **only if**:
   $$\text{unblocked\_task\_priority} > \text{current\_task\_priority}$$
   It does **not** unblock for equal priority ($\ge$ is incorrect).
4. **Deferred Context Switch (`portYIELD_FROM_ISR`)**:
   `portYIELD_FROM_ISR(xHigherPriorityTaskWoken)` writes bit 28 (`PENDSVSET`) to the Interrupt Control and State Register (`SCB->ICSR`).
   It **does not switch tasks immediately inside the ISR**. Context switching occurs only after exception exit, when all higher-urgency interrupts have completed and the Cortex-M processor tail-chains into `PendSV_Handler`.

### 2.3 Cortex-M3 NVIC Priority vs BASEPRI Syscall Boundary
STM32F103 implements 4 bits of interrupt priority (`__NVIC_PRIO_BITS = 4`):
- **CMSIS Logical Priority**: $0$ (highest urgency) to $15$ (lowest urgency), set via `NVIC_SetPriority(IRQn, logical)`.
- **Hardware Encoded Priority Byte**: $\text{encoded} = \text{logical} \ll 4$.
- **Course Configuration**:
  ```c
  #define configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY 5
  #define configMAX_SYSCALL_INTERRUPT_PRIORITY         (5 << 4) /* 0x50 */
  ```
- **Priority Partitioning**:
  - **Logical Priorities 5 to 15 (Encoded `0x50` to `0xF0`)**: Within the kernel syscall boundary. These ISRs can safely invoke FreeRTOS `...FromISR()` APIs. When the kernel enters a critical section, it writes `0x50` to `BASEPRI`, masking these interrupts.
  - **Logical Priorities 0 to 4 (Encoded `0x00` to `0x40`)**: Higher urgency than `configMAX_SYSCALL_INTERRUPT_PRIORITY`. They are **not masked by the FreeRTOS BASEPRI critical-section threshold** and therefore must not call FreeRTOS APIs. This does not imply zero interrupt latency or zero jitter from all other architectural/software causes.
- **Priority Grouping Contract**:
  `NVIC_SetPriorityGrouping(0)` must be established so that all 4 implemented bits act as preemption priority bits. The kernel assertion `vPortValidateInterruptPriority()` in `portable/GCC/ARM_CM3/port.c` explicitly checks both the current interrupt priority byte against `ucMaxSysCallPriority` and the AIRCR priority group setting.

### 2.4 Task API vs `FromISR` API Boundary
- **Task APIs (`xQueueSend`, `xQueueReceive`)**:
  Execute in Thread mode, can block, and specify a timeout (`xTicksToWait`). They enter critical sections using `portENTER_CRITICAL()`, which asserts that execution is not in Handler mode:
  ```c
  configASSERT((portNVIC_INT_CTRL_REG & portVECTACTIVE_MASK) == 0);
  ```
  Calling a task-context API from Handler mode is unsupported. On exercised paths where `vPortEnterCritical()` observes the first task-context critical nesting level, the pinned port's `VECTACTIVE` assertion can catch the misuse. Do **not** rely on one universal assertion site or deterministic failure mode; without a caught assertion, the misuse can corrupt kernel state or otherwise misbehave. It does **not** guarantee a deterministic HardFault.
- **ISR APIs (`xQueueSendFromISR`, `xQueueReceiveFromISR`)**:
  Execute in Handler mode, never block (`xTicksToWait` does not exist), and communicate task wakeups via `*pxHigherPriorityTaskWoken`.

### 2.5 Binary Semaphore vs Mutex
- **Binary Semaphore**: Signaling / token primitive. Can be given by an ISR and taken by a task. Has no concept of ownership; does not implement priority inheritance.
- **Mutex**: Mutual exclusion primitive. Has an owner (`pxMutexHolder`). Can only be unlocked by the task that locked it. Implements priority inheritance to prevent priority inversion. **Must never be taken or given from an ISR.**

---

## 3. Module Structure

```text
fundamentals/rtos/02-freertos-queue-isr-boundary/
├── Makefile                          # Cross-compilation targets (all, clean, asm, size, check)
├── SOURCE_LEDGER.md                  # Pinned provenance for FreeRTOS V11.3.0 and CMSIS headers
├── README.md                         # This architecture and curriculum document
├── include/
│   ├── FreeRTOSConfig.h              # Kernel configuration with NVIC/BASEPRI priority contracts
│   ├── clock.h                       # 72 MHz HSE / 64 MHz HSI clock tree interface
│   ├── gpio.h                        # PA1 (ISR), PA2 (Task), PC13 (LED) atomic marker controls
│   ├── timer.h                       # TIM2 100 Hz periodic ISR interface
│   ├── queue_app.h                   # Queue length (10), item size (4 B), and task declarations
│   └── system_stm32f1xx.h            # SystemCoreClock export
├── src/
│   ├── main.c                        # Firmware entry: peripheral bring-up and scheduler launch
│   ├── clock.c                       # Dynamic clock configuration implementation
│   ├── gpio.c                        # GPIO pin setup and atomic register operations
│   ├── timer.c                       # TIM2 configuration and TIM2_IRQHandler with FromISR queue send
│   ├── queue_app.c                   # Queue creation and Task_Consumer sequence verification
│   ├── runtime_glue.c                # FreeRTOS assertion, malloc, and stack overflow hooks
│   ├── startup_stm32f103c8.s         # Vector table with FreeRTOS exception handler bindings
│   └── system_stm32f1xx.c            # Dynamic SystemCoreClock tracking variable
├── linker/
│   └── stm32f103c8tx_flash.ld        # Linker script (64 KB Flash, 20 KB SRAM)
├── scripts/
│   └── verify_m05.sh                 # Automated static, symbol, and disassembly test harness
├── diagrams/
│   ├── queue_memory_model.mmd        # Ring buffer storage and wait list layout
│   ├── isr_handoff_sequence.mmd      # TIM2 ISR -> Queue -> PendSV -> Consumer task timing
│   └── nvic_syscall_boundary.mmd     # 16-level priority map vs BASEPRI mask threshold
├── labs/
│   ├── 01-queue-memory-model/README.md          # 45 min: Copy-by-value vs pointer ownership
│   ├── 02-synthetic-isr-handoff/README.md       # 45 min: TIM2 ISR enqueuing and task receive
│   ├── 03-higher-priority-wake-yield/README.md  # 45 min: xTaskRemoveFromEventList & portYIELD_FROM_ISR
│   ├── 04-nvic-basepri-boundary/README.md       # 45 min: Logical vs encoded priorities & PRIGROUP
│   ├── 05-task-api-in-isr/README.md             # 45 min: vPortValidateInterruptPriority assertions
│   └── 06-queue-full-drop-handling/README.md    # 45 min: Buffer overflow handling & bounded drop counters
├── faults/
│   ├── README.md                     # Neutral learner fault catalog
│   ├── f1/                           # Invalid ISR priority (logical 2 calling FromISR)
│   ├── f2/                           # Priority grouping misconfiguration (PRIGROUP != 0)
│   ├── f3/                           # Task API (xQueueSend) invoked from interrupt context
│   ├── f4/                           # Missing portYIELD_FROM_ISR after queue send
│   └── f5/                           # Unhandled queue full / item size mismatch
├── challenge/
│   ├── README.md                     # Learner-facing AI-Free challenge specification
│   ├── starter/                      # Learner starter integration bundle with TODOs
│   │   ├── queue_app.c               # Application skeleton
│   │   ├── queue_app.h               # Queue interface header
│   │   └── FreeRTOSConfig.h          # Learner-owned FreeRTOS configuration with TODOs
│   ├── validate.sh                   # Automated challenge bundle grading script
│   └── verify_challenge.sh           # Learner convenience test runner
├── reviewer/
│   ├── README.md                     # Reviewer-side isolated documentation index
│   ├── challenge-reference/          # Golden reference implementation bundle
│   ├── mutations/                    # 12 negative mutation bundles evaluating validate.sh
│   ├── test_m05_validator_mutations.sh # Automated mutation regression test runner
│   ├── verify_gate_regression.sh     # Module gate automated verification harness
│   ├── challenge_solution.md         # Challenge design and reference breakdown
│   ├── fault_analysis.md             # Learner fault hypothesis trees and solutions
│   ├── gate_solution.md              # Module gate root-cause diagnosis and patch
│   └── hints.md                      # Progressive Socratic hints
└── gate/
    └── gate_fault_firmware/          # Unfamiliar synchronization Gate: Priority & polling defect
```

---

## 4. Build and Verification Instructions

### Build Module Firmware:
```bash
make -C fundamentals/rtos/02-freertos-queue-isr-boundary clean all
```

### Run Static & Contract Verification:
```bash
bash fundamentals/rtos/02-freertos-queue-isr-boundary/scripts/verify_m05.sh
```

### Run Reviewer Test Suites:
```bash
# Verify challenge validator against 12 negative mutations:
bash fundamentals/rtos/02-freertos-queue-isr-boundary/reviewer/test_m05_validator_mutations.sh

# Verify module gate regression test:
bash fundamentals/rtos/02-freertos-queue-isr-boundary/reviewer/verify_gate_regression.sh
```

---

## 5. Physical Hardware Observation Disclosure

> **VERIFICATION DISCLOSURE**:  
> In accordance with course integrity standards, **all builds, symbol tables, stack offsets, register math, and memory limits are VERIFIED** using host cross-compilation and static binary analysis.  
> **Physical logic analyzer waveforms, microsecond ISR-to-task handover latencies, and live GDB step executions are explicitly designated UNVERIFIED** as this environment operates headlessly without physical hardware attached. No register values or oscilloscope traces have been fabricated.
