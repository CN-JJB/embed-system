# Part C: FreeRTOS Scheduling & Context Switch Mechanics

> **Time Budget:** 50 minutes  
> **Weight:** 25 points (Floor: 60% / $\ge 15.0$ points)  
> **Mode:** AI-Free (Strict)  

---

## 1. System Context & Observed Symptom

You are auditing an unfamiliar FreeRTOS V11.3.0 real-time firmware package on the STM32F103C8T6.
The system features:
* Preemptive multitasking with FreeRTOS kernel memory management and syscall boundary protection enabled.
* Assembly context switching via `xPortPendSVHandler` on the Cortex-M3.
* External event signaling via `EXTI0_IRQHandler` posting event tokens to a worker task queue using `xQueueSendFromISR()`.

The firmware compiles cleanly with zero warnings (`-Wall -Wextra -Werror`).
However, during execution under real-time event traffic, the system abruptly halts inside an unrecoverable FreeRTOS kernel assertion trap during interrupt service execution.

---

## 2. Deliverables & Investigation Tasks

1. **Context Switch Stack Frame Derivation:**
   Inspect the pre-recorded GDB trace fixture in `fixtures/pendsv_gdb_trace.txt` (labeled `SEEDED FIXTURE / ASSESSMENT INPUT`).
   - Identify active stack pointers: Which stack pointer (MSP vs PSP) is active in Handler mode? Which in Thread mode?
   - Derive the exact memory addresses and contents of the 8-word hardware-pushed exception frame (`r0-r3, r12, lr, pc, xpsr`) on the PSP using the ARMv7-M Architecture Manual (DDI 0403E.e Section B1.5).
   - Trace the software stack push executed by `xPortPendSVHandler` (`stmdb r0!, {r4-r11}`). Calculate the resulting value of `pxCurrentTCB->pxTopOfStack`.
   - Explain the architectural meaning of the exception return code `0xFFFFFFFD`.
2. **Interrupt Priority & Kernel Boundary Audit:**
   Inspect `src/interrupt_config.c`, `include/FreeRTOSConfig.h`, and the raw NVIC register readback in `fixtures/pendsv_gdb_trace.txt`:
   - Determine how the interrupt priority for EXTI0 was configured in software.
   - Decode how this value maps to the physical Cortex-M3 NVIC priority byte (`NVIC->IP[EXTI0_IRQn]`) under ST PM0056 Section 4.3.
   - Audit the configured priority against the FreeRTOS maximum syscall interrupt priority threshold.
   - Explain why this configuration triggers the kernel assertion trap when calling `FromISR` API functions.
3. **Observation, Interpretation & Non-Proof:**
   Provide a disciplined analysis of what the register and stack evidence proves and does not prove.
4. **Minimal Principled Correction:**
   Apply the minimal correction to `src/interrupt_config.c` to assign an NVIC priority that satisfies the FreeRTOS ISR-safe API boundary.
5. **Verify Artifact & Build Integrity:**
   Rebuild the firmware and run `make check` to confirm valid compilation, symbol exports, and artifact generation. (Note: `make check` validates generic artifact integrity; technical evaluation of the interrupt priority contract is performed by reviewer-isolated testing).

---

## 3. Investigation Protocol

1. Build the seeded fixture:
   ```bash
   make clean && make
   ```
2. Run `make check` to verify initial build integrity:
   ```bash
   make check
   ```
3. Inspect `fixtures/pendsv_gdb_trace.txt` and compare against ST PM0056 Section 4.3 (NVIC) and FreeRTOS `FreeRTOSConfig.h`.
4. Record your answers and derivations in Section 6 of `../SUBMISSION_TEMPLATE.md`.
5. Apply the minimal fix in `src/interrupt_config.c` and verify build integrity with `make check`.
