# Fault Case F2: Unconditional Watchdog Refresh Policy Failure

## Symptom
A hardware fault stalls the ADC trigger (TIM3 stops generating TRGO pulses). Telemetry stream ceases on USART1, and PA1 stops pulsing. However, the MCU never triggers a hardware watchdog reset and remains hung indefinitely in a deadlocked state.

## Diagnostic Steps
1. Inspect the Independent Watchdog (IWDG) refresh policy:
   - Does `Task_Health` execute `iwdg_refresh()` unconditionally every 500 ms?
   - Is `iwdg_refresh()` executed regardless of whether `g_acq_transfers` has incremented?
2. Compare the intended safety contract:
   - A watchdog refresh MUST represent a validated assertion that all critical system invariants (acquisition progress, stack high-water mark, heap integrity) are currently satisfied.

## Resolution Contract
Guard `iwdg_refresh()` behind `progress_ok && stack_ok && heap_ok`. If any health condition fails, withhold `iwdg_refresh()` to allow the hardware watchdog (~2000 ms timeout) to reset and recover the node.
