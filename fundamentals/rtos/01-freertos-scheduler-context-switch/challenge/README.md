# P2-M04 Challenge: FreeRTOS Kernel Integration and Dual-Task Context Switch

## 1. Objective

In this challenge, you will implement a complete, learner-owned integration bundle for **FreeRTOS V11.3.0** on the **STM32F103 (ARM Cortex-M3)** microcontroller.

You are responsible for:
1. Configuring the FreeRTOS kernel (`FreeRTOSConfig.h`):
   - Remapping the Cortex-M port handlers (`vPortSVCHandler`, `xPortPendSVHandler`, `xPortSysTickHandler`) to the hardware interrupt vector symbols (`SVC_Handler`, `PendSV_Handler`, `SysTick_Handler`).
   - Establishing dynamic clock coherence by tying `configCPU_CLOCK_HZ` to `SystemCoreClock` to ensure exact 1 kHz tick reload across 72 MHz HSE and 64 MHz HSI fallback.
   - Configuring `configKERNEL_INTERRUPT_PRIORITY` to the lowest implemented Cortex-M3 priority (`0xF0`).
   - Dimensioning a dedicated 10 KB heap for `heap_4.c` within the 20 KB SRAM limit.
2. Implementing the dual-task application (`scheduler_app.c`):
   - Initializing the clock tree and GPIO diagnostic pins (PA1 for Task A, PA2 for Task B).
   - Creating Task A (Priority 2, 128 words stack) that asserts PA1, blocks for 5 ms via `vTaskDelay(pdMS_TO_TICKS(5))`, deasserts PA1, and delays 5 ms.
   - Creating Task B (Priority 1, 128 words stack) that toggles PA2 during Task A's blocked intervals.
   - Checking and validating return codes from `xTaskCreate()`.
   - Starting the FreeRTOS preemptive scheduler via `vTaskStartScheduler()`.

---

## 2. Prerequisites

Before attempting this challenge, ensure you have completed and understood:
- Module Labs 01–05 (`labs/01-freertos-kernel-integration` through `labs/05-heap4-sram-budget`);
- ARM Cortex-M3 exception handling, NVIC priority grouping, and tail-chaining;
- Distinction between Main Stack Pointer (MSP) and Process Stack Pointer (PSP);
- The 16-word Cortex-M context frame and the role of `EXC_RETURN` (`0xFFFFFFFD`);
- FreeRTOS `heap_4` coalescing memory management.

---

## 3. Environment

- **Host OS**: Linux (Ubuntu x86_64 or WSL2)
- **Target Microcontroller**: STM32F103C8T6 (ARM Cortex-M3, 64 KB Flash, 20 KB SRAM)
- **Toolchain**: GNU Arm Embedded Toolchain (`arm-none-eabi-gcc`, `arm-none-eabi-nm`, `arm-none-eabi-size`, `arm-none-eabi-objdump`)
- **Kernel**: Pinned FreeRTOS V11.3.0 (located in `fundamentals/rtos/vendor/freertos/`)

---

## 4. Estimated Time

- **Estimated Time**: 90 minutes

---

## 5. AI Mode = AI-Free

> **IMPORTANT**: This challenge is designated **AI-Free**.  
> You must formulate the configuration macros, task functions, and integration logic yourself using the official FreeRTOS documentation and ARM architecture manuals. Do not use generative AI to produce the solution.

---

## 6. Starter / Submission Contract

Your submission is evaluated as an **integrated 3-file bundle**:

```text
<submission-directory>/
├── scheduler_app.h      # Interface header and task configuration contracts
├── scheduler_app.c      # Task initialization, task creation, and execution bodies
└── FreeRTOSConfig.h     # Learner-owned FreeRTOS kernel configuration
```

Starter templates with guided TODO annotations are provided in:
`fundamentals/rtos/01-freertos-scheduler-context-switch/challenge/starter/`

> **NOTE**: The untouched starter intentionally fails automated validation until all TODO items are resolved and the contracts are implemented.

---

## 7. Allowed Official Documentation

