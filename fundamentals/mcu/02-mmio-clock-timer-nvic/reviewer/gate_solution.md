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
The Gate firmware in `gate/gate_fault_firmware/` compiles cleanly with zero warnings, but upon flashing to hardware (or running under GDB):
1. The CPU enters an infinite loop inside `TIM2_IRQHandler`; the main thread loop in `main()` never makes forward progress.
2. An oscilloscope probe on PA1 shows that before lockup, the interrupt toggles at 2.0 kHz (500 us period) instead of the expected 1.0 kHz.

### Step 2: Hypotheses
1. **Clock prescaler math error**: The timer prescaler `TIM2->PSC` was calculated using an assumed 36 MHz clock instead of the doubled 72 MHz timer clock on APB1.
2. **Interrupt storm**: The peripheral interrupt flag in `TIM2->SR` is not cleared inside `TIM2_IRQHandler`, or is cleared without a memory synchronization barrier (`__DSB()`).
3. **NVIC priority conflict**: `TIM2` priority was configured with an unshifted priority value, causing it to block all Thread mode execution.
4. **Flash wait state failure**: Flash latency was left at 0 WS, causing instruction prefetch corruptions.

### Step 3: Evidence Collection
Connect GDB to the target:
```bash
arm-none-eabi-gdb gate/gate_fault_firmware/build/firmware.elf
```
GDB commands:
```gdb
(gdb) target remote localhost:3333
(gdb) monitor reset halt
(gdb) continue
^C
(gdb) backtrace
#0  TIM2_IRQHandler () at timer_gate.c:30
#1  <signal handler called>
#2  main () at ../../src/main.c:28

(gdb) print /x TIM2->SR
$1 = 0x1    <-- Bit 0 (UIF) is STILL SET! Hardware interrupt request line never deasserted!

(gdb) print TIM2->PSC
$2 = 35     <-- PSC is 35! (72 MHz / 36 = 2 MHz counter clock -> 2 kHz update rate)
```

### Step 4: Root Cause
Two interrelated defects are present in `timer_gate.c`:
1. **Interrupt Flag Omission**: `TIM2_IRQHandler` toggles PA1 and increments tick, but completely omits clearing `TIM2->SR = ~TIM_SR_UIF;`. When the core executes exception return (`BX LR`), the NVIC sees the peripheral line still active and immediately re-enters the ISR.
2. **Timer Clock Prescaler Miscalculation**: The calculation `assumed_clk = timclk_hz / 2U;` assumes the timer clock is halved by the APB1 prescaler (/2). Per RM0008 Section 6.2, when APB1 prescaler != 1, the timer clock is multiplied by 2, restoring it to 72 MHz. Dividing by 36 MHz derived `PSC = 35`, doubling the interrupt frequency.

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
1. Verify `TIM2->PSC` is `71` in GDB:
   $$\frac{72000000}{(71 + 1) \times (999 + 1)} = \frac{72000000}{72000} = 1000\text{ Hz}$$
2. Verify `main()` loop executes continuously without being locked in the ISR.
3. Run `make check` from module root to verify static checks.
