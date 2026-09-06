# P2-M07: STM32 FreeRTOS Acquisition Node Integration Project

## 1. Project Overview

The **STM32 FreeRTOS Acquisition Node** is the Phase 2 capstone integration project of the Embedded Systems Foundations curriculum. It integrates hardware-triggered peripheral acquisition, direct DMA circular double-buffering, ISR-to-task synchronization, prioritized RTOS scheduling, serial telemetry logging, health-gated watchdog recovery, and a controlled priority-inversion diagnostic into a production-grade embedded subsystem on bare-metal silicon.

### Target Specifications
- **Target Microcontroller**: STM32F103C8T6 (Arm Cortex-M3 @ 72 MHz)
- **Memory Capacity**: 64 KB Flash, 20 KB SRAM
- **Operating System**: FreeRTOS-Kernel V11.3.0 (GCC ARM_CM3 port, `heap_4`)
- **Firmware Footprint**: 12,168 bytes Flash (~18.6%), 10,888 bytes SRAM (~53.2%)
- **Driver Architecture**: Direct CMSIS register-level implementation; **zero HAL, CubeMX, or CMSIS-RTOS wrapper dependencies**.

---

## 2. System Architecture & Acquisition Fast Path

```text
TIM3 update @ 1.0 kHz
→ TIM3 TRGO
→ ADC1 regular PA0 conversion (12 MHz ADCCLK, SMP0=55.5 cycles)
→ DMA1 Channel 1 circular 2 × 64 uint16_t pool (g_adc_pool)
→ DMA HT / TC ISR (Priority 6)
→ xAcqQueue (depth 4)
→ Task_Process (Priority 3)
→ xLogQueue (depth 4)
→ Task_Comm (Priority 2)
→ USART1 direct register TX @ 115200 baud
```

### Key Architectural Invariants
1. **Zero Application Mutex in Normal Fast Path**:
   - The acquisition pipeline (DMA $\to$ `Task_Process` $\to$ `Task_Comm`) communicates exclusively through FreeRTOS queues using value-copied messages.
   - No application mutex or binary semaphore is locked during normal sample processing or logging.
2. **Ping-Pong Buffer Ownership Contract**:
   - Double buffer: `uint16_t g_adc_pool[2][64]` (128 samples total) in persistent static SRAM.
   - At 1.0 kHz sampling rate, each 64-sample half-buffer takes **64.0 ms** to fill.
   - `Task_Process` (Priority 3) completes batch statistics (min, max, average, integer RMS via `isqrt_u32`) in $< 100\ \mu\text{s}$, well before DMA completes the alternate half.
3. **ISR to Task Synchronization**:
   - `DMA1_Channel1_IRQHandler` is configured at logical priority **6** (inside the FreeRTOS syscall-safe band $\ge 5$).
   - Uses `xQueueSendFromISR(xAcqQueue, &msg, &xHigherPriorityTaskWoken)`.
   - Explicitly records queue-full backpressure drops (`g_acq_drops`).
   - Propagates unblocking yields immediately via `portYIELD_FROM_ISR()`.

---

## 3. Application Tasks & Priority Hierarchy

| Task Name | Priority | Stack Depth | Core Responsibilities |
|---|---|---|---|
| **`Task_Process`** | 3 (High) | 256 words | Blocks on `xAcqQueue`, validates half-buffer tokens, computes integer statistics (min, max, avg, RMS), and posts `TelemetryRecord_t` to `xLogQueue`. |
| **`Task_Comm`** | 2 (Medium) | 256 words | Blocks on `xLogQueue`, formats ASCII telemetry records, and transmits frames via direct `USART1->SR` / `USART1->DR` registers @ 115200 baud. |
| **`Task_Compute`** | 2 (Medium) | 256 words | Diagnostic-only task; executes finite CPU-runnable interference workload (~20 ms) when triggered. |
| **`Task_Health`** | 1 (Low) | 256 words | 500 ms periodic health monitor; audits acquisition progress, task stack watermarks, and heap integrity. Enforces health-gated IWDG refresh. |

---

## 4. Health & Watchdog Recovery Subsystem

Watchdog refreshing represents an active health decision, not a blind timer:
1. **Acquisition Progress Audit**: Confirms that `g_acq_transfers` has increased since the prior audit cycle.
2. **Stack High-Water Mark Audit**: Queries `uxTaskGetStackHighWaterMark()` for all tasks; requires $\ge 32$ words ($\ge 128$ bytes) remaining.
3. **Heap Health Audit**: Queries `xPortGetFreeHeapSize()` and `xPortGetMinimumEverFreeHeapSize()`.
4. **Conditional Refresh Gate**:
   - If **all three audits pass**, `iwdg_refresh()` is called.
   - If **any audit fails** (e.g. DMA stalls, stack nears overflow, or memory leaks), `iwdg_refresh()` is withheld.
   - The Independent Watchdog (configured for ~2000 ms timeout via prescaler /64, reload 1250) resets the microcontroller.
   - `iwdg_check_and_clear_reset_cause()` inspects `RCC_CSR_IWDGRSTF` on boot.

