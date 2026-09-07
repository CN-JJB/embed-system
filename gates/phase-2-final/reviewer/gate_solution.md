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
Firmware compiles and links cleanly with `-nostartfiles -Wl,--gc-sections` and zero warnings. However, upon booting, the core never enters the main operational loop; instead, it enters an infinite trap loop inside `main()` because the pre-main constructor token assertion fails (`g_boot_preinit_token == 0` instead of `0x5A5AA5A5`).

### 2. Plausible Hypotheses
1. `__libc_init_array()` is not invoked by `Reset_Handler` in `startup_stm32f103c8.s`.
2. `.data` or `.bss` initialization loops overwrite `g_boot_preinit_token` after the constructor executes.
3. Linker garbage collection (`--gc-sections`) discarded `.init_array` because the section input pattern lacked the `KEEP()` directive.
4. The entry point symbol in the ELF header is pointing directly to `main()` rather than `Reset_Handler`.

### 3. Discriminative Evidence
Inspect section headers in the compiled ELF:
```bash
arm-none-eabi-readelf -W -S build/firmware.elf | grep -E '\.init_array'
```
Observation:
```text
  [ 5] .init_array       INIT_ARRAY      08000218 001218 000000 04  WA  0   0  1
```
Section size is `000000` (0 bytes)!
Inspect symbol table:
```bash
arm-none-eabi-nm build/firmware.elf | grep "system_peripheral_preinit"
```
Observation: Symbol `system_peripheral_preinit` is completely absent from the symbol table.
Inspect linker map:
```text
.init_array     0x08000218        0x0
 *(.init_array*)
```
The constructor function was discarded as unreferenced during `--gc-sections`.

### 4. Root Cause
In `linker/stm32f103c8tx_flash.ld`, the `.init_array` section definition used:
```ld
    .init_array :
    {
        . = ALIGN(4);
        PROVIDE_HIDDEN (__init_array_start = .);
        *(SORT(.init_array.*))
        *(.init_array*)
        PROVIDE_HIDDEN (__init_array_end = .);
        . = ALIGN(4);
    } > FLASH
```
Because no C function explicitly calls `system_peripheral_preinit` by name (it is called solely via function pointer array in `__libc_init_array()`), the GNU linker's `--gc-sections` optimization considered the input section unused and discarded it. The GNU ld `KEEP()` directive is mandatory to mark these sections as non-discardable.

### 5. Minimal Fix
Enclose the input section wildcards in `KEEP()`:
```ld
    .init_array :
    {
        . = ALIGN(4);
        PROVIDE_HIDDEN (__init_array_start = .);
        KEEP (*(SORT(.init_array.*)))
        KEEP (*(.init_array*))
        PROVIDE_HIDDEN (__init_array_end = .);
        . = ALIGN(4);
    } > FLASH
```

### 6. Regression
Run `make clean && make check`:
`readelf -W -S build/firmware.elf` confirms `.init_array` size is 4 bytes (`0x000004`).
`nm build/firmware.elf` confirms `system_peripheral_preinit` is present in Flash.

### 7. Non-Proof Limits
A non-zero `.init_array` section in the ELF proves the constructor pointers were retained in Flash by the linker. It does **not** prove that `__libc_init_array()` executed without faults on hardware or that peripheral hardware was properly configured.

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
TIM3 generates 10.0 kHz TRGO pulses, ADC1 performs regular conversions on PA0, and DMA1 Channel 1 generates Half-Transfer and Transfer-Complete interrupts. However, memory dump of destination buffer `g_adc_buffer` shows that only index `0` is updated; indices `1..127` remain static at `0x0000`.

### 2. Plausible Hypotheses
1. `ADC1->CR2` lacks the `DMA` bit, failing to generate DMA request pulses after index 0.
2. `DMA1_Channel1->CCR` lacks the `CIRC` bit, stopping after 1 single transfer.
3. `DMA1_Channel1->CCR` lacks the memory increment enable bit (`MINC = 0`), causing every DMA transfer to overwrite destination address `CMAR` (slot 0) instead of incrementing.
4. Destination buffer size in `CNDTR` was initialized to 1 instead of 128.

