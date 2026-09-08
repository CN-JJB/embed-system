# Phase 2 Final Gate: Master Solution & Diagnostic Walkthrough

> **CONFIDENTIAL: REVIEWER REFERENCE MATERIALS — DO NOT DISTRIBUTE TO LEARNERS**  
> Under repository governance rules, this document is strictly isolated from learner-facing materials.

---

## Part A: Bare-Metal Startup & Linker Reasoning

```text
symptom
-> plausible hypotheses
-> discriminative evidence
-> root cause
-> minimal fix
-> regression
-> non-proof limits
```

### 1. Symptom
Firmware compiles and links cleanly with `-nostartfiles -Wl,--gc-sections` and zero warnings. However, upon booting, the core never enters the main operational loop; instead, it enters an infinite fault loop inside `main()` because initialized configuration data in `.data` fails validation against its compile-time initializers (`g_boot_config_token != 0x5A5AA5A5U`, halting with `g_boot_status == 0xDEADBEEFU`).

### 2. Plausible Hypotheses
1. `.data` copy loop in `Reset_Handler` has an off-by-one boundary condition or loop termination defect.
2. Linker script assigns the relocation source pointer `_sidata = ADDR(.data);` pointing to the SRAM VMA (`0x20000000`) instead of the Flash LMA (`LOADADDR(.data)`), causing the startup copy loop to self-copy uninitialized SRAM rather than copying initialized data from Flash.
3. Linker script positions `_edata = .;` before `*(.data*)`, collapsing the copy range to 0 bytes (`_edata == _sdata`).
4. `.bss` zeroing loop executes after `.data` copy loop and accidentally clears `.data`.

### 3. Discriminative Evidence
Inspect section and symbol table headers in the compiled ELF:
```bash
arm-none-eabi-readelf -l build/firmware.elf
arm-none-eabi-nm build/firmware.elf | grep -E '_si|_sd|_ed|_et'
```
Observations:
```text
Program Headers:
  Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
  LOAD           0x010000 0x08000000 0x08000000 0x00234 0x00234 R E 0x4
  LOAD           0x020000 0x20000000 0x08000234 0x00004 0x00004 RW  0x4
```
Symbol table inspection:
```text
0800020c A _etext
20000000 A _sidata
20000000 D _sdata
20000004 D _edata
```
Discriminative Finding:
- `.data` LMA (Load Memory Address / PhysAddr) is at `0x08000234`, strictly in Flash.
- Symbol `_sidata` is set to `ADDR(.data)` (`0x20000000`), which is the Virtual Memory Address (VMA) in SRAM.
- In `startup_stm32f103c8.s`, the startup copy loop evaluates:
  ```assembly
  ldr r0, =_sdata
  ldr r1, =_edata
  ldr r2, =_sidata
  ```
- Because `r2 (_sidata)` points to `0x20000000` (equal to `_sdata`), the copy loop reads uninitialized SRAM from `0x20000000` and writes it back into `0x20000000`.
- The actual initial value of `g_boot_config_token` (located in Flash at `LOADADDR(.data)`) is never loaded into SRAM. Instead, `g_boot_config_token` retains uninitialized SRAM garbage, failing the verification in `main()`.

### 4. Root Cause
In `linker/stm32f103c8tx_flash.ld`, `_sidata` was defined as:
```ld
_sidata = ADDR(.data);
```
Because `ADDR(.data)` returns the runtime VMA in RAM (`0x20000000`), `_sidata` does not point to the load address in Flash (`LOADADDR(.data)`).

### 5. Minimal Fix
In `linker/stm32f103c8tx_flash.ld`, define `_sidata` using the builtin function `LOADADDR(.data)`:
```ld
_sidata = LOADADDR(.data);
```

### 6. Regression
Run `make clean && make check`:
Reviewer oracle verifies that symbol `_sidata` equals `LOADADDR(.data)`.
Runtime initialized variables in `.data` match their compile-time initializers, and `main()` proceeds to operational execution.

### 7. Non-Proof Limits
Proving `_sidata == LOADADDR(.data)` statically confirms the linker script exports correct section load addresses. It does **not** prove that hardware Flash wait-states were configured correctly or that SRAM retention was verified across reset cycles.

---

## Part B: Peripheral Register & DMA Data-Path Diagnosis

```text
symptom
-> plausible hypotheses
-> discriminative evidence
-> root cause
-> minimal fix
-> regression
-> non-proof limits
```