---

## 5. Controlled Priority-Inversion Diagnostic

To demonstrate priority inheritance without disrupting steady-state acquisition, the firmware includes an isolated benchmark:
- **High**: `Task_Process` (Priority 3)
- **Medium**: `Task_Compute` (Priority 2)
- **Low**: `Task_Health` (Priority 1)
- **Shared Resource**: `g_diag_resource`

### Run A — Binary Semaphore (No Inheritance)
1. Low acquires binary semaphore `g_diag_sem`.
2. Low releases High via direct task notification.
3. High awakens, samples DWT cycle counter, calls `xSemaphoreTake(g_diag_sem)`, and blocks.
4. Only after High has had the deterministic block opportunity does Low release Medium.
5. Medium preempts Low (Priority 2 > 1) and runs finite CPU interference (~20 ms).
6. Low resumes and completes bounded CPU critical workload (~5 ms, strictly NO `vTaskDelay`).
7. Low releases `g_diag_sem`. High unblocks and stores cycle delta in `g_diag_high_wait_cycles_run_a`.
- **Design Target / UNVERIFIED**: $\approx 25\text{ ms}$ bounded wait in the finite binary-semaphore comparison.

### Run B — Mutex (Priority Inheritance Active)
1. Low acquires mutex `g_diag_mutex`.
2. Low releases High via direct task notification.
3. High awakens, samples DWT, calls `xSemaphoreTake(g_diag_mutex)`, and blocks.
4. **Low inherits Priority 3** from High!
5. Low releases Medium. Medium awakens at Priority 2, but **cannot preempt inherited Priority 3 Low**!
6. Low executes identical critical workload promptly (~5 ms).
7. Low releases mutex, disinherits to Priority 1. High unblocks and stores cycle delta in `g_diag_high_wait_cycles_run_b`.
- **Design Target / UNVERIFIED**: $\approx 5\text{ ms}$ / $\le 6\text{ ms}$ in the mutex comparison.

---

## 6. Memory Lifecycle & Static Verification

- **Single Heap**: FreeRTOS `heap_4` (`ucHeap`, 9216 bytes).
- **Steady-State Invariant**: All application tasks, queues, semaphores, and buffers are created in `node_app_init()` before `vTaskStartScheduler()`. Zero dynamic memory allocation occurs in steady state.
- **Libc Dynamic Allocators**: `malloc`, `free`, `realloc`, and `calloc` are completely absent from the linked ELF.

---

## 7. Verification Status Boundary

In strict compliance with root `AGENTS.md`:

| Evidence Item | Status | Basis | Does Not Prove |
|---|---|---|---|
| Target compile and link | **VERIFIED** | Clean compilation with `arm-none-eabi-gcc` 13.2.1 under `-Werror` | Target physical execution |
| Memory bounds (Flash / SRAM) | **VERIFIED** | Flash = 12,168 / 65,536 B, SRAM = 10,888 / 20,480 B | Target runtime stability |
| FreeRTOS V11.3.0 pin | **VERIFIED** | Pinned upstream commit `9b777ae5` | Non-regressed third-party code |
| Peripheral register disassembly | **VERIFIED** | `objdump` direct access verification for TIM3, ADC1, DMA1, USART1, IWDG, DWT | Physical analog accuracy |
| Positive reference validation | **VERIFIED** | `scripts/verify_project.sh` passed on reference bundle | Target hardware execution |
| Negative mutation suite | **VERIFIED** | All 16 compilable defective mutations rejected by validator | Completeness of future Final Gate |
| Physical target flash and run | **UNVERIFIED** | No bench hardware attached | Live silicon operation |
| GDB register inspection | **UNVERIFIED** | Illustrative commands; no probe attached | Actual register snapshots |
| Serial telemetry stream | **UNVERIFIED** | Illustrative protocol; no UART logic capture | Measured baud rate or line noise |
| Physical oscilloscope waveforms | **UNVERIFIED** | Illustrative timing diagrams; no oscilloscope | Physical rise times or jitter |
| Physical watchdog reset timing | **UNVERIFIED** | Illustrative timing (~2000 ms); no timer capture | LSI frequency drift |

---

## 8. Build & Verification Commands

```bash
# Clean build
make -C projects/stm32-freertos-acquisition-node clean build

# Run project validator
bash projects/stm32-freertos-acquisition-node/scripts/verify_project.sh

# Run reviewer mutation suite
bash projects/stm32-freertos-acquisition-node/reviewer/verify_mutations.sh

# Run full acceptance harness
bash projects/stm32-freertos-acquisition-node/acceptance/test_acceptance.sh
```
