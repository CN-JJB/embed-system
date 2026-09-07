# Part C: FreeRTOS Scheduling & Context Switch Mechanics

> **Time Budget:** 50 minutes  
> **Weight:** 25 points (Floor: 60% / $\ge 15.0$ points)  
> **Mode:** AI-Free (Strict)  

---

## 1. System Context & Observed Symptom

You are auditing an unfamiliar FreeRTOS V11.3.0 real-time system on the STM32F103C8T6.
The system features:
* Preemptive multitasking with `configMAX_SYSCALL_INTERRUPT_PRIORITY = 0x50` (CMSIS logical priority 5).
* Assembly context switching via `xPortPendSVHandler` on the Cortex-M3.
* External sensor event capture via `EXTI0_IRQHandler` posting event tokens to a worker task queue using `xQueueSendFromISR()`.

The firmware compiles cleanly with zero warnings.
However, under integration testing on hardware with FreeRTOS assertion checks enabled (`configASSERT` active), the system periodically halts inside `vPortValidateInterruptPriority()` immediately when an external event occurs:
```text
/* In FreeRTOS portable/GCC/ARM_CM3/port.c */
configASSERT( ucCurrentPriority >= ucMaxSysCallPriority );
```

---

## 2. Deliverables & Investigation Tasks

1. **Context Switch Stack Frame Derivation:**
   Inspect the pre-recorded GDB trace fixture in `fixtures/pendsv_gdb_trace.txt` (labeled `SEEDED FIXTURE / ASSESSMENT INPUT`).
   - Identify active stack pointers: Which stack pointer (MSP vs PSP) is active in Handler mode? Which in Thread mode?
   - Derive the exact memory addresses and contents of the 8-word hardware-pushed exception frame (`r0-r3, r12, lr, pc, xpsr`) on the PSP.
   - Trace the software stack push executed by `xPortPendSVHandler` (`stmdb r0!, {r4-r11}`). Calculate the resulting value of `pxCurrentTCB->pxTopOfStack`.
   - Explain the architectural meaning of the exception return code `0xFFFFFFFD`.
2. **NVIC Priority vs BASEPRI Safety Audit:**
   Inspect `src/interrupt_config.c` and `fixtures/pendsv_gdb_trace.txt`:
   - Determine the numerical priority argument passed to `NVIC_SetPriority(EXTI0_IRQn, ...)`.
   - Calculate how this logical priority is encoded into the Cortex-M3 NVIC hardware register byte (`NVIC->IP[EXTI0_IRQn]`).
   - Explain why this priority setting violates the `configMAX_SYSCALL_INTERRUPT_PRIORITY` threshold and why `BASEPRI` fails to protect FreeRTOS critical sections when this ISR executes.
3. **Observation, Interpretation & Non-Proof:**
   Provide a disciplined analysis of what the register and stack evidence proves and does not prove.
4. **Minimal Principled Correction:**
   Apply the minimal correction to `src/interrupt_config.c` to assign an NVIC priority that satisfies the FreeRTOS ISR-safe API boundary.
5. **Regression Verification:**
   Run `make check` to verify that the interrupt priority contract is satisfied.

---

## 3. Investigation Protocol

1. Build the seeded fixture:
   ```bash
   make clean && make
   ```
2. Run `make check` to observe the automated priority contract failure:
   ```bash
   make check
   ```
3. Inspect `fixtures/pendsv_gdb_trace.txt` and compare against ST PM0056 Section 4.3 (NVIC) and FreeRTOS `FreeRTOSConfig.h`.
4. Record your answers and derivations in Section 6 of `../SUBMISSION_TEMPLATE.md`.
5. Apply the minimal fix in `src/interrupt_config.c` and verify with `make check`.