### 3. Discriminative Evidence
Inspect `fixtures/register_dump.txt`:
```text
DMA1_Channel1->CCR   = 0x00002527 (EN=1, TCIE=1, HTIE=1, DIR=0, CIRC=1, PSIZE=01, MSIZE=01, PL=10, MINC=0, PINC=0)
DMA1_Channel1->CNDTR = 0x00000040 (64 transfers remaining in current buffer half)
DMA1_Channel1->CMAR  = 0x20000200 (&g_adc_buffer[0])
```
Observations:
- Bit 5 (`CIRC`) is set (1).
- `CNDTR` is actively decrementing (64 remaining).
- Bit 7 (`MINC` / `0x80`) is cleared (0)!
In disassembly of `dma1_channel1_init`:
The constant loaded into `CCR` is `0x52e`.
`0x52e` breakdown: `CIRC(0x20) | PSIZE_0(0x100) | MSIZE_0(0x400) | HTIE(0x04) | TCIE(0x02) | TEIE(0x08) = 0x52e`.
Bit 7 (`0x80`) is absent.

### 4. Root Cause
In `src/dma.c`, `DMA1_Channel1->CCR` configuration omitted `DMA_CCR_MINC`. Without `MINC`, the DMA controller keeps the memory pointer frozen at `CMAR` (`&g_adc_buffer[0]`). Each 16-bit ADC conversion is written to `g_adc_buffer[0]`, leaving the remaining 127 elements unpopulated.

### 5. Minimal Fix
In `src/dma.c`, add `DMA_CCR_MINC` to the `DMA1_Channel1->CCR` bitmask:
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
`make check` disassembles `dma1_channel1_init` and confirms the constant loaded for `CCR` is `0x5ae` (`0x52e | 0x80`), confirming `MINC` is active.

### 7. Non-Proof Limits
Confirming `MINC=1` in `CCR` proves the DMA controller is configured to advance memory addresses. It does **not** prove analog signal accuracy, ADC calibration quality, or jitter-free timer triggering on physical silicon.

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
Integration testing halts inside `vPortValidateInterruptPriority()` assertion when external sensor interrupt `EXTI0_IRQHandler` executes.

### 2. Plausible Hypotheses
1. FreeRTOS priority grouping in `SCB->AIRCR` was configured with subpriorities rather than group priority 0.
2. `EXTI0_IRQHandler` called a non-ISR FreeRTOS API (`xQueueSend` instead of `xQueueSendFromISR`).
3. `EXTI0_IRQn` was assigned a logical priority numerically less than `configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY` (5), giving it higher hardware priority than `configMAX_SYSCALL_INTERRUPT_PRIORITY` (`0x50`).

### 3. Discriminative Evidence
Inspect `fixtures/pendsv_gdb_trace.txt`:
```text
(gdb) x/1bx (0xE000E400 + 6)   # NVIC->IP[EXTI0_IRQn]
0xe000e406:	0x40
```
Cortex-M3 hardware priority register byte is `0x40`.
Calculate logical priority: `0x40 >> 4 = 4`.
In `FreeRTOSConfig.h`:
```c
#define configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY 5
#define configMAX_SYSCALL_INTERRUPT_PRIORITY (5 << 4) = 0x50
```
In Cortex-M3, priority 4 has higher preemption urgency than priority 5 (`0x40 < 0x50`).
When FreeRTOS enters a critical section, it writes `0x50` into `BASEPRI`.
Because `0x40 < 0x50`, `EXTI0_IRQn` is **not masked** by `BASEPRI`.
If `EXTI0_IRQHandler` executes during a critical section and calls `xQueueSendFromISR()`, it concurrently mutates kernel list structures, causing kernel corruption. FreeRTOS traps this condition inside `vPortValidateInterruptPriority()`.

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
`NVIC_SetPriority(EXTI0_IRQn, 4);`
assigned logical priority 4 (`0x40`), which exceeds the maximum allowable system call priority boundary (`0x50` / logical 5).