### 1. Symptom
The autonomous acquisition pipeline initializes and triggers via TIM3 TRGO. DMA transfers the initial 128-sample double buffer, advancing `g_dma_ht_count` to 1 and `g_dma_tc_count` to 1. However, all subsequent streaming halts permanently: `g_dma_ht_count` and `g_dma_tc_count` remain stuck at 1, `DMA1_Channel1->CNDTR` reads 0, and no further samples are acquired.

### 2. Plausible Hypotheses
1. Circular mode was omitted (`DMA_CCR_CIRC = 0`), causing the DMA channel to disable upon CNDTR decrementing to 0.
2. ADC1 calibration failed or input multiplexer was disconnected.
3. TIM3 TRGO master mode was misconfigured.
4. Memory increment was omitted (`DMA_CCR_MINC = 0`).

### 3. Discriminative Evidence
Inspect `fixtures/register_dump.txt`:
```text
DMA1_Channel1->CCR   = 0x0000058F
DMA1_Channel1->CNDTR = 0x00000000
DMA1->ISR            = 0x00000002
```
And `fixtures/buffer_dump.txt`:
```text
0x20000200 <g_adc_buffer>:      0x073a  0x0742  0x073f  0x0745 ...
g_dma_ht_count = 1
g_dma_tc_count = 1
```
Decoding `DMA1_Channel1->CCR = 0x0000058F` against ST RM0008 Section 10.4.3:
- Bit 0: `EN = 1`
- Bit 1: `TCIE = 1`
- Bit 2: `HTIE = 1`
- Bit 3: `TEIE = 1`
- Bit 4: `DIR = 0` (Peripheral to memory)
- Bit 5: `CIRC = 0` (Circular mode DISABLED!)
- Bit 7: `MINC = 1` (Memory increment ENABLED)
- Bit 8: `PSIZE = 01` (16-bit peripheral data size)
- Bit 10: `MSIZE = 01` (16-bit memory data size)

Discriminative Finding:
- Bit 7 (`MINC`) is 1: memory increment is active; all 128 slots in `g_adc_buffer` receive valid ADC samples on the first pass.
- Bit 5 (`CIRC`) is 0: circular reloading is disabled.
- When `CNDTR` decrements to 0, transfer complete interrupt fires (`g_dma_tc_count = 1`), and the channel halts automatically. Without `CIRC = 1`, `CNDTR` is not reloaded from the initial count register, and DMA transfers cease permanently.

### 4. Root Cause
In `src/dma.c`, `DMA1_Channel1->CCR` configuration omitted `DMA_CCR_CIRC`.

### 5. Minimal Fix
In `src/dma.c`, add `DMA_CCR_CIRC` to `DMA1_Channel1->CCR`:
```c
    DMA1_Channel1->CCR = DMA_CCR_CIRC |
                         DMA_CCR_MINC |
                         DMA_CCR_PSIZE_0 |
                         DMA_CCR_MSIZE_0 |
                         DMA_CCR_HTIE |
                         DMA_CCR_TCIE |
                         DMA_CCR_TEIE;
```

### 6. Regression
`reviewer/regression_oracle.py` verifies `DMA1_Channel1->CCR` has `DMA_CCR_CIRC` enabled (`CCR = 0x5AE` / 1454).
Continuous buffer streaming and periodic HT/TC reloading resume.

### 7. Non-Proof Limits
Confirming `CIRC=1` in `CCR` proves the DMA controller is configured to reload transfer counts cyclically. It does **not** prove analog signal integrity, absence of DMA bus contention, or jitter-free sampling timing on physical silicon.

---

## Part C: FreeRTOS Scheduling & Context Switch Mechanics

```text
symptom
-> plausible hypotheses
-> discriminative evidence
-> root cause
-> minimal fix
-> regression
-> non-proof limits
```

### 1. Symptom
During execution under real-time event traffic, the system halts inside an unrecoverable FreeRTOS kernel assertion trap inside `vPortValidateInterruptPriority()` when external interrupt `EXTI0_IRQHandler` fires and calls `xQueueSendFromISR()`.