- *FreeRTOS Kernel Developer Guide* (FreeRTOS.org)
- *ARM Cortex-M3 Technical Reference Manual* (ARM DDI 0337E)
- *STM32F103xC/D/E Reference Manual* (ST RM0008)
- *PM0056: STM32F10xxx/20xxx/21xxx/L1xxxx Cortex-M3 programming manual*

---

## 8. Build and Validation Command

To test your submission bundle, run the automated challenge validator:

```bash
bash fundamentals/rtos/01-freertos-scheduler-context-switch/challenge/verify_challenge.sh <path-to-your-submission-dir>
```

Alternatively, invoke `validate.sh` directly:

```bash
bash fundamentals/rtos/01-freertos-scheduler-context-switch/challenge/validate.sh <path-to-your-submission-dir>
```

If no directory argument is passed, `verify_challenge.sh` tests the untouched starter bundle (which will report pending TODO items).

---

## 9. Required Evidence

The automated validator checks the following 14 concrete criteria against your submitted bundle:
1. **Pinned Kernel Source**: Validates that FreeRTOS V11.3.0 is referenced.
2. **Vector Remapping**: Static analysis checks `vPortSVCHandler`, `xPortPendSVHandler`, and `xPortSysTickHandler` macro definitions.
3. **Vector Table Entries**: Binary inspection of ELF and `.bin` proves vector table offsets 11, 14, and 15 resolve to the FreeRTOS handlers and do **not** point to `Default_Handler`.
4. **Clock Coherence**: Proves `configCPU_CLOCK_HZ` dynamically tracks `SystemCoreClock`, and validates SysTick reload values for 72 MHz (71999) and 64 MHz (63999).
5. **Kernel Priority**: Proves `configKERNEL_INTERRUPT_PRIORITY` is set to the lowest priority (`0xF0` / 255).
6. **Heap Budget**: Validates `configSUPPORT_DYNAMIC_ALLOCATION == 1` and `configTOTAL_HEAP_SIZE` is within safe SRAM bounds (>= 2 KB and <= 16 KB).
7. **Task Stack Size**: Validates task stack depths are >= 128 words.
8. **Return Code Checking**: Confirms `xTaskCreate()` return codes are checked against `pdPASS`.
9. **Priority Relationship**: Enforces `Task_A` priority > `Task_B` priority.
10. **Non-busy Blocking**: Enforces `Task_A` calls `vTaskDelay(pdMS_TO_TICKS(5))` to transition to Blocked.
11. **Scheduler Launch**: Confirms `vTaskStartScheduler()` is called.
12. **Linker & Memory Bounds**: Verifies final ELF fits in 64 KB Flash and 20 KB SRAM.
13. **Heap Exclusivity**: Verifies `ucHeap` symbol presence matching configured size and verifies absence of standard libc `malloc()` / `free()`.
14. **Disassembly Integrity**: Inspects `PendSV_Handler` and `SVC_Handler` disassembly for PSP stack frame operations (`mrs r0, psp`, `msr psp, r0`, `vTaskSwitchContext`).

---

## 10. Expected Observation

When running on hardware or logic analyzer:
- **PA1 (Task A)** toggles with a 10 ms period (5 ms HIGH, 5 ms LOW; 100 Hz square wave).
- **PA2 (Task B)** executes CPU burn loops and toggles rapidly only during the 5 ms intervals when Task A is Blocked.
- When Task A's 5 ms timer expires, SysTick unblocks Task A, and PendSV preempts Task B immediately because Task A has higher priority.

---

## 11. Actual Verification Status

| Artifact / Property | Verification Status | Verification Basis |
|---|---|---|
| Pinned FreeRTOS V11.3.0 Identity | **VERIFIED** | Static version check in `task.h` |
| Vector Remapping & Binary Vectors | **VERIFIED** | Linker symbols and binary image inspection |
| Dynamic Clock & Reload Arithmetic | **VERIFIED** | Macro evaluation and reload equation checks |
| Dual-Task Compilation & Linking | **VERIFIED** | Cross-compiler build with `-Wall -Wextra -Werror` |
| SRAM Footprint & Heap Size | **VERIFIED** | `arm-none-eabi-size` and `nm` symbol inspection |
| Context Switch Disassembly | **VERIFIED** | Disassembly inspection (`arm-none-eabi-objdump`) |
| Physical Oscilloscope Waveforms | **UNVERIFIED** | Automated headless environment without hardware |
| Live GDB Stepping on Target | **UNVERIFIED** | Automated headless environment without hardware |