### 5. Minimal Fix
In `src/interrupt_config.c`, set logical priority $\ge 5$ (e.g. 5, 6, or 7):
```c
    NVIC_SetPriority(EXTI0_IRQn, 6);
```

### 6. Regression
`make check` verifies that the priority byte loaded into `NVIC->IP[EXTI0_IRQn]` is $\ge 0x50$ (logical priority $\ge 5$).

### 7. Non-Proof Limits
A static priority check proves the interrupt priority is compatible with `BASEPRI`. It does **not** prove that queue buffers will not overflow under extreme external interrupt rates or that context switches occur within bounded time.

---

## Part D: Concurrency, Priority Inversion & HW/SW Debugging

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
Under concurrent workloads:
- `Task_Telemetry` (Priority 3, period 50 ms) exhibits severe latency jitter (> 200 ms).
- Microcontroller abruptly restarts.
- `RCC->CSR` confirms watchdog reset (`IWDGRSTF = 1`).

### 2. Plausible Hypotheses
1. `Task_Storage` has an unconstrained infinite loop, preventing all other tasks from running.
2. `Task_Telemetry` stack overflowed, triggering `vApplicationStackOverflowHook()`.
3. `xSharedResourceLock` was created as a binary semaphore without priority inheritance, causing `Task_Compute` (Priority 2) to starve `Task_Storage` (Priority 1) while `Task_Storage` holds the lock, blocking `Task_Telemetry` (Priority 3) and causing `Task_Storage` to miss its IWDG watchdog refresh deadline.
4. IWDG timeout was miscalculated and expired under normal task execution.

### 3. Discriminative Evidence
- **Channel 1 (GDB Task State & Lock Inspection):**
  Inspect `fixtures/task_state_dump.txt`:
  * `Task_Compute` (Priority 2) is in `Running` state.
  * `Task_Telemetry` (Priority 3) is `Blocked` on `xSharedResourceLock`.
  * `Task_Storage` (Priority 1) holds the lock, but its `uxPriority` remains 1! No priority inheritance occurred.
  * `xSharedResourceLock` has `uxItemSize = 0` and `xMutexHolder = NULL`, proving it is a Binary Semaphore, not a Mutex!
- **Channel 2 (Reset Flag & Timing Trace):**
  Inspect `fixtures/watchdog_reset_trace.txt`:
  * `RCC->CSR = 0x24000000`: Bit 29 (`IWDGRSTF`) is set, proving hardware watchdog reset.
  * Timing trace shows `Task_Compute` ran for > 500 ms while `Task_Storage` was preempted, preventing `Task_Storage` from executing `iwdg_refresh()` before the 500 ms window expired.

### 4. Root Cause
In `src/node_app.c`, `xSharedResourceLock = xSemaphoreCreateBinary();` was used for mutual exclusion. Binary semaphores do not track the owner task (`xMutexHolder`) and do not implement priority inheritance. When `Task_Compute` (Priority 2) preempted `Task_Storage` (Priority 1) while it held the lock, `Task_Telemetry` (Priority 3) was blocked indefinitely. Unbounded priority inversion starved `Task_Storage`, which failed to refresh the independent watchdog (IWDG), triggering a hardware reset.

### 5. Minimal Fix
In `src/node_app.c`:
Change `xSharedResourceLock = xSemaphoreCreateBinary();` to `xSharedResourceLock = xSemaphoreCreateMutex();`.
With a mutex, when `Task_Telemetry` (Priority 3) requests `xSharedResourceLock`, FreeRTOS elevates `Task_Storage`'s priority to 3, allowing it to finish its critical section without preemption from `Task_Compute` (Priority 2), release the lock, and refresh the IWDG.

### 6. Regression
`make check` verifies that `xQueueCreateMutex` is invoked during `node_app_init()`.

### 7. Non-Proof Limits
A clean compile and mutex creation prove that priority inheritance is enabled. It does **not** prove absence of deadlocks if multiple locks are acquired out-of-order, nor does it prove that the watchdog timeout cannot expire under extended compute starvation if priority inheritance is not properly maintained across all tasks.
