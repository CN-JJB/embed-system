# Lab 04: Cortex-M3 Priority Grouping and NVIC/BASEPRI Syscall Boundary

## Objective
Distinguish CMSIS logical priority from hardware encoded priority bytes, understand the effect of `NVIC_SetPriorityGrouping(0)`, and trace how FreeRTOS `vPortValidateInterruptPriority()` asserts interrupt priority compliance.

## Prerequisites
- P2-M02: Cortex-M3 NVIC registers, priority bits, and `BASEPRI`.
- Lab 02: Synthetic TIM2 ISR handoff.

## Estimated Time
- 45 minutes (MUST load).

## Architectural Principles

### 1. CMSIS Logical Priority vs Hardware Encoded Byte
STM32F103 implements 4 bits of interrupt priority (`__NVIC_PRIO_BITS = 4`), placed in bits [7:4] of each NVIC priority register:
- **CMSIS Function**: `NVIC_SetPriority(IRQn, priority)` takes an unshifted logical integer from $0$ to $15$.
  It internally performs:
  ```c
  NVIC->IP[IRQn] = (uint8_t)((priority << (8 - __NVIC_PRIO_BITS)) & (uint32_t)0xFF);
  ```
- **Example Encodings**:
  - Logical 0 $\longrightarrow$ Encoded byte `0x00` (highest urgency)
  - Logical 2 $\longrightarrow$ Encoded byte `0x20`
  - Logical 5 $\longrightarrow$ Encoded byte `0x50` (`configMAX_SYSCALL_INTERRUPT_PRIORITY`)
  - Logical 6 $\longrightarrow$ Encoded byte `0x60` (valid syscall ISR)
  - Logical 15 $\longrightarrow$ Encoded byte `0xF0` (lowest urgency, SysTick/PendSV)

### 2. FreeRTOS Syscall Boundary Contract
In `FreeRTOSConfig.h`:
```c
#define configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY 5
#define configMAX_SYSCALL_INTERRUPT_PRIORITY         (5 << 4) /* 0x50 */
```
- **The Masking Mechanism**: When FreeRTOS enters an ISR-safe critical section (`portSET_INTERRUPT_MASK_FROM_ISR()`), it writes `configMAX_SYSCALL_INTERRUPT_PRIORITY` (`0x50`) into the Cortex-M `BASEPRI` register.
- **Hardware Effect**: All interrupts with encoded priority $\ge 0x50$ (logical 5 to 15, lower urgency) are masked. Interrupts with encoded priority $< 0x50$ (logical 0 to 4, higher urgency) remain active and unmasked.
- **Strict Prohibition**: Interrupts with logical priority 0 to 4 must **NEVER** call any FreeRTOS API, because they can preempt kernel critical sections and access RTOS data structures while the kernel is in the middle of modifying them!

### 3. Priority Grouping (`NVIC_SetPriorityGrouping(0)`)
The Cortex-M Application Interrupt and Reset Control Register (`SCB->AIRCR`) contains the `PRIGROUP` field:
- Setting `NVIC_SetPriorityGrouping(0)` (or `7` depending on CMSIS convention for binary point position) assigns all 4 implemented bits to **pre-emption priority**, with 0 bits for subpriority.
- Upstream FreeRTOS `vPortValidateInterruptPriority()` in `port.c` checks:
  ```c
  configASSERT( ( portAIRCR_REG & portPRIORITY_GROUP_MASK ) <= ulMaxPRIGROUPValue );
  ```
  If priority grouping is omitted or set incorrectly, this assertion fails immediately upon the first FreeRTOS API call from an ISR.

## Lab Procedure
1. In `src/main.c`, confirm that `NVIC_SetPriorityGrouping(0)` is executed before `vTaskStartScheduler()`.
2. In `src/timer.c`, confirm that `NVIC_SetPriority(TIM2_IRQn, 6)` is used:
   - Logical 6 corresponds to encoded byte `0x60`.
   - `0x60 >= 0x50`, strictly satisfying the syscall threshold.
3. Open `vendor/freertos/portable/GCC/ARM_CM3/port.c` and review `vPortValidateInterruptPriority()`. Note how `ulCurrentInterrupt` is queried from `SCB->ICSR` and checked against `ucMaxSysCallPriority`.

> **Status**: Static register formulas and source checks VERIFIED; live GDB assertion capture UNVERIFIED (Headless automated build).
