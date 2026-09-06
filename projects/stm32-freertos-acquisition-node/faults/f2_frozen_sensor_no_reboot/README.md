# Fault Case F2: Frozen Sensor Input Produces Silent Stall Without Watchdog Reset

## Manifested Symptom

During an environmental simulation test, the upstream sensor trigger is disconnected or stalls (e.g. TIM3 update trigger stops or ADC conversions cease). As expected, PA1 stops toggling and the USART1 telemetry stream ceases entirely.

However, contrary to safety specifications, the node remains permanently hung in this stalled condition. The Independent Watchdog (IWDG) does not trigger a hardware reset even after several minutes, forcing manual power-cycling to restore service.

## Investigation Workflow

1. **Formulate Hypotheses**:
   Formulate 3 to 5 candidate hypotheses explaining why the node fails to initiate a hardware watchdog reboot when the primary data acquisition pipeline has stalled:
   - Hardware watchdog configuration failure (e.g. LSI oscillator stopped, window/prescaler mismatch, or IWDG peripheral inactive).
   - Watchdog kick logic executing unconditionally without gating on subsystem progress.
   - Task starvation or priority inversion affecting supervisory execution.
   - Reset flags or fault handlers trapping execution without triggering reset.
2. **Design Discriminative Observations**:
   Determine what debugger observations, register inspections (e.g. IWDG->SR, RCC->CSR), or GPIO timing captures distinguish between these failure modes.
3. **Isolate Root Cause**:
   Trace the supervision architecture in `Task_Health` and verify how watchdog refresh decisions are coupled to actual acquisition milestones.
4. **Implement Surgical Fix**:
   Ensure watchdog refreshing is strictly conditional upon verified system progress, stack bounds, and heap health.
5. **Verify**:
   Confirm that `scripts/verify_project.sh` passes.

