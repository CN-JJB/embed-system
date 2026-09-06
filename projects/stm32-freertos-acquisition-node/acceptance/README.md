# Acceptance Testing Harness: STM32 FreeRTOS Acquisition Node

This harness validates the end-to-end integration and architectural invariants of the acquisition node firmware.

## Acceptance Criteria

1. **Firmware Constraints**:
   - Target: STM32F103C8T6 (Arm Cortex-M3, 72 MHz SYSCLK).
   - Flash $\le$ 64 KB (65,536 bytes); SRAM $\le$ 20 KB (20,480 bytes).
   - Sole dynamic memory allocator: FreeRTOS `heap_4` (`ucHeap` $\le$ 9 KB).
   - Zero libc dynamic allocation (`malloc/free`).
   - Zero HAL / CubeMX / CMSIS-RTOS wrappers.

2. **Acquisition Invariants**:
   - TIM3 1.0 kHz hardware update trigger (TRGO).
   - ADC1 regular PA0 external trigger conversion with ADCPRE /6 (12 MHz ADCCLK) and 55.5 cycles sample time.
   - DMA1 Channel 1 circular 128-halfword double buffer in static SRAM (`g_adc_pool[2][64]`).
   - DMA IRQ logical priority 6 (safe for FreeRTOS syscalls $\le$ 5).
   - ISR communicates with `Task_Process` exclusively via value-copied `AcquisitionMessage_t` through `xAcqQueue` with `xQueueSendFromISR` and `portYIELD_FROM_ISR`.
   - **Zero application mutex in normal fast path**.

3. **Task Pipeline**:
   - `Task_Process` (Priority 3): blocks on `xAcqQueue`, computes integer batch statistics (min, max, avg, RMS via integer `isqrt`), produces `TelemetryRecord_t` to `xLogQueue`.
   - `Task_Comm` (Priority 2): blocks on `xLogQueue`, outputs formatted ASCII telemetry via direct USART1 registers @ 115200 baud.
   - `Task_Health` (Priority 1): 500 ms periodic health audit; guards IWDG refresh behind acquisition progress, stack watermark $\ge$ 32 words, and heap availability.

4. **Diagnostic Integrity**:
   - Deterministic controlled priority inversion benchmark comparing Run A (binary semaphore) vs Run B (mutex with priority inheritance).
   - High block opportunity precedes Medium release.
   - Low critical workload strictly CPU-runnable with no `vTaskDelay()`.
   - Cycle measurements derived strictly from Cortex-M3 DWT CYCCNT pre/post deltas with provenance enforced.

5. **Mutation Suite**:
   - Positive reference solution passes.
   - All 16 compilable negative mutations covering all defect families are rejected.

## Running the Acceptance Suite

```bash
bash acceptance/test_acceptance.sh
```
