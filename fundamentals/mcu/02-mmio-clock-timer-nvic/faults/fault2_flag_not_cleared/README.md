# Fault Fixture 2: Interrupt Storm (Unacknowledged Flag)

## Symptom
Firmware boots, but the main loop is completely unresponsive. Breakpoints in `main()` never hit. GDB shows the CPU continuously stuck executing `TIM2_IRQHandler`.

## Task
1. Inspect the peripheral status register in the ISR.
2. Determine why the interrupt remains permanently pending in the NVIC.
3. Formulate the minimal fix.

## Build
```bash
make clean && make
```
