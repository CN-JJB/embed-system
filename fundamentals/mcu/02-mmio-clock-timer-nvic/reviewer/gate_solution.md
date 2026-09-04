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
The Gate firmware in `gate/gate_fault_firmware/` compiles cleanly with zero warnings, but upon execution on hardware or simulation:
1. The processor enters an infinite loop inside `TIM2_IRQHandler`; the main thread loop in `main()` ceases forward progress.
2. Timing analysis indicates that before lockup, update events occur at 2000 events/s (2.0 kHz event rate). Because PA1 toggles once per event, the resulting square wave on an oscilloscope is 1000 Hz (1.0 ms square-wave period: 500 us HIGH, 500 us LOW), whereas the intended 1000 events/s rate should produce a 500 Hz square wave (2.0 ms square-wave period: 1.0 ms HIGH, 1.0 ms LOW).

### Step 2: Hypotheses
1. **Clock prescaler math error**: The timer prescaler `TIM2->PSC` was calculated using an assumed 36 MHz clock instead of recognizing the doubled 72 MHz timer clock on APB1.
2. **Interrupt storm**: The peripheral interrupt flag in `TIM2->SR` is not cleared inside `TIM2_IRQHandler`, or is cleared without a memory synchronization barrier (`__DSB()`).
3. **NVIC priority conflict**: `TIM2` priority was configured with an unshifted priority value.
4. **Flash wait state failure**: Flash latency was left at 0 WS, causing instruction prefetch corruptions.

### Step 3: Evidence Collection
Static binary audit (VERIFIED on host):
1. Disassembly of `TIM2_IRQHandler` in `gate_fault_firmware` reveals no store (`STR`) to `TIM2_BASE + 0x10` (`TIM2->SR`).
2. Disassembly of `tim2_init_1khz` reveals `TIM2->PSC` is loaded with literal `35` (`0x23`).

Diagnostic command and expected interpretation on target hardware (Target run UNVERIFIED):
```text
(gdb) continue
^C
(gdb) backtrace
#0  TIM2_IRQHandler () at timer_gate.c:30
#1  <signal handler called>
#2  main () at ../../src/main.c:28

(gdb) print /x TIM2->SR
$1 = 0x1    <-- Bit 0 (UIF) remains asserted; hardware request line never clears!

(gdb) print TIM2->PSC
$2 = 35     <-- Prescaler is 35 (yields 2.0 MHz counter clock -> 2000 events/s)
```

### Step 4: Root Cause
Two distinct defects are present in `timer_gate.c`:
1. **Interrupt Flag Omission**: `TIM2_IRQHandler` toggles PA1 and increments tick, but omits clearing `TIM2->SR = ~TIM_SR_UIF;`. When the core executes exception return (`BX LR`), the NVIC observes the peripheral line still active and immediately re-enters the ISR, completely starving Thread mode.
2. **Timer Clock Prescaler Miscalculation**: The calculation `assumed_clk = timclk_hz / 2U;` assumes the timer clock is halved by the APB1 prescaler (/2). Per RM0008 Section 6.2, when APB1 prescaler != 1, the timer clock is multiplied by 2, restoring it to 72 MHz. Dividing by 36 MHz derived `PSC = 35`, doubling the update event rate from 1000 Hz to 2000 Hz.

### Step 5: Minimal Fix

In `gate/gate_fault_firmware/timer_gate.c`:

```diff
--- a/gate/gate_fault_firmware/timer_gate.c
+++ b/gate/gate_fault_firmware/timer_gate.c
@@ -10,8 +10,7 @@ void tim2_init_1khz(uint32_t timclk_hz)
 {
     RCC->APB1ENR |= RCC_APB1ENR_TIM2EN;
 
-    uint32_t assumed_clk = timclk_hz / 2U;
-    uint32_t psc_val = (assumed_clk / 1000000U) - 1U;
+    uint32_t psc_val = (timclk_hz / 1000000U) - 1U;
     uint32_t arr_val = 999U;
 
     TIM2->PSC = (uint16_t)psc_val;
@@ -28,6 +27,8 @@ void tim2_init_1khz(uint32_t timclk_hz)
 void TIM2_IRQHandler(void)
 {
     if (TIM2->SR & TIM_SR_UIF) {
+        TIM2->SR = ~TIM_SR_UIF;
+        __DSB();
         gpio_toggle_pa1_atomic();
         g_tim2_ticks++;
     }
```

### Step 6: Regression Verification
Recompile:
```bash
make -C gate/gate_fault_firmware clean all
```
1. Verify `TIM2->PSC` is `71`:
   $$\frac{72000000}{(71 + 1) \times (999 + 1)} = \frac{72000000}{72000} = 1000\text{ events/s}$$
   $$f_{\text{square\_wave}} = \frac{1000}{2} = 500\text{ Hz (2.0 ms period)}$$
2. Verify `main()` loop executes continuously without being locked in the ISR.
3. Run `make check` from module root to verify static checks.
