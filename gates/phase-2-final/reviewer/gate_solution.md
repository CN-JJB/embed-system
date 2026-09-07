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
2. Linker script positions `_edata = .;` before `*(.data*)`, collapsing the copy range to 0 bytes (`_edata == _sdata`).
3. Linker script assigns the relocation source pointer `_sidata` incorrectly, ignoring intervening sections in Flash.
4. `.bss` zeroing loop executes after `.data` copy loop and accidentally clears `.data`.

### 3. Discriminative Evidence
Inspect section and symbol table headers in the compiled ELF:
```bash
arm-none-eabi-readelf -S build/firmware.elf
arm-none-eabi-nm build/firmware.elf | grep -E '_si|_sd|_ed|_et'
```
Observations:
```text
Section Headers:
  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
  [ 1] .isr_vector       PROGBITS        08000000 010000 00010c 00   A  0   0  1
  [ 2] .text             PROGBITS        0800010c 01010c 000100 00  AX  0   0  4
  [ 3] .rodata           PROGBITS        0800020c 01020c 000020 00   A  0   0  4
  [ 4] .data             PROGBITS        20000000 020000 000004 00  WA  0   0  4
```
Symbol table inspect:
```text
20000000 D _sdata
20000000 D _edata
0800022c A _sidata
```
Discriminative Finding:
- `_sdata = 0x20000000`
- `_edata = 0x20000000`
- `_edata == _sdata`! The relocation range calculated by the startup code (`&_edata - &_sdata`) has a length of exactly 0 bytes.
- In `startup_stm32f103c8.s`, the startup copy loop evaluates:
  ```assembly
  ldr r2, =_edata
  ...
  cmp r0, r2
  bcc copy_loop
  ```
- Because `r0 (_sdata) == r2 (_edata)`, the branch condition `bcc` fails on the very first iteration. The copy loop exits immediately without relocating `.data` from Flash (`_sidata = 0x0800022C`) to SRAM (`0x20000000`).
- Global initialized variables in `.data` remain uninitialized random SRAM garbage or unwritten zeroes, triggering the boot check failure.

### 4. Root Cause
In `linker/stm32f103c8tx_flash.ld`, the linker symbol `_edata = .;` was placed immediately after `_sdata = .;` and *before* `*(.data*)` rather than after the section input specifications:
```ld
  .data : 
  {
    . = ALIGN(4);
    _sdata = .;        /* create a global symbol at data start */
    _edata = .;        /* DEFECT: positioned before input sections */
    *(.data)           /* .data sections */
    *(.data*)          /* .data* sections */

    . = ALIGN(4);
  } >RAM AT> FLASH
```
Because the location counter `.` had not yet advanced past `*(.data*)`, `_edata` captured `.` at `0x20000000`, making the copy range 0 bytes.

### 5. Minimal Fix
In `linker/stm32f103c8tx_flash.ld`, move `_edata = .;` after the section input specifications and alignment:
```ld
  .data : 
  {
    . = ALIGN(4);
    _sdata = .;        /* create a global symbol at data start */
    *(.data)           /* .data sections */
    *(.data*)          /* .data* sections */

    . = ALIGN(4);
    _edata = .;        /* create a global symbol at data end */
  } >RAM AT> FLASH
```

### 6. Regression
Run `make clean && make check`:
`python3 scripts/check_linker.py` confirms that `_edata > _sdata` (`_edata = 0x20000004`, size = 4 bytes) and `_sidata == LOADADDR(.data) == 0x0800022C`.
Runtime initialized variables in `.data` match their compile-time initializers, and `main()` proceeds to operational execution.

### 7. Non-Proof Limits
Proving `_edata > _sdata` statically confirms the linker script exports non-zero section bounds. It does **not** prove that hardware Flash wait-states were configured correctly or that SRAM retention was verified across reset cycles.

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
The autonomous acquisition pipeline initializes and triggers via TIM3 TRGO. DMA interrupt counters (`g_dma_ht_count`, `g_dma_tc_count`) continuously advance (142 counts recorded), proving the DMA transfer requests fire and reload cyclically. However, inspecting the double buffer `g_adc_buffer` reveals that only the very first sample slot (`g_adc_buffer[0][0]`) is ever updated with live data (`0x073A`), while all other 127 slots (`g_adc_buffer[0][1..63]` and `g_adc_buffer[1][0..63]`) remain completely unwritten (`0x0000`).