### 2. Plausible Hypotheses
1. FreeRTOS priority grouping in `SCB->AIRCR` was configured with subpriorities rather than group priority 0 (all preemption bits).
2. `EXTI0_IRQHandler` called a non-ISR FreeRTOS API (`xQueueSend` instead of `xQueueSendFromISR`).
3. Developer configured EXTI0 with logical priority 4, which maps to hardware priority byte `0x40`, exceeding the urgency limit set by `configMAX_SYSCALL_INTERRUPT_PRIORITY` (`0x50`), violating the FreeRTOS critical section boundary.

### 3. Discriminative Evidence
Inspect `fixtures/pendsv_gdb_trace.txt`:
```text
(gdb) x/1bx (0xE000E400 + 6)
0xe000e406:	0x40
```
- Hardware priority register for EXTI0 (`NVIC->IP[6]`) contains `0x40`.
- In Cortex-M3 (4-bit implemented priority), priority byte `0x40` corresponds to logical priority 4 (`0x40 >> 4 = 4`).
- In `FreeRTOSConfig.h`:
  `configMAX_SYSCALL_INTERRUPT_PRIORITY` is `0x50` (CMSIS logical priority 5).
- In Cortex-M, numerically lower priority values indicate higher preemption urgency.
- Because `0x40 < 0x50`, EXTI0 has **higher urgency** than the FreeRTOS syscall boundary (`BASEPRI = 0x50`).
- When FreeRTOS enters a critical section, it writes `0x50` into `BASEPRI`.
- Because `0x40 < 0x50`, EXTI0 is **not masked** by `BASEPRI`.
- When `EXTI0_IRQHandler` executes during a critical section and invokes `xQueueSendFromISR()`, it concurrently mutates kernel list structures, corrupting the scheduler. FreeRTOS guards against this using `configASSERT` in `vPortValidateInterruptPriority()`.

Context Switch Derivation from `pendsv_gdb_trace.txt`:
- Active mode at breakpoint: Handler mode (running `xPortPendSVHandler`). Active stack pointer: `MSP = 0x20004ff8`.
- Preempted task: `Task_Worker`, ran in Thread mode with `PSP = 0x20001210`.
- Hardware exception frame (8 words, 32 bytes from `0x20001210` to `0x2000122F`):
  * `r0  = 0x00000001` at `0x20001210`
  * `r1  = 0x00000002` at `0x20001214`
  * `r2  = 0x00000003` at `0x20001218`
  * `r3  = 0x00000004` at `0x2000121C`
  * `r12 = 0x12121212` at `0x20001220`
  * `lr  = 0x08000851` at `0x20001224`
  * `pc  = 0x080007d4` at `0x20001228`
  * `xpsr= 0x21000000` at `0x2000122C` (Thumb bit 24 set)
- Software save in `xPortPendSVHandler`:
  `mrs r0, psp; stmdb r0!, {r4-r11};`
  Pushes 8 words (`32` bytes = `0x20`).
  New `pxCurrentTCB->pxTopOfStack = 0x20001210 - 0x20 = 0x200011F0`.
- `lr = 0xFFFFFFFD`: EXC_RETURN indicating return to Thread mode using PSP.

### 4. Root Cause
In `src/interrupt_config.c`:
```c
    NVIC_SetPriority(EXTI0_IRQn, 4);
```
Configuring logical priority 4 sets hardware byte `0x40`. Because `0x40 < 0x50` (`configMAX_SYSCALL_INTERRUPT_PRIORITY`), EXTI0 is not masked by `BASEPRI`, violating FreeRTOS API execution safety from ISR context.

### 5. Minimal Fix
Configure logical priority $\ge 5$ (e.g. 5 or 6, producing hardware byte `0x50` or `0x60`):
```c
    NVIC_SetPriority(EXTI0_IRQn, 6);
```

### 6. Regression
`reviewer/regression_oracle.py` confirms `EXTI0_IRQn` priority byte is $\ge 0x50$ (`0x60`), safely within FreeRTOS syscall boundary.

### 7. Non-Proof Limits
A static priority check proves the interrupt priority is compatible with `BASEPRI`. It does **not** prove that queue buffers will not overflow under extreme external interrupt rates or that context switches occur within bounded time.

---

## Part D: Concurrency & HW/SW Debugging

```text
symptom
-> plausible hypotheses
-> discriminative evidence
-> root cause
-> minimal fix
-> regression
-> non-proof limits
```

### 1. Symptom
Under concurrent multi-task operation:
- The system intermittently freezes during operation, halting telemetry transmission and logging.
- Approximately 500 ms following the freeze, the MCU abruptly restarts.
- Post-reset register examination reveals `RCC->CSR` has bit 29 (`IWDGRSTF`) set, confirming hardware watchdog reset.

