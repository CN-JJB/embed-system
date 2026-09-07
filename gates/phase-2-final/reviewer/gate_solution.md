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
2. Linker script assigns the relocation source pointer `_sidata` incorrectly (e.g. to `_etext`), ignoring intervening sections in Flash such as `.rodata` and `.init_array`.
3. Stack initialization placed `_estack` inside `.data`, causing stack frames to overwrite global variables.
4. `.bss` zeroing loop executes after `.data` copy loop and accidentally clears `.data`.

### 3. Discriminative Evidence
Inspect section and segment headers and symbols in the compiled ELF:
```bash
arm-none-eabi-readelf -l build/firmware.elf
arm-none-eabi-nm build/firmware.elf | grep -E '_si|_sd|_ed|_et'
```
Observations:
```text
Program Headers:
  Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
  LOAD           0x001000 0x08000000 0x08000000 0x0022c 0x0022c R E 0x1000
  LOAD           0x000000 0x20000000 0x0800022c 0x00008 0x00008 RW  0x1000
```
- `.data` segment has `VirtAddr = 0x20000000` and `PhysAddr = 0x0800022C` (Flash LMA).
- Inspect symbol table:
```text
08000208 T _etext
20000000 D _sdata
08000208 A _sidata
```
Discriminative Finding:
- `_sidata = 0x08000208` (equal to `_etext`).
- However, the actual load address of `.data` is `0x0800022C`!
- The 36-byte disparity (`0x0800022C - 0x08000208 = 0x24`) represents `.rodata` (constants and build metadata) and `.init_array` residing in Flash between `_etext` and `.data`.
- Consequently, the startup copy loop copied `.rodata` bytes into `.data` in SRAM instead of initialized variable values!

### 4. Root Cause
In `linker/stm32f103c8tx_flash.ld`, the linker script defined `_sidata` as:
```ld
    _sidata = _etext;
```
Assigning `_sidata = _etext;` is an invalid shortcut that assumes `.data` immediately follows `.text` in Flash. Because `.rodata` and constructor arrays reside after `.text`, `_sidata` must be assigned using the linker builtin function `LOADADDR(.data)`:
```ld
    _sidata = LOADADDR(.data);
```

### 5. Minimal Fix
In `linker/stm32f103c8tx_flash.ld`, update the definition of `_sidata`:
```ld
    _sidata = LOADADDR(.data);
```

### 6. Regression
Run `make clean && make check`:
`python3 scripts/check_linker.py` confirms that `_sidata == LOADADDR(.data) == 0x0800022C`.
Runtime initialized variables in `.data` match their initializers, and `main()` proceeds to operational execution.

### 7. Non-Proof Limits
Proving `_sidata == LOADADDR(.data)` statically confirms the linker script exports the exact Flash load address. It does **not** prove that hardware Flash wait-states were configured correctly or that SRAM retention was verified across reset cycles.

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
The autonomous acquisition pipeline initializes and captures an initial block of 128 samples. Half-Transfer and Transfer-Complete interrupt events fire once. However, continuous streaming subsequently halts: no further samples are transferred into `g_adc_buffer`, `DMA1_Channel1->CNDTR` remains locked at zero, and interrupt counters cease advancing despite TIM3 and ADC1 continuing to run.

### 2. Plausible Hypotheses
1. ADC1 calibration failed or hung in a timeout loop.
2. TIM3 TRGO master mode was misconfigured (MMS bits reset).
3. DMA channel was configured in normal single-buffer mode (`CIRC = 0`) instead of circular mode (`CIRC = 1`), causing the DMA controller to halt permanently once `CNDTR` decremented to zero.
4. Interrupt handler failed to clear DMA interrupt flags in `DMA1->IFCR`, causing interrupt starvation.