### 2. Plausible Hypotheses
1. ADC1 calibration failed or input multiplexer was disconnected.
2. TIM3 TRGO master mode was misconfigured.
3. DMA channel CCR omitted memory increment (`DMA_CCR_MINC = 0`), causing destination pointer stagnation.
4. Circular mode was disabled (`DMA_CCR_CIRC = 0`), causing channel shutdown.

### 3. Discriminative Evidence
Inspect `fixtures/register_dump.txt`:
```text
DMA1_Channel1->CCR   = 0x0000052F
DMA1_Channel1->CNDTR = 0x0000005A
DMA1->ISR            = 0x00000002
```
And `fixtures/buffer_dump.txt`:
```text
0x20000200 <g_adc_buffer>:      0x073a  0x0000  0x0000  0x0000 ...
g_dma_ht_count = 142
g_dma_tc_count = 142
```
Decoding `DMA1_Channel1->CCR = 0x0000052F` against ST RM0008 Section 10.4.3:
- Bit 0: `EN = 1` (Channel enabled)
- Bit 1: `TCIE = 1` (Transfer complete interrupt enabled)
- Bit 2: `HTIE = 1` (Half-transfer interrupt enabled)
- Bit 3: `TEIE = 1` (Transfer error interrupt enabled)
- Bit 4: `DIR = 0` (Peripheral to memory)
- Bit 5: `CIRC = 1` (Circular mode ENABLED!)
- Bit 7: `MINC = 0` (Memory increment DISABLED!)
- Bit 8: `PSIZE = 01` (16-bit peripheral data size)
- Bit 10: `MSIZE = 01` (16-bit memory data size)

Discriminative Finding:
- Bit 5 (`CIRC`) is 1: circular reloading is functioning (confirmed by 142 HT/TC interrupt events).
- Bit 7 (`MINC`) is 0: the DMA controller does not increment `CMAR` after each transfer.
- Every single conversion transferred by DMA1 Channel 1 is written to the base address in `CMAR` (`&g_adc_buffer[0][0]`), constantly overwriting slot 0 and leaving the rest of the buffer unpopulated.

### 4. Root Cause
In `src/dma.c`, `DMA1_Channel1->CCR` configuration omitted `DMA_CCR_MINC`. Without memory address incrementation, all incoming peripheral samples are written to the identical memory destination address.

### 5. Minimal Fix
In `src/dma.c`, add `DMA_CCR_MINC` to `DMA1_Channel1->CCR`:
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
`make check` runs `scripts/check_dma.py` which verifies the compiled configuration constant matches the expected cryptographic contract hash, proving both `DMA_CCR_CIRC` and `DMA_CCR_MINC` are enabled (`CCR = 0x5AE` / 1454).

### 7. Non-Proof Limits
Confirming `MINC=1` in `CCR` proves the DMA controller is configured to increment destination pointers. It does **not** prove analog signal integrity, absence of DMA bus contention, or jitter-free sampling timing on physical silicon.

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
3. Developer configured EXTI0 with logical priority 3, which maps to hardware priority byte `0x30`, exceeding the urgency limit set by `configMAX_SYSCALL_INTERRUPT_PRIORITY` (`0x50`), violating the FreeRTOS critical section boundary.

### 3. Discriminative Evidence
Inspect `fixtures/pendsv_gdb_trace.txt`:
```text
(gdb) x/1bx (0xE000E400 + 6)
0xe000e406:	0x30
```
- Hardware priority register for EXTI0 (`NVIC->IP[6]`) contains `0x30`.
- In Cortex-M3 (4-bit implemented priority), priority byte `0x30` corresponds to logical priority 3 (`0x30 >> 4 = 3`).
- In `FreeRTOSConfig.h`:
  `configMAX_SYSCALL_INTERRUPT_PRIORITY` is `0x50` (CMSIS logical priority 5).
