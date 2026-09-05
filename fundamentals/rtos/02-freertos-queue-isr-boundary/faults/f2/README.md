# Fault Investigation: Fixture `f2`

## Scenario-Reported Symptom (Scenario-provided symptom, not author-captured evidence)
When running the firmware, the system hangs inside `vAssertCalled()` during the first call to an ISR-safe FreeRTOS function. Debugging indicates that the assertion failure occurs inside `vPortValidateInterruptPriority()`, but inspecting the timer priority shows that `NVIC_SetPriority(TIM2_IRQn, 6)` was configured, which appears logically valid.

## Objective
Diagnose why `vPortValidateInterruptPriority()` rejects the interrupt configuration despite a seemingly valid logical priority level, and correct the Cortex-M3 priority grouping configuration.

## Build
```bash
make -C fundamentals/rtos/02-freertos-queue-isr-boundary/faults/f2 clean all
```
