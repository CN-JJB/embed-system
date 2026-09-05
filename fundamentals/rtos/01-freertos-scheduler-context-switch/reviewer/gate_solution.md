# P2-M04 Module Gate Solution: Cortex-M3 NVIC Priority Shift Defect

## Gate Defect Summary
The candidate is presented with `gate/gate_fault_firmware/`.
While the scheduler appears functional in isolation, any interrupt-driven environment or architectural register check exposes severe priority masking failures:
FreeRTOS critical sections fail to mask interrupts, allowing ISRs to interrupt `vTaskSwitchContext()` and corrupt kernel task ready lists.

## Root Cause Analysis

### 1. Cortex-M3 Priority Bit Alignment
The ARM Cortex-M3 NVIC specification allows silicon vendors to implement between 3 and 8 bits of interrupt priority.
STM32F103 implements **4 priority bits** (`__NVIC_PRIO_BITS = 4`).

These 4 bits are aligned to the **most significant bits (MSBs)** of each 8-bit priority register:
```text
Bit:    [7]  [6]  [5]  [4]  [3]  [2]  [1]  [0]
Field: [    Implemented   ] [ Unimplemented (0) ]
```

### 2. The BASEPRI Register Failure
FreeRTOS uses the Cortex-M `BASEPRI` register to implement critical sections.
When `BASEPRI` is loaded with a non-zero value, the processor masks all interrupts with priority value greater than or equal to that value (lower or equal priority).

In the defective gate configuration `FreeRTOSConfig.h`:
```c
/* DEFECTIVE CONFIGURATION */
#define configMAX_SYSCALL_INTERRUPT_PRIORITY    5
```
Here, the value `5` (`0b00000101`) occupies bits [2] and [0].
When `PendSV_Handler` executes:
```assembly
mov.w r0, #5
msr   BASEPRI, r0
```
Because the hardware only writes the upper 4 bits [7:4] and hardwires bits [3:0] to zero:
$$\text{BASEPRI} \longleftarrow (5 \ \& \ \texttt{0xF0}) = 0$$
Setting `BASEPRI` to 0 **unmasks all interrupts**!
Instead of creating an atomic critical section, executing `taskENTER_CRITICAL()` or `PendSV_Handler` context switch leaves interrupts completely unmasked!

### 3. Disassembly Comparison

#### Defective Binary:
```assembly
08000d72:  f04f 0005   mov.w   r0, #5
08000d76:  f380 8811   msr     BASEPRI, r0
```

#### Correct Binary:
```assembly
08000d72:  f04f 0050   mov.w   r0, #80      @ 0x50 = (5 << 4)
08000d76:  f380 8811   msr     BASEPRI, r0
```

## Minimal Reference Patch

In `gate/gate_fault_firmware/include/FreeRTOSConfig.h`, change:
```c
- #define configMAX_SYSCALL_INTERRUPT_PRIORITY    5
+ #define configMAX_SYSCALL_INTERRUPT_PRIORITY \
+     (configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY << (8 - configPRIO_BITS))
```

## Automated Verification
Run the regression harness:
```bash
bash fundamentals/rtos/01-freertos-scheduler-context-switch/reviewer/verify_gate_regression.sh
```
Expected output:
```text
=== Running P2-M04 Module Gate Regression Suite ===
Step 1: Building unpatched gate firmware...
[PASS] Defect correctly identified: PendSV_Handler sets BASEPRI to unshifted 5 (evaluates to 0 on Cortex-M3)
Step 2: Applying reference patch to FreeRTOSConfig.h...
Step 3: Building patched gate firmware...
[PASS] Patch verified: PendSV_Handler correctly programs BASEPRI to 0x50 (shifted priority 5)
Step 4: Reverting patch to restore pristine gate challenge...
=== ALL P2-M04 GATE REGRESSION CHECKS PASSED ===
```
