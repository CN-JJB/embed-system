# P2-M02 Gate Solution & Diagnostic Walkthrough

> **Assessment Mode**: AI-Free (Strict)  
> **Target Mastery**: L4-local register/MMIO interaction, L3 NVIC handling  
> **Time Limit**: 50 minutes

---

## 1. Complete Diagnostic Mapping

```text
symptom
→ hypotheses
→ evidence
→ root cause
→ minimal fix
→ regression
```

### Step 1: Symptom
The Gate firmware in `gate/gate_fault_firmware/` compiles cleanly with zero warnings and executes on hardware or simulation, but:
1. `g_tim2_ticks` increments to `1` and permanently ceases forward progress; the heartbeat indicator pin (PA1) toggles exactly once at startup and remains permanently frozen.
2. The main thread loop in `main()` continues running without hanging (no watchdog reset, no hard fault, no interrupt lockup), but periodic timer interrupts cease completely after the first event.

### Step 2: Hypotheses
1. **One-Pulse Mode Misconfiguration (`TIM_CR1_OPM`)**: Bit 3 (`OPM`) of `TIM2->CR1` was erroneously set alongside `CEN` during timer startup, directing hardware to clear `CEN` upon the first update event.
2. **Interrupt Flag Omission (`TIM_SR_UIF`)**: The interrupt service routine failed to clear UIF, causing an interrupt storm (Refuted: Main thread loop continues forward progress, confirming no starvation).
3. **Timer Prescaler / Auto-Reload Overflow**: PSC or ARR was set to `0xFFFFFFFF` or misconfigured so that the next period is too long to observe.
4. **NVIC Masking / Priority Lockout**: The NVIC interrupt line was masked by BASEPRI / PRIMASK or disabled in software after the first firing.

### Step 3: Evidence Collection
Static binary audit (VERIFIED on host):
1. Disassembly of `tim2_init_1khz` in `gate_fault_firmware` reveals:
   ```text
   movs r3, #9
   str  r3, [r2, #0]
   ```
   where `r2` holds `TIM2_BASE` (`0x40000000`) and offset `0` corresponds to `TIM2->CR1`. Value `0x09` is `TIM_CR1_CEN (0x01) | TIM_CR1_OPM (0x08)`.
2. Disassembly of `TIM2_IRQHandler` confirms `TIM2->SR = (uint16_t)~TIM_SR_UIF;` is properly executed:
   ```text
   movw r2, #65534   @ 0xfffe
   str  r2, [r3, #16]
   ldr  r3, [r3, #16]
   ```
   ruling out an interrupt storm.

Diagnostic command and expected interpretation on target hardware (Target run UNVERIFIED):
```text
(gdb) continue
^C
(gdb) print g_tim2_ticks
$1 = 1      <-- Incremented exactly once upon startup

(gdb) print /x TIM2->CR1
$2 = 0x8    <-- OPM bit (bit 3) is set; CEN (bit 0) was automatically cleared by hardware on update event!

(gdb) print /x TIM2->SR
$3 = 0x0    <-- UIF cleared; no pending interrupt
```

### Step 4: Root Cause
In `gate/gate_fault_firmware/timer_gate.c`:
```c
/* Configure timer control register */
TIM2->CR1 = TIM_CR1_CEN | TIM_CR1_OPM;
```
Bit 3 (`TIM_CR1_OPM`) enables One-Pulse Mode. Per RM0008 Section 15.3.10 and Section 15.4.1 (Control Register 1):
- `OPM = 0`: Counter is not stopped at update event (continuous periodic mode).
- `OPM = 1`: Counter stops counting at the next update event (hardware automatically clears `CEN`).

When the first 1 ms update event occurs, timer hardware generates the update interrupt, fires `TIM2_IRQHandler`, and simultaneously clears the `CEN` enable bit in `TIM2->CR1`. The timer counter stops, preventing any further periodic interrupts while Thread mode continues uninterrupted.

### Step 5: Minimal Fix

In `gate/gate_fault_firmware/timer_gate.c`:

```diff
--- a/gate/gate_fault_firmware/timer_gate.c
+++ b/gate/gate_fault_firmware/timer_gate.c
@@ -22,5 +22,5 @@ void tim2_init_1khz(uint32_t timclk_hz)
     NVIC_EnableIRQ(TIM2_IRQn);
 
     /* Configure timer control register */
-    TIM2->CR1 = TIM_CR1_CEN | TIM_CR1_OPM;
+    TIM2->CR1 = TIM_CR1_CEN;
 }
```

### Step 6: Regression Verification
Recompile:
```bash
make -C gate/gate_fault_firmware clean all
```
1. Verify `TIM2->CR1` is loaded with `1` (`TIM_CR1_CEN` only):
   Disassembly should show `movs r3, #1` stored to `[r2, #0]`.
2. Target run (UNVERIFIED): Verify `g_tim2_ticks` increments continuously at 1000 Hz and PA1 toggles at 500 Hz square wave.
3. Run reviewer regression script:
   ```bash
   bash reviewer/verify_gate_regression.sh
   ```
