# Phase 2 Implementation Notes: P2-M05 & P2-M06

> Module Pair: **P2-M05** (Queue, Mutex & ISR Boundaries) + **P2-M06** (Priority Inversion, Stack Watermark & Watchdog)  
> Repository: `CN-JJB/embed-system`  
> Branch: `tutorial/p2-m05-m06`  
> Date: 2026-09-05  
> Status: Fully Implemented & Regressed

---

## 1. Upstream Provenance & Pinning

All code and architecture across P2-M05 and P2-M06 derive from authoritative primary sources:

- **FreeRTOS Kernel**: Official upstream tag `V11.3.0`, commit `9b777ae5c5b8e9e456065a00294d1e5f5f9facf5`.
- **CMSIS Core / Device**: ARM CMSIS_5 `5.9.0` (`2b7495b`) and ST `cmsis_device_f1` `v4.3.5` (`8a76309`).
- **Hardware Reference**: STMicroelectronics Reference Manual RM0008 (DocID 13902 Rev 21) and Cortex-M3 Programming Manual PM0056 (DocID 15491 Rev 7).
- **Toolchain**: Arm GNU Toolchain 13.3.rel1 / Ubuntu `arm-none-eabi-gcc 13.2.1`. Zero proprietary HAL, CubeMX, or CMSIS-RTOS wrappers.

---

## 2. Module P2-M05 Architecture & Verification

- **Module Path**: `fundamentals/rtos/02-freertos-queue-isr-boundary/`
- **MUST Load Budget**: 4.5 h MUST
- **Core Real-Time Contracts**:
  1. **Queue Memory Model**: Contiguous FIFO circular buffer allocated in FreeRTOS `heap_4`. Items transferred strictly by copy-by-value (`memcpy`), ensuring zero pointer lifetime hazards between ISR and task contexts.
  2. **Deferred Interrupt Pipeline**: TIM2 100 Hz hardware timer ISR enqueues 32-bit packets using `xQueueSendFromISR()`, tracking `pxHigherPriorityTaskWoken`. When unblocking the higher-priority Consumer task (Priority 3 vs interrupted task Priority 1), `portYIELD_FROM_ISR()` sets `SCB->ICSR` bit 28 (`PENDSVSET`), deferring context switch to Handler exit.
  3. **Strict `>` Unblocking Semantics**: FreeRTOS V11.3.0 `tasks.c` (`xTaskRemoveFromEventList`) unblocks tasks to ready lists and returns `pdTRUE` if and only if `pxUnblockedTCB->uxPriority > pxCurrentTCB->uxPriority`. Equal priorities do not trigger preemption.
  4. **NVIC-BASEPRI Syscall Boundary**:
     - STM32F103 implements 4 priority bits (`__NVIC_PRIO_BITS = 4`).
     - Priority grouping is strictly locked to 0 (`NVIC_SetPriorityGrouping(0)`), allocating all 4 bits to preemption priority (0 to 15) and 0 bits to subpriority.
     - `configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY` is set to 5. Shifted into the upper 4 bits of the 8-bit register byte, this yields `0x50` (`configMAX_SYSCALL_INTERRUPT_PRIORITY`).
     - Any ISR invoking FreeRTOS APIs must be configured with logical priority $\ge 5$ (numerical priority $\ge 5$, urgency $\le$ syscall threshold). TIM2 is assigned priority 6 (`0x60`).
- **Curriculum Artifacts**:
  - `labs/01` to `06`: Guided labs covering queue memory, ISR handoffs, preemption yielding, BASEPRI boundaries, task API hazards in ISR, and queue-full drop accounting.
  - `faults/f1` to `f5`: Reproducible defect fixtures with symptom-first documentation and Makefiles.
  - `challenge/`: Starter bundle, automated validator (`validate.sh`), and runner (`verify_challenge.sh`).
  - `reviewer/`: Reference solution, 12 negative mutations, mutation test runner (`test_m05_validator_mutations.sh`), and gate regression test harness (`verify_gate_regression.sh`).
  - `gate/gate_fault_firmware/`: Isolated qualification defect firmware.

---

## 3. Module P2-M06 Architecture & Verification

