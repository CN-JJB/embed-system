# Fault Case F2: Frozen Sensor Input Produces Silent Stall Without Watchdog Reset

## Manifested Symptom

During an environmental simulation test, the upstream sensor trigger is disconnected or stalls (e.g. TIM3 update trigger stops or ADC conversions cease). As expected, PA1 stops toggling and the USART1 telemetry stream ceases entirely.

However, contrary to safety specifications, the node remains permanently hung in this stalled condition. The Independent Watchdog (IWDG) does not trigger a hardware reset even after several minutes, forcing manual power-cycling to restore service.

## Investigation Workflow

1. **Formulate Hypotheses**:
   Draft 3 to 5 distinct candidate hypotheses explaining why the node fails to initiate a hardware watchdog reboot when the primary data acquisition pipeline has stalled. Base your hypotheses strictly on the observable symptom, watchdog architecture, and supervisory design.
2. **Design Discriminative Observations**:
   Determine what debugger observations, register inspections (e.g. `IWDG->SR`, `RCC->CSR`), or GPIO timing captures distinguish between your candidate failure modes.
3. **Isolate Root Cause**:
   Trace the supervisory task implementation and evaluate how system health status is audited and propagated to the watchdog hardware.
4. **Implement Surgical Fix**:
   Implement a surgical fix that ensures the node correctly triggers a hardware watchdog reboot when system progress invariants are violated, while preserving legitimate steady-state operation.
5. **Verify**:
   Confirm that `scripts/verify_project.sh` passes.
