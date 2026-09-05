# P2-M06 Challenge: Priority Inversion, Inheritance, Stack Watermark & Watchdog

## Overview
In this challenge, you will implement the deterministic priority inversion and inheritance experiment harness, the stack watermark monitoring system, and the direct-register STM32F103 Independent Watchdog (IWDG) subsystem under FreeRTOS V11.3.0.

Your submission must satisfy:
1. **FreeRTOS Configuration (`FreeRTOSConfig.h`)**:
   - Enable `configUSE_MUTEXES = 1`.
   - Enable `configCHECK_FOR_STACK_OVERFLOW = 2` (Method 2 Canary verification).
   - Configure Cortex-M3 interrupt priority groupings and syscall boundaries.
2. **Independent Watchdog Subsystem (`iwdg.c`, `iwdg.h`)**:
   - Configure `IWDG->PR` and `IWDG->RLR` with bounded status register polling (`PVU`, `RVU`).
   - Implement `iwdg_init()`, `iwdg_refresh()`, `iwdg_was_reset_caused_by_watchdog()`, and `iwdg_clear_reset_flags()`.
   - Direct CMSIS register access; no vendor HAL.
3. **Priority Inversion & Inheritance Harness (`inversion_app.c`, `inversion_app.h`)**:
   - 3-task deterministic model: Task High (Prio 3), Task Medium (Prio 2), Task Low (Prio 1).
   - Run A: Binary semaphore control showing bounded priority inversion (**DESIGN TARGET / UNVERIFIED**: ~25 ms High wait on target).
   - Run B: Mutex control showing priority inheritance (**DESIGN TARGET / UNVERIFIED**: ~5 ms High wait on target).
   - Zero `vTaskDelay()` calls while holding the shared lock during workload execution.
   - Stack watermark conversion from words to bytes (`words * sizeof(StackType_t)`).

## Starter Code
Starter templates with structured `TODO` prompts are located in `starter/`:
- `starter/FreeRTOSConfig.h`
- `starter/inversion_app.h`
- `starter/inversion_app.c`
- `starter/iwdg.h`
- `starter/iwdg.c`

## Validation
To validate your solution:
```bash
./validate.sh starter/
```
Or run the verification runner:
```bash
./verify_challenge.sh
```
All static architectural rules, AST checks, compilation checks, symbol audits, and disassembly verifications must pass.