### 3. Discriminative Evidence
Inspect `fixtures/register_dump.txt`:
```text
DMA1_Channel1->CCR   = 0x0000058F
DMA1_Channel1->CNDTR = 0x00000000
DMA1->ISR            = 0x00000002
```
Decoding `DMA1_Channel1->CCR = 0x0000058F` against ST RM0008 Section 10.4.3:
- Bit 0: `EN = 1` (Channel enabled)
- Bit 1: `TCIE = 1` (Transfer complete interrupt enabled)
- Bit 2: `HTIE = 1` (Half-transfer interrupt enabled)
- Bit 3: `TEIE = 1` (Transfer error interrupt enabled)
- Bit 4: `DIR = 0` (Peripheral to memory)
- Bit 5: `CIRC = 0` (Circular mode DISABLED!)
- Bit 7: `MINC = 1` (Memory increment enabled)
- Bit 8: `PSIZE = 01` (16-bit peripheral data size)
- Bit 10: `MSIZE = 01` (16-bit memory data size)

Discriminative Finding:
- Bit 5 (`CIRC`) is 0.
- `CNDTR = 0x00000000`.
- In normal mode (`CIRC = 0`), when `CNDTR` decrements to 0, the channel stops transferring data until software reloads `CNDTR`.
- In circular mode (`CIRC = 1`), `CNDTR` is automatically reloaded with the initial buffer size on wrap, enabling continuous ping-pong double buffering.

### 4. Root Cause
In `src/dma.c`, `DMA1_Channel1->CCR` configuration omitted the `DMA_CCR_CIRC` bitmask. Without circular mode enabled, the DMA controller executes a single 128-sample block transfer and permanently halts.

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
`make check` disassembles `dma1_channel1_init` and confirms the constant loaded for `CCR` is `0x5ae` (`#1454`), proving `DMA_CCR_CIRC` is enabled.

### 7. Non-Proof Limits
Confirming `CIRC=1` in `CCR` proves the DMA controller is configured for continuous reload. It does **not** prove analog signal integrity, absence of DMA bus contention from other masters, or jitter-free timer update timing on physical silicon.

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
3. Developer confused `configMAX_SYSCALL_INTERRUPT_PRIORITY` (`0x50`) with unshifted logical priority, passing `0x50` to CMSIS `NVIC_SetPriority()`, which shifted the value to `0x00` (highest hardware priority), violating the FreeRTOS critical section boundary.

### 3. Discriminative Evidence
Inspect `fixtures/pendsv_gdb_trace.txt`:
```text
(gdb) x/1bx (0xE000E400 + 6)
0xe000e406:	0x00
```
- Hardware priority register for EXTI0 (`NVIC->IP[6]`) contains `0x00`.
- In Cortex-M3, `0x00` is the highest possible interrupt preemption priority (Priority 0).
- In `FreeRTOSConfig.h`:
  `configMAX_SYSCALL_INTERRUPT_PRIORITY` is `0x50` (CMSIS logical priority 5).
- Because `0x00 < 0x50`, EXTI0 has higher hardware priority than the `BASEPRI` masking threshold.
- When FreeRTOS enters a critical section, it writes `0x50` into `BASEPRI`.
- Because `0x00 < 0x50`, EXTI0 is **not masked** by `BASEPRI`.
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
    NVIC_SetPriority(EXTI0_IRQn, 0x50);
```
The developer passed the 8-bit shifted priority constant `configMAX_SYSCALL_INTERRUPT_PRIORITY` (`0x50`) instead of unshifted logical priority (`5` or `6`).
CMSIS `NVIC_SetPriority` shifts the input argument:
`NVIC->IP[IRQn] = (uint8_t)((priority << 4) & 0xFF)`.
Evaluating with `0x50`: `(0x50 << 4) & 0xFF == 0x500 & 0xFF == 0x00`.
This set EXTI0 priority to `0x00`, violating the FreeRTOS syscall boundary.

### 5. Minimal Fix
Pass unshifted logical priority $\ge 5$ (e.g. 5 or 6) to `NVIC_SetPriority`:
```c
    NVIC_SetPriority(EXTI0_IRQn, 5);