### 2. Plausible Hypotheses
1. `task_telemetry` stack overflowed, triggering `vApplicationStackOverflowHook()`.
2. A task entered an unbounded busy-wait loop, starving all lower-priority tasks and the watchdog refresh.
3. `task_storage` acquires `xSensorBusLock` but releases `xLogBufferLock` (wrong semaphore), leaking `xSensorBusLock` and starving `task_telemetry` and `iwdg_refresh()`.
4. The IWDG prescaler/reload values were misconfigured, causing watchdog expiration under normal execution.

### 3. Discriminative Evidence
- **Channel 1 (GDB Task State & Synchronization Queue Audit):**
  Inspect `fixtures/task_state_dump.txt`:
  * `info threads` shows both `Task_Telemetry` and `Task_Storage` in `Blocked` state inside `vListInsert ()`.
  * `Task_Telemetry` is blocked waiting on `xSensorBusLock` (`0x20000408`).
    In `xSensorBusLock`, `xMutexHolder` is `0x20000300` (`Task_Storage`)!
  * `Task_Storage` is also blocked waiting for `xSensorBusLock` on its next cycle.
  * In `task_storage`, code acquired `xSensorBusLock` but called `xSemaphoreGive(xLogBufferLock)`, leaving `xSensorBusLock` locked by `Task_Storage`.
  * `Task_Telemetry` is permanently blocked waiting for the unreleased lock.
- **Channel 2 (Hardware Reset Flag & Timing Trace):**
  Inspect `fixtures/watchdog_reset_trace.txt`:
  * `RCC->CSR = 0x24000000`: Bit 29 (`IWDGRSTF`) is set, proving reset was triggered by IWDG timeout.
  * STM32 IWDG downcounter model:
    `PR = /64` (divider 64). LSI nominal frequency = 40 kHz.
    Counter clock rate = $40000 / 64 = 625\text{ Hz}$ (1.6 ms per count).
    `RLR = 312` (downcounter counts $312 + 1 = 313$ ticks).
    Nominal timeout: $313 \times 1.6\text{ ms} = 500.8\text{ ms}$.
    LSI manufacturing variation per DS5319: 30 kHz to 60 kHz:
    - Minimum timeout (at 60 kHz): $313 \times (64 / 60000) \approx 333.9\text{ ms}$.
    - Maximum timeout (at 30 kHz): $313 \times (64 / 30000) \approx 667.7\text{ ms}$.
  * Timing trace shows:
    - t = 0.000 s: `task_telemetry` active, `iwdg_refresh()` executed.
    - t = 0.020 s: `task_storage` wakes, acquires `xSensorBusLock`, releases `xLogBufferLock` (defect).
    - t = 0.050 s: `task_telemetry` wakes, attempts to acquire `xSensorBusLock`, blocks permanently.
    - t = 0.120 s: `task_storage` wakes, attempts to acquire `xSensorBusLock`, blocks permanently.
    - t = 0.050 s .. 0.501 s: Both tasks blocked. Watchdog refresh starved.
    - t = 0.501 s (501 ms after refresh at t = 0.000 s): Hardware IWDG downcounter decrements to 0 -> hardware reset asserted.

### 4. Root Cause
In `src/node_app.c`, `task_storage` acquired `xSensorBusLock` but called `xSemaphoreGive(xLogBufferLock)` instead of `xSemaphoreGive(xSensorBusLock)`. Leaking the mutex permanently blocked `task_telemetry`, preventing it from calling `iwdg_refresh()` and causing hardware watchdog timeout.

### 5. Minimal Fix
In `src/node_app.c`, ensure `xSemaphoreGive(xSensorBusLock)` is called in `task_storage`:
```c
        if (xSemaphoreTake(xSensorBusLock, portMAX_DELAY) == pdTRUE) {
            g_storage_cycles++;
            xSemaphoreGive(xSensorBusLock);
        }
```

### 6. Regression
`reviewer/regression_oracle.py` audits AST/control-flow to ensure `task_storage` releases `xSensorBusLock`.

### 7. Non-Proof Limits
A static mutex release audit proves that locks are paired within the examined task bodies. It does **not** prove that third-party library calls cannot block or that hardware LSI clock drift cannot reduce watchdog margins under extreme temperatures.
