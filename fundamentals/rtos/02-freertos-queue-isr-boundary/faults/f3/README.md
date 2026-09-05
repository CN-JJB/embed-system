# Fault Investigation: Fixture `f3`

## Scenario-Reported Symptom (Scenario-provided symptom, not author-captured evidence)
During firmware testing with assertions enabled, the microcontroller traps inside `vAssertCalled()` on the very first timer interrupt. Live GDB call-stack inspection indicates that the failure occurred inside `vPortEnterCritical()`, which failed the assertion checking `(portNVIC_INT_CTRL_REG & portVECTACTIVE_MASK) == 0`.

## Objective
Diagnose why entering a critical section fails the `VECTACTIVE` assertion and replace the prohibited task API with an interrupt-safe equivalent.

## Build
```bash
make -C fundamentals/rtos/02-freertos-queue-isr-boundary/faults/f3 clean all
```