- **Module Path**: `fundamentals/rtos/03-freertos-priority-inversion-stack-watchdog/`
- **MUST Load Budget**: 4.0 h MUST
- **Core Real-Time Contracts**:
  1. **Deterministic Priority Inversion**: 3-task model (High 3, Medium 2, Low 1) with task notification sequencing. Low executes a deterministic CPU integer workload (~5 ms) with strictly zero `vTaskDelay()`. Medium executes ~20 ms CPU workload.
     - **Run A (Binary Semaphore)**: Binary semaphore (`xSemaphoreCreateBinary()`) lacks ownership tracking. High blocks on Low, Medium preempts Low, delaying High by ~25 ms (bounded priority inversion).
     - **Run B (Mutex with Priority Inheritance)**: Mutex (`xSemaphoreCreateMutex()`) activates `xTaskPriorityInherit()`. Low is temporarily boosted to Priority 3. Medium (Priority 2) cannot preempt Low. High unblocks promptly with only ~5 ms delay.
  2. **Stack Watermark Unit Conversion**: FreeRTOS fills stacks with `0xA5` and scans upward in `uxTaskGetStackHighWaterMark()`. The function returns headroom in **words** (`StackType_t`), which is strictly multiplied by 4 (`sizeof(StackType_t)`) to obtain physical bytes remaining on 32-bit Cortex-M3.
  3. **Stack Overflow Canary Verification**: `configCHECK_FOR_STACK_OVERFLOW = 2` (Method 2) verifies both SP limits and the integrity of the 16-byte `0xA5` canary buffer at the stack base upon every context switch, trapping corrupted tasks via `vApplicationStackOverflowHook()`.
  4. **Direct-Register IWDG Subsystem**:
     - Driven by internal LSI ($f_{\text{LSI}} \approx 30\text{--}60\text{ kHz}$).
     - Direct MMIO writes to `IWDG->KR` (`0x5555` unlock, `0xCCCC` start, `0xAAAA` reload).
     - Bounded status register wait loops on `PVU` and `RVU` status bits preventing system hang on clock stall.
     - Reset cause detection and clear via `RCC->CSR` (`IWDGRSTF` and `RMVF`).
- **Curriculum Artifacts**:
  - `labs/01` to `07`: Structured labs covering Mutex vs Binary Semaphore, Priority Inversion reproduction, `tasks.c` inheritance tracing, stack watermark sizing, stack overflow hooks, IWDG register configuration, and multi-task watchdog topologies.
  - `faults/f1` to `f5`: Reproducible defect fixtures with symptom-first documentation and Makefiles.
  - `challenge/`: Starter bundle, automated validator (`validate.sh`), and runner (`verify_challenge.sh`).
  - `reviewer/`: Reference solution, 12 negative mutations, mutation test runner (`test_m06_validator_mutations.sh`), and gate regression test harness (`verify_gate_regression.sh`).
  - `gate/gate_fault_firmware/`: Isolated qualification defect firmware.

---

## 4. Time Budget Accounting

| Module ID | Module Title | Roadmap MUST | Implemented MUST | Status |
|---|---|---:|---:|---|
| **P2-M05** | Queue, Mutex, and ISR-Safe Synchronization Boundaries | 4.5 h | 4.5 h | COMPLETE |
| **P2-M06** | Priority Inversion, Inheritance, Stack Watermark & Debugging | 4.0 h | 4.0 h | COMPLETE |
| **Total** | **Phase 2 Week 3 Modules** | **8.5 h** | **8.5 h** | **EXACT MATCH** |

No content from P2-M07 (Acquisition Node integration) or Phase 2 Final Gate was implemented, strictly respecting the module boundary constraints.

---

## 5. Verification Summary

| Check / Test Suite | Scope | Result | Notes |
|---|---|---|---|
| `make -C 02-freertos-queue-isr-boundary check` | P2-M05 Static Checks | **PASS** | Footprint, symbols, Basepri priority 5, no HAL |
| `02-.../challenge/validate.sh` | P2-M05 Reference & Starter | **PASS** | Positive accepted, starter with TODOs rejected |
| `02-.../reviewer/test_m05_validator_mutations.sh` | P2-M05 12 Negative Mutations | **PASS** | 12/12 rejected, 0 false acceptances |
| `02-.../reviewer/verify_gate_regression.sh` | P2-M05 Gate Defect Image | **PASS** | Defects verified, patch applied, regressed cleanly |
| `make -C 03-freertos-priority-inversion-stack-watchdog check` | P2-M06 Static Checks | **PASS** | Footprint, symbols, mutexes, IWDG MMIO, no HAL |
| `03-.../challenge/validate.sh` | P2-M06 Reference & Starter | **PASS** | Positive accepted, starter with TODOs rejected |
| `03-.../reviewer/test_m06_validator_mutations.sh` | P2-M06 12 Negative Mutations | **PASS** | 12/12 rejected, 0 false acceptances |
| `03-.../reviewer/verify_gate_regression.sh` | P2-M06 Gate Defect Image | **PASS** | Defects verified, patch applied, regressed cleanly |
| `make -C fundamentals/rtos check` | Aggregate M04 + M05 + M06 | **PASS** | Full suite clean pass |
| Physical Scope & Live IWDG Reset Evidence | Hardware Measurements | **DESIGN TARGET / UNVERIFIED** | Explicitly declared per honest evidence policy |
