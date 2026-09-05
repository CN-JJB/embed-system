# Lab 04: The PendSV Context Switch Mechanism and Assembly Level Deep-Dive

## Objective
Dissect the Cortex-M3 PendSV assembly handler (`xPortPendSVHandler`), analyze step-by-step context saving (`portSAVE_CONTEXT`) and restoring (`portRESTORE_CONTEXT`), verify the dual stack pointer architecture (MSP vs PSP), and understand interrupt priority tail-chaining.

## Prerequisites
- Lab 01: FreeRTOS kernel exception mapping.
- Lab 03: Task stack layout and synthetic frames.
- Cortex-M3 assembly instructions: `mrs`, `msr`, `stmdb`, `ldmia`, `isb`, `bx`.

## Environment
- Target: STM32F103C8T6 (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM).
- Toolchain: Arm GNU Toolchain 13.3.rel1 / Ubuntu GCC 13.2.1 cross-compiler.

## Estimated Time
- 60 minutes (MUST load).

## AI Mode
- **AI-Hint**: Socratic guidance permitted on assembly instruction semantics, EXC_RETURN codes, and NVIC tail-chaining. Direct code generation prohibited.

## Architectural Principles

### 1. Why PendSV? The Tail-Chaining Real-Time Rationale
In a real-time system, if context switching occurred directly inside high-priority peripheral ISRs (e.g. DMA, UART, Timer):
- The context switch routine would execute at elevated interrupt priority, blocking other urgent interrupts from being serviced.
- Latency jitter would degrade hard real-time guarantees.

To solve this, ARM Cortex-M provides **PendSV (Pended System Call)**:
1. When an ISR or task requests a context switch, it sets the `PENDSVSET` bit in `SCB->ICSR`:
   ```c
   portNVIC_INT_CTRL_REG = portNVIC_PENDSVSET_BIT;
   ```
2. Because PendSV is configured to the **lowest possible interrupt priority** (`0xF0`):
   - The hardware postpones executing PendSV until all higher-priority active ISRs have finished.
   - When the last ISR executes exception return, the NVIC executes a zero-overhead **tail-chain** directly into PendSV without intermediate unstacking/restacking.
   - The entire context switch executes cleanly at lowest priority before control returns to thread mode.

### 2. Detailed PendSV Assembly Walkthrough
The implementation in `portable/GCC/ARM_CM3/port.c`:

```assembly
.thumb_func
xPortPendSVHandler:
    /* Step 1: Read Process Stack Pointer (PSP) of current running task */
    mrs r0, psp
    isb

    /* Step 2: Locate pxCurrentTCB pointer in RAM */
    ldr r3, =pxCurrentTCB       /* r3 = &pxCurrentTCB */
    ldr r2, [r3]                /* r2 = pxCurrentTCB */

    /* Step 3: Save software-saved registers (R4-R11) to task stack */
    stmdb r0!, {r4-r11}         /* Push R4-R11 onto task stack, decrement r0 */
    str r0, [r2]                /* Save updated top-of-stack to pxCurrentTCB->pxTopOfStack */

    /* Step 4: Protect scheduler call by masking interrupts up to MAX_SYSCALL */
    stmdb sp!, {r3, r14}        /* Save &pxCurrentTCB and EXC_RETURN onto MSP */
    mov r0, #configMAX_SYSCALL_INTERRUPT_PRIORITY
    msr basepri, r0
    dsb
    isb

    /* Step 5: Select highest priority ready task */
    bl vTaskSwitchContext

    /* Step 6: Unmask interrupts */
    mov r0, #0
    msr basepri, r0
    ldmia sp!, {r3, r14}        /* Restore &pxCurrentTCB and EXC_RETURN from MSP */

    /* Step 7: Load new pxCurrentTCB and its top-of-stack */
    ldr r1, [r3]                /* r1 = new pxCurrentTCB */
    ldr r0, [r1]                /* r0 = new pxTopOfStack */

    /* Step 8: Restore software-saved registers (R4-R11) from new task stack */
    ldmia r0!, {r4-r11}         /* Pop R4-R11 from stack, increment r0 */

    /* Step 9: Update PSP with new task stack pointer */
    msr psp, r0
    isb

    /* Step 10: Exception exit return */
    bx r14                      /* EXC_RETURN (0xFFFFFFFD) triggers hardware unstacking */
```

### 3. Dual Stack Pointer Partitioning (MSP vs PSP)
- **MSP (Main Stack Pointer)**: Used by OS kernel, exception handlers, and ISRs. Configured in linker script at `_estack` (`0x20005000`).
- **PSP (Process Stack Pointer)**: Exclusively used by FreeRTOS tasks in Thread mode.
- When `bx r14` is executed with `r14 == 0xFFFFFFFD`:
  - Bit 2 of `EXC_RETURN` is `1`: return to Thread mode using **PSP**.
  - Bit 3 of `EXC_RETURN` is `1`: return to Thread mode (not Handler mode).
  - The Cortex-M hardware automatically pops `R0-R3`, `R12`, `LR`, `PC`, and `xPSR` from PSP into the CPU registers, resuming the newly selected task seamlessly.

## Step-by-Step Procedure

1. **Disassemble the Compiled PendSV Handler**:
   Run:
   ```bash
   arm-none-eabi-objdump -d build/firmware.elf | grep -A 35 "<PendSV_Handler>:"
   ```
2. **Examine Register Transitions**:
   - Trace how `r0` holds the stack pointer before and after `stmdb` / `ldmia`.
   - Verify `basepri` is programmed with `0x50` (`configMAX_SYSCALL_INTERRUPT_PRIORITY`) before calling `vTaskSwitchContext`.
   - Verify `basepri` is cleared to `0` before restoring task context.
3. **Trace `vTaskSwitchContext`**:
   In `tasks.c`:
   - Checks stack overflow if configured.
   - Calls `taskSELECT_HIGHEST_PRIORITY_TASK()`.
   - Updates global variable `pxCurrentTCB`.

## Expected Observations & Verification
- Disassembly shows clean `mrs r0, psp` and `msr psp, r0` sequence.
- Branch to `vTaskSwitchContext` wrapped inside `basepri` masking.
- Return via `bx r14` with EXC_RETURN.

## Actual Verification Status
- **Disassembly & Register Flow Verification**: **VERIFIED** on host cross-compiler.
- **Cycle-Accurate Oscilloscope Context Switch Latency Trace**: **UNVERIFIED** (Headless build environment; no physical probe attached).
