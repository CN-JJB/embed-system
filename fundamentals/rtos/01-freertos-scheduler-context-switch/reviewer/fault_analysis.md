# P2-M04 Fault Analysis: Comprehensive Learner Diagnostics

## Fixture `f1`: Vector Table Exception Handler Remapping Failure

### Scenario-Reported Symptom & Behavior
Microcontroller boots, runs `main()`, creates tasks, and calls `vTaskStartScheduler()`. It immediately enters an infinite loop in `Default_Handler`.

### Root Cause Analysis
In `src/startup_stm32f103c8.s`, the exception vectors at offsets `0x2C` (SVCall), `0x38` (PendSV), and `0x3C` (SysTick) are declared with weak aliases to `Default_Handler`:
```assembly
.weak SVC_Handler
.thumb_set SVC_Handler,Default_Handler
```
In upstream FreeRTOS `portable/GCC/ARM_CM3/port.c`, the handlers are named `vPortSVCHandler`, `xPortPendSVHandler`, and `xPortSysTickHandler`. If `FreeRTOSConfig.h` omits:
```c
#define vPortSVCHandler     SVC_Handler
#define xPortPendSVHandler  PendSV_Handler
#define xPortSysTickHandler SysTick_Handler
```
the linker fails to override the weak symbols. When `vTaskStartScheduler()` triggers `svc 0`, the CPU vectors into `Default_Handler` (`b .`).

### Static Symbol & Vector Inspection (HOST STATICALLY VERIFIED / TARGET RUN UNVERIFIED)
```bash
arm-none-eabi-nm build/firmware.elf | grep -E '(Default_Handler|SVC_Handler|PendSV_Handler|SysTick_Handler)'
```
Defective state: all four symbols share identical address `08000560`. (Expected runtime behavior: traps in `Default_Handler` — TARGET RUN UNVERIFIED).

### Minimal Fix
Add exception handler remapping macros to `FreeRTOSConfig.h`.

---

## Fixture `f2`: Static Core Clock Mismatch Under HSI Fallback

### Scenario-Reported Symptom & Behavior
When hardware operates on internal HSI fallback (64 MHz PLL), all task delays, timers, and LED blink intervals run 12.5% slower than expected.

### Root Cause Analysis
`FreeRTOSConfig.h` statically defined:
```c
#define configCPU_CLOCK_HZ ((uint32_t)72000000UL)
```
When `vPortSetupTimerInterrupt()` programs `SysTick->LOAD`, it computes:
$$\text{LOAD} = \left( \frac{72,000,000}{1000} \right) - 1 = 71,999 \quad (\texttt{0x1193F})$$
With the core clock running at 64 MHz:
$$f_{\text{tick}} = \frac{64,000,000}{72,000} = 888.89\text{ Hz}$$
Tick interval is $1.125\text{ ms}$ instead of $1.000\text{ ms}$ (12.5% error).

### Disassembly Inspection (HOST STATICALLY VERIFIED / TARGET RUN UNVERIFIED)
```bash
arm-none-eabi-objdump -d build/firmware.elf | grep -A 10 '<vPortSetupTimerInterrupt>:'
```
Defective state: literal pool contains fixed `.word 0x0001193f`. (Target waveform/timing measurement: UNVERIFIED).

### Minimal Fix
Define `#define configCPU_CLOCK_HZ (SystemCoreClock)` and ensure `clock_init()` assigns `SystemCoreClock = 64000000U` upon fallback.

---

## Fixture `f3`: Task Stack Sizing and Underflow Budget Defect

### Scenario-Reported Symptom & Behavior
Target crashes into `HardFault_Handler` on the first function call inside a newly created worker task.

### Root Cause Analysis
The task stack depth was passed as 16 words (64 bytes):
`xTaskCreate(vWorkerTask, "Worker", 16, NULL, 1, NULL);`
On Cortex-M3:
- Hardware exception frame = 8 words (32 bytes: xPSR, PC, LR, R12, R3-R0).
- Software context switch frame = 8 words (32 bytes: R4-R11).
- Total initial frame = 16 words (64 bytes).
The stack pointer at task launch is already at the very bottom boundary (`pxStack`). Any local variable allocation or subroutine call immediately pushes past the bottom boundary, corrupting adjacent heap structures. (Hardware crash behavior: EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED).

### Minimal Fix
Enforce `TASK_STACK_SIZE_WORDS >= 128` (512 bytes minimum per task stack).

---

## Fixture `f4`: Missing Thumb Bit in Synthetic Task Stack (`INVSTATE`)

### Scenario-Reported Symptom & Behavior
During scheduler launch, the CPU executes `svc 0`, unrolls the initial task context, and immediately crashes into `UsageFault_Handler` before executing any task code. `SCB->CFSR` bit 17 (`INVSTATE`) is set.

### Root Cause Analysis
In `port.c`, `pxPortInitialiseStack()` creates the synthetic hardware frame.
ARM Cortex-M microcontrollers ONLY support the Thumb-2 instruction set.
If the initial `xPSR` word on stack is initialized to `0x00000000` instead of `0x01000000` (bit 24 cleared):
$$\text{xPSR[24]} == 0 \implies \text{UsageFault INVSTATE}$$
The CPU attempts to resume execution in ARM 32-bit state, which does not exist on Cortex-M. (ARMv7-M architectural invariant; register fault status: EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED).

### Minimal Fix
Define `#define portINITIAL_XPSR ( 0x01000000UL )` in `port.c`.

---

## Fixture `f5`: Heap Exhaustion During Kernel Task Allocation

### Scenario-Reported Symptom & Behavior
Target stops during startup inside `vApplicationMallocFailedHook()` or hits `bkpt #0`. The scheduler never starts.

### Root Cause Analysis
`FreeRTOSConfig.h` defined `configTOTAL_HEAP_SIZE` as 512 bytes.
Task creation requires:
- Task stack: $128 \times 4 = 512\text{ bytes}$
- TCB: $\approx 84\text{ bytes}$
- Alignment overhead: 8 bytes per block
Total for one task $\approx 604\text{ bytes} > 512\text{ bytes}$.
The first `xTaskCreate` fails, returning `errCOULD_NOT_ALLOCATE_REQUIRED_MEMORY` (`NULL`), and triggers `vApplicationMallocFailedHook()`. (Allocation failure behavior: EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED).

### Minimal Fix
Allocate `configTOTAL_HEAP_SIZE ((size_t)(10 * 1024))` (10 KB heap) out of the available 20 KB SRAM.