- In Cortex-M, numerically lower priority values indicate higher preemption urgency.
- Because `0x30 < 0x50`, EXTI0 has **higher urgency** than the FreeRTOS syscall boundary (`BASEPRI = 0x50`).
- When FreeRTOS enters a critical section, it writes `0x50` into `BASEPRI`.
- Because `0x30 < 0x50`, EXTI0 is **not masked** by `BASEPRI`.
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
    NVIC_SetPriority(EXTI0_IRQn, 3);
```
Configuring logical priority 3 sets hardware byte `0x30`. Because `0x30 < 0x50` (`configMAX_SYSCALL_INTERRUPT_PRIORITY`), EXTI0 is not masked by `BASEPRI`, violating FreeRTOS API execution safety from ISR context.

### 5. Minimal Fix
Configure logical priority $\ge 5$ (e.g. 5 or 6, producing hardware byte `0x50` or `0x60`):
```c
    NVIC_SetPriority(EXTI0_IRQn, 6);
```

### 6. Regression
`make check` runs `scripts/check_priority.py`, confirming `EXTI0_IRQn` priority byte is $\ge 0x50$ (`0x60`), safely within FreeRTOS syscall boundary.

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
3. `task_storage` acquires the shared `xSensorBusLock` and omits `xSemaphoreGive(xSensorBusLock)`, leaking the mutex and starving `task_telemetry` and `iwdg_refresh()`.
4. The IWDG prescaler/reload values were misconfigured, causing watchdog expiration under normal execution.

### 3. Discriminative Evidence
- **Channel 1 (GDB Task State & Synchronization Queue Audit):**
  Inspect `fixtures/task_state_dump.txt`:
  * `info threads` shows both `Task_Telemetry` and `Task_Storage` in `Blocked` state inside `vListInsert ()`.
  * `Task_Telemetry` is blocked waiting on `xSensorBusLock` (`0x20000408`).
    In `xSensorBusLock`, `xMutexHolder` is `0x20000300` (`Task_Storage`)!
  * `Task_Storage` is also blocked waiting for `xSensorBusLock` on its next cycle or blocked on task delays.
  * `Task_Storage` acquired `xSensorBusLock`, copied sensor data, and exited the critical section block without releasing the mutex (`xSemaphoreGive` omitted).
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
    - t = 0.100 s: `iwdg_refresh()` executed.
    - t = 0.105 s: `Task_Storage` acquires `xSensorBusLock` and fails to give it back.
    - t = 0.110 s: `Task_Telemetry` activates, requests `xSensorBusLock`, and blocks permanently.
    - t = 0.110 s .. 0.601 s: Both tasks suspended. Watchdog refresh starved.
    - t = 0.601 s (501 ms after last refresh at t = 0.100 s, within [334 ms, 668 ms] window): Hardware IWDG counter decrements to 0 -> hardware reset asserted.

### 4. Root Cause
In `src/node_app.c`, `task_storage` acquired `xSensorBusLock` but omitted the release call `xSemaphoreGive(xSensorBusLock)`. Leaking the mutex permanently blocked `task_telemetry`, preventing it from calling `iwdg_refresh()` and causing hardware watchdog timeout.

### 5. Minimal Fix
In `src/node_app.c`, ensure `xSemaphoreGive(xSensorBusLock)` is called in `task_storage` after accessing shared data:
```c
        if (xSemaphoreTake(xSensorBusLock, portMAX_DELAY) == pdTRUE) {
            g_storage_cycles++;
            xSemaphoreGive(xSensorBusLock);
        }
```

### 6. Regression
`make check` executes `scripts/check_concurrency.py`, verifying that all mutex acquisitions are properly paired with `xSemaphoreGive()`.

### 7. Non-Proof Limits
A static mutex release audit proves that locks are paired within the examined task bodies. It does **not** prove that third-party library calls cannot block or that hardware LSI clock drift cannot reduce watchdog margins under extreme temperatures.
