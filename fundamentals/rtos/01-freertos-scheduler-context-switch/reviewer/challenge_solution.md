# P2-M04 Challenge Solution: FreeRTOS Scheduler and Context Switch Integration Core

## Design Overview
The redesigned P2-M04 transfer challenge evaluates the core competency of microcontroller RTOS integration: establishing an end-to-end FreeRTOS scheduler runtime on bare-metal Arm Cortex-M3 (STM32F103) hardware under strict temporal, architectural, and memory contracts.

The learner integration completes `scheduler_app_init_and_start(clock_profile_t profile)`:
1. **Clock Integration & Dynamic Coherence**:
   - Initializes system clock with requested profile (72 MHz HSE primary), falling back to 64 MHz HSI if HSE fails.
   - `configCPU_CLOCK_HZ` dynamically tracks `SystemCoreClock`, ensuring exact 1000 Hz SysTick operation across clock transitions.
2. **Vector Table Integration**:
   - Vector table entries 11 (SVCall), 14 (PendSV), and 15 (SysTick) resolve to FreeRTOS port implementations (`SVC_Handler`, `PendSV_Handler`, `SysTick_Handler`) rather than `Default_Handler`.
3. **Dual-Task Priority & State Transitions**:
   - Task_A: Priority 2 (`tskIDLE_PRIORITY + 2`), stack $\ge 128\text{ words}$. Toggles PA1 and yields CPU to lower-priority tasks by transitioning to `Blocked` state via `vTaskDelay(pdMS_TO_TICKS(5))`.
   - Task_B: Priority 1 (`tskIDLE_PRIORITY + 1`), stack $\ge 128\text{ words}$. Toggles PA2 and executes compute loop while Task_A is blocked.
   - Return codes from `xTaskCreate()` are strictly validated.
4. **Scheduler Startup**:
   - Launches kernel via `vTaskStartScheduler()`.
5. **Memory and Context Isolation**:
   - Exclusive use of `heap_4` (`ucHeap` 10 KB). Complete absence of standard C library dynamic memory allocators (`malloc/calloc/realloc/free`).
   - PendSV disassembly proves correct `mrs r0, psp`, `stmdb r0!, {r4-r11}`, `vTaskSwitchContext`, `ldmia r0!, {r4-r11}`, `msr psp, r0` sequence.

## Verification & Mutation Regression
The student validator (`challenge/validate.sh`) tests 14 distinct static, architectural, and compilation contracts.
The automated regression harness (`reviewer/test_m04_validator_mutations.sh`) proves validator rigor:
1. **Positive Control**: `reviewer/challenge-reference/scheduler_app.c` -> **MUST PASS**.
2. **Negative Mutations** (8 mutation families) -> **ALL MUST BE REJECTED**:
   - `mut1_broken_vectors`: dummy handler breaks vector table mapping.
   - `mut2_inverted_priority`: Task A has lower priority than Task B.
   - `mut3_task_never_delays`: Task A never blocks, starving Task B.
   - `mut4_scheduler_not_started`: `vTaskStartScheduler()` omitted.
   - `mut5_libc_malloc_used`: calls prohibited standard libc `malloc()`.
   - `mut6_undersized_stack`: stack size set to 64 words (< 128 words).
   - `mut7_unchecked_task_create`: return code of `xTaskCreate` ignored.
   - `mut8_todo_unimplemented`: uncompleted TODO stub remaining.