```

### 6. Regression
`make check` runs `scripts/check_priority.py`, confirming `EXTI0_IRQn` priority byte is $\ge 0x50$ (`0x50` or `0x60`).

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
3. Inverted lock acquisition hierarchy between `task_telemetry` and `task_storage` creates an AB-BA circular deadlock, permanently suspending both tasks and starving `iwdg_refresh()`.
4. The IWDG prescaler/reload values were misconfigured, causing watchdog expiration under normal execution.

### 3. Discriminative Evidence
- **Channel 1 (GDB Task State & Synchronization Queue Audit):**
  Inspect `fixtures/task_state_dump.txt`:
  * `info threads` shows both `Task_Telemetry` and `Task_Storage` in `Blocked` state inside `vListInsert ()`.
  * `Task_Telemetry` is blocked waiting on `xTelemetryBufferLock`. Its queue item container is `0x20000508`.
    In `xTelemetryBufferLock`, `xMutexHolder` is `0x20000300` (`Task_Storage`)!
  * `Task_Storage` is blocked waiting on `xSensorBusLock`. Its queue item container is `0x20000408`.
    In `xSensorBusLock`, `xMutexHolder` is `0x20000240` (`Task_Telemetry`)!
  * **Deadlock Observation:** `Task_Telemetry` holds `xSensorBusLock` and waits for `xTelemetryBufferLock`. `Task_Storage` holds `xTelemetryBufferLock` and waits for `xSensorBusLock`.
  * Both tasks are permanently blocked waiting on each other (Coffman circular wait condition).
- **Channel 2 (Hardware Reset Flag & Timing Trace):**
  Inspect `fixtures/watchdog_reset_trace.txt`:
  * `RCC->CSR = 0x24000000`: Bit 29 (`IWDGRSTF`) is set, proving reset was triggered by IWDG timeout.
  * Timing trace shows:
    - t = 0.105 s: `Task_Storage` acquires `xTelemetryBufferLock`.
    - t = 0.110 s: `Task_Telemetry` activates, acquires `xSensorBusLock`, then requests `xTelemetryBufferLock` and blocks.
    - t = 0.110 s: `Task_Storage` resumes, requests `xSensorBusLock`, and blocks.
    - t = 0.110 s .. 0.611 s: Both tasks suspended. No execution on PA1/PA2.
    - t = 0.611 s (501 ms after last refresh at t = 0.100 s): Hardware IWDG counter decrements to 0 -> hardware reset asserted.

### 4. Root Cause
In `src/node_app.c`, tasks acquired shared mutexes in inconsistent order:
- `task_telemetry`: acquires `xSensorBusLock` first, then `xTelemetryBufferLock`.
- `task_storage`: acquires `xTelemetryBufferLock` first, then `xSensorBusLock`.
This inverted lock acquisition hierarchy violates total lock ordering. When `task_storage` held `xTelemetryBufferLock` and was preempted by `task_telemetry`, which held `xSensorBusLock`, a classic circular wait deadlock occurred. Neither task could advance, permanently starving `iwdg_refresh()` and causing hardware reset.

### 5. Minimal Fix
In `src/node_app.c`, enforce canonical lock acquisition order in `task_storage`:
```c
        /* Enforce canonical lock hierarchy: xSensorBusLock before xTelemetryBufferLock */
        if (xSemaphoreTake(xSensorBusLock, portMAX_DELAY) == pdTRUE) {
            if (xSemaphoreTake(xTelemetryBufferLock, portMAX_DELAY) == pdTRUE) {
                g_storage_cycles++;
                xSemaphoreGive(xTelemetryBufferLock);
            }
            xSemaphoreGive(xSensorBusLock);
        }
```

### 6. Regression
`make check` executes `scripts/check_concurrency.py`, verifying that all tasks follow canonical lock acquisition hierarchy (`xSensorBusLock` before `xTelemetryBufferLock`).

### 7. Non-Proof Limits
A static lock ordering check proves the absence of circular wait deadlock for the modeled tasks. It does **not** prove that third-party library calls cannot block or that hardware LSI clock drift (30 kHz to 60 kHz per DS5319) cannot reduce watchdog margins under extreme temperatures.