---

## 12. Conceptual Questions

1. **Vector Mapping**: Why do we use preprocessor macros to remap `vPortSVCHandler` to `SVC_Handler` rather than renaming the port function in `port.c`?
2. **Interrupt Priority**: Why must `PendSV` and `SysTick` run at the lowest possible interrupt priority (`0xF0`), while application ISRs may run at higher priorities?
3. **Dynamic Clock**: If the system crystal fails and the clock falls back from 72 MHz to 64 MHz HSI, what happens to `vTaskDelay(pdMS_TO_TICKS(500))` if `configCPU_CLOCK_HZ` was statically set to 72,000,000?
4. **Allocator Choice**: Why does the bare-metal kernel prohibit standard `malloc()` in favor of `heap_4.c`?

---

## 13. Common Failure Modes

1. **Trap in `Default_Handler`**:
   - *Symptom*: Target halts in an infinite loop inside `Default_Handler` as soon as `vTaskStartScheduler()` triggers SVC 0.
   - *Cause*: Forgot to define `vPortSVCHandler SVC_Handler` in `FreeRTOSConfig.h`.
2. **Clock Drift / Dilated Delays**:
   - *Symptom*: Delays run 12.5% slower after HSE failure.
   - *Cause*: Hardcoded `configCPU_CLOCK_HZ` to `72000000UL` instead of dynamic `(SystemCoreClock)`.
3. **Immediate Scheduler Crash**:
   - *Symptom*: HardFault or assertion failure in `vPortValidateInterruptPriority()`.
   - *Cause*: Configured `configKERNEL_INTERRUPT_PRIORITY` to 0 (highest priority) instead of 0xF0 (lowest).
4. **Task B Starvation**:
   - *Symptom*: PA2 never toggles; Task B never runs.
   - *Cause*: Task A uses a busy-wait loop instead of `vTaskDelay()`, permanently starving lower-priority Task B.
5. **Inverted Priorities**:
   - *Symptom*: Task B starves Task A.
   - *Cause*: Task B assigned priority 2 and Task A assigned priority 1.
6. **Heap Allocation Failure**:
   - *Symptom*: `xTaskCreate()` returns `errCOULD_NOT_ALLOCATE_REQUIRED_MEMORY`.
   - *Cause*: `configTOTAL_HEAP_SIZE` configured too small to fit the TCBs and stacks for Task A, Task B, and the Idle task.

---

## 14. Debug Strategy

1. **Step 1 — Static Validator**: Run `bash validate.sh <submission-dir>` to catch syntax, macro, and priority mismatches immediately.
2. **Step 2 — Symbol Resolution**: Run `arm-none-eabi-nm <elf-file> | grep -E "Handler|Heap"` to inspect symbol addresses and sizes.
3. **Step 3 — Vector Inspection**: Dump the first 64 bytes of the binary image with `hexdump -C` to verify vector offsets 0x2C (SVC), 0x38 (PendSV), and 0x3C (SysTick).
4. **Step 4 — Disassembly Check**: Run `arm-none-eabi-objdump -d <elf-file> | grep -A 20 "<PendSV_Handler>:"` to confirm that the PSP save/restore sequence is intact.

---

## 15. Cleanup

To remove test artifacts and temporary build outputs generated during manual testing:

```bash
rm -f build/firmware.elf build/firmware.map build/firmware.bin build/firmware.asm
```

---

## 16. Sources

- FreeRTOS V11.3.0 Source Distribution: `fundamentals/rtos/vendor/freertos/`
- ARMv7-M Architecture Reference Manual (DDI 0403E.e)
- STMicroelectronics STM32F103 Reference Manual RM0008
