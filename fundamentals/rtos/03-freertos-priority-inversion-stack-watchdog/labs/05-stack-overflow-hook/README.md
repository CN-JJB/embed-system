# Lab 05: Stack Overflow Detection Hooks and Limitations

## Objectives
- Compare FreeRTOS Stack Overflow Check Method 1 vs Method 2.
- Configure `configCHECK_FOR_STACK_OVERFLOW = 2` in `FreeRTOSConfig.h`.
- Implement and diagnose `vApplicationStackOverflowHook()`.

## Stack Overflow Macros (`include/stack_macros.h`)

### Method 1 (`configCHECK_FOR_STACK_OVERFLOW == 1`)
```c
#define taskCHECK_FOR_STACK_OVERFLOW()                                  \
{                                                                       \
    /* Is the current stack pointer within the valid stack limits? */   \
    if( ( pxCurrentTCB->pxTopOfStack <= pxCurrentTCB->pxStack ) )       \
    {                                                                   \
        vApplicationStackOverflowHook( ( TaskHandle_t ) pxCurrentTCB,   \
                                       pxCurrentTCB->pcTaskName );      \
    }                                                                   \
}
```
**Limitation:** Method 1 only inspects `pxTopOfStack` *at the moment of context switch*. If a function allocates 300 bytes on the stack, writes beyond `pxStack` into adjacent variables, and then returns before the next context switch, `pxTopOfStack` will be back inside valid bounds. Method 1 fails completely to detect this silent corruption!

### Method 2 (`configCHECK_FOR_STACK_OVERFLOW == 2`)
```c
#define taskCHECK_FOR_STACK_OVERFLOW()                                              \
{                                                                                   \
    /* First perform the Method 1 pointer check */                                  \
    if( ( pxCurrentTCB->pxTopOfStack <= pxCurrentTCB->pxStack ) ||                  \
        /* Then inspect the last 16 bytes (4 words) of the stack buffer */          \
        ( memcmp( ( void * ) pxCurrentTCB->pxStack,                                 \
                  ( void * ) ( pulStackRef ),                                       \
                  uxSquareBufferCheckSize ) != 0 ) )                                \
    {                                                                               \
        vApplicationStackOverflowHook( ( TaskHandle_t ) pxCurrentTCB,               \
                                       pxCurrentTCB->pcTaskName );                  \
    }                                                                               \
}
```
Method 2 verifies that the 16 bytes at the very bottom of the allocated buffer (`pxStack`) still contain the initial `0xA5` fill pattern. If a deep function call touched this bottom buffer, the hook triggers upon the next context switch.

## Implementing the Overflow Hook

In `src/main.c`:
```c
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
    (void)xTask;
    (void)pcTaskName;

    /* Disable interrupts to freeze system state */
    __disable_irq();

    /* Assert timing markers to signal hardware diagnostic probe */
    gpio_set(GPIO_MARKER_INV_LOW);
    gpio_set(GPIO_MARKER_INV_MED);
    gpio_set(GPIO_MARKER_INV_HIGH);

    /* Trap CPU for GDB inspection */
    for (;;) {
        __NOP();
    }
}
```

## Review Questions
1. Why does `vApplicationStackOverflowHook` receive the task handle and name?
   *(Answer: To allow runtime telemetry or a debugger to immediately identify which task ran out of stack).*
2. Can `configCHECK_FOR_STACK_OVERFLOW` prevent memory corruption from occurring?
   *(Answer: No. The hook is only evaluated during context switches; corruption occurs during task execution before the check runs).*
