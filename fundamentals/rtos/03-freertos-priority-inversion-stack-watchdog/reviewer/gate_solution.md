# Reviewer Guide: P2-M06 Gate Solution & Diagnostics

## 1. Candidate Faults in Gate Defect Firmware

The qualification gate firmware exhibits three subtle faults in concurrency, memory monitoring, and watchdog recovery:

### Fault 1: Binary Semaphore Used for Mutual Exclusion on Communication Buffer
- **Location**: `gate/gate_fault_firmware/src/main.c`
- **Symptom**: `Task_Sensor` (Priority 3) experiences preemption latency (**DESIGN TARGET / UNVERIFIED**: ~25 ms / ~25 ticks) whenever `Task_Filter` (Priority 2) executes.
- **Root Cause**: `s_shared_buffer_sem = xSemaphoreCreateBinary()` creates a binary semaphore without ownership tracking or priority inheritance. When `Task_Telemetry` (Priority 1) holds the lock, `Task_Sensor` blocks, and `Task_Filter` preempts `Task_Telemetry`.
- **Fix**: Change instantiation to `s_shared_buffer_sem = xSemaphoreCreateMutex()` and remove initial give.

### Fault 2: Watermark Unit Hazard (Words vs Bytes)
- **Location**: `gate/gate_fault_firmware/src/main.c` (`prvTelemetryTask`)
- **Symptom**: Telemetry reports scenario-reported stack headroom as 48 bytes instead of the expected 192 bytes derived from the supplied word count.
- **Root Cause**: `uxTaskGetStackHighWaterMark()` returns remaining headroom in **words** (`StackType_t`). On 32-bit Cortex-M3, this must be multiplied by 4 (`sizeof(StackType_t)`).
- **Fix**: Multiply result: `g_reported_watermark_bytes = (uint32_t)(wm_words * sizeof(StackType_t));`

### Fault 3: Unbounded Status Wait and Unhandled Reset Flags in IWDG
- **Location**: `gate/gate_fault_firmware/src/iwdg.c`
- **Symptom**: Potential infinite hang during boot if LSI clock stalls, and stale reset flags in `RCC->CSR`.
- **Root Cause**: `while ((IWDG->SR & IWDG_SR_PVU) != 0)` has no timeout guard. In `iwdg_check_and_clear_reset_cause()`, `RCC->CSR |= RCC_CSR_RMVF` is missing.
- **Fix**: Add bounded loop counter with timeout return in `iwdg_init()`, and add `RCC->CSR |= RCC_CSR_RMVF` in `iwdg_check_and_clear_reset_cause()`.

---

## 2. GDB Verification Steps (Expected Diagnostic Procedure — Target Run Unverified)

> [!NOTE]
> The following GDB steps describe the expected diagnostic observation during interactive target debugging. Physical target execution was not captured during this phase and remains UNVERIFIED.

1. Attach GDB to target:
   ```gdb
   target extended-remote :3333
   break prvSensorTask
   continue
   ```
2. Break at mutex acquisition and inspect `g_sensor_wait_ticks`:
   - Expected under binary semaphore: `g_sensor_wait_ticks` is expected to be near ~25 ticks (**DESIGN TARGET / UNVERIFIED**).
   - Expected under mutex with inheritance: `g_sensor_wait_ticks` is expected to be near ~5 ticks (**DESIGN TARGET / UNVERIFIED**).
3. Print watermark value:
   ```gdb
   print g_reported_watermark_bytes
   ```
   Verify reported headroom matches word count multiplied by 4.
