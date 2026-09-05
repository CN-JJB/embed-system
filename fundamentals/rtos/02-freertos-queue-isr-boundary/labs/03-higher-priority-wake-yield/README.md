# Lab 03: Higher-Priority Wake Semantics and Deferred Preemption

## Objective
Walk through `tasks.c::xTaskRemoveFromEventList()`, understand the exact FreeRTOS V11.3.0 strict `>` preemption condition, analyze how `xPendingReadyList` defers ready transitions when the scheduler is suspended, and trace how `portYIELD_FROM_ISR()` triggers PendSV.

## Prerequisites
- Lab 02: Synthetic TIM2 ISR to task queue handoff.
- P2-M04: PendSV assembly context switch mechanics.

## Estimated Time
- 45 minutes (MUST load).

## Architectural Principles

### 1. The `xTaskRemoveFromEventList()` Unblocking Mechanism
In upstream FreeRTOS `tasks.c`:
```c
BaseType_t xTaskRemoveFromEventList( const List_t * const pxEventList )
{
    TCB_t *pxUnblockedTCB;
    BaseType_t xReturn;

    /* 1. Remove the highest priority task from the event list */
    pxUnblockedTCB = prvGetTCBFromListItem( listGET_HEAD_ENTRY( pxEventList ) );
    ( void ) uxListRemove( &( pxUnblockedTCB->xEventListItem ) );

    if( uxSchedulerSuspended == ( UBaseType_t ) pdFALSE )
    {
        /* 2a. Scheduler active: move directly to ready list */
        ( void ) uxListRemove( &( pxUnblockedTCB->xStateListItem ) );
        prvAddNewTaskToReadyList( pxUnblockedTCB );
    }
    else
    {
        /* 2b. Scheduler suspended: place on pending ready list */
        vListInsertEnd( &( xPendingReadyList ), &( pxUnblockedTCB->xEventListItem ) );
    }

    /* 3. Strict greater-than priority comparison */
    if( pxUnblockedTCB->uxPriority > pxCurrentTCB->uxPriority )
    {
        xReturn = pdTRUE;
    }
    else
    {
        xReturn = pdFALSE;
    }

    return xReturn;
}
```

### 2. Critical Distinctions
- **Strict `>` Comparison**:
  `xTaskRemoveFromEventList()` returns `pdTRUE` **only when** `pxUnblockedTCB->uxPriority > pxCurrentTCB->uxPriority`.
  If the unblocked task has priority equal to the currently running task, `xReturn` is `pdFALSE`. Equal priority tasks do not preempt via ISR unblocking; they share CPU time across SysTick time-slices.
- **Normal Ready vs Suspended Scheduler**:
  If the scheduler is suspended (`uxSchedulerSuspended != 0`, e.g. while another task executes `vTaskSuspendAll()`), the unblocked task cannot be placed into `pxReadyTasksLists`. Instead, it is placed onto `xPendingReadyList`. When `xTaskResumeAll()` is subsequently called, all pending tasks are moved to the ready lists.

### 3. The `portYIELD_FROM_ISR()` Mechanism
In `portable/GCC/ARM_CM3/portmacro.h`:
```c
#define portYIELD_FROM_ISR( x ) do { if( ( x ) != pdFALSE ) { portNVIC_INT_CTRL_REG = portNVIC_PENDSVSET_BIT; } } while( 0 )
```
`portNVIC_INT_CTRL_REG` corresponds to the Cortex-M Interrupt Control and State Register (`SCB->ICSR`, address `0xE000ED04`).
Writing `portNVIC_PENDSVSET_BIT` (bit 28) sets PendSV to pending state.
- **No Immediate Context Switch**: Writing this bit does **not** cause an immediate jump to `PendSV_Handler` while inside `TIM2_IRQHandler()`.
- **Tail-Chaining**: Because PendSV runs at logical priority 15 (lowest hardware priority), Cortex-M exception rules defer it until `TIM2_IRQHandler()` returns and no other pending exception of higher urgency is active. At that point, Cortex-M tail-chains directly into `PendSV_Handler` without restoring MSP state.

## Lab Procedure
1. Locate `xTaskRemoveFromEventList()` in `fundamentals/rtos/vendor/freertos/tasks.c`. Confirm the strict `>` condition at line ~4250.
2. In `src/timer.c`, observe:
   ```c
   BaseType_t xHigherPriorityTaskWoken = pdFALSE;
   xQueueSendFromISR(g_sample_queue, &s_seq, &xHigherPriorityTaskWoken);
   portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
   ```
3. Disassemble `TIM2_IRQHandler`:
   ```bash
   arm-none-eabi-objdump -d build/firmware.elf | grep -A 25 "<TIM2_IRQHandler>:"
   ```
   Verify that `SCB->ICSR` (literal `0xe000ed04`) and `0x10000000` (bit 28) are loaded and conditionally stored.

> **Status**: Source and disassembly VERIFIED; timing oscilloscope capture UNVERIFIED (Headless automated build).
