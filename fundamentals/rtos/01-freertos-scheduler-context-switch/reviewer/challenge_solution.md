# P2-M04 Challenge Solution: FreeRTOS Scheduler and Context Switch Integration Core

## Design Overview
The redesigned P2-M04 transfer challenge evaluates the core competency of microcontroller RTOS integration: establishing an end-to-end FreeRTOS scheduler runtime on bare-metal Arm Cortex-M3 (STM32F103) hardware under strict temporal, architectural, and memory contracts.

The learner integration is packaged as a **learner-owned 3-file integration bundle**:
- `scheduler_app.h`: Task parameters and function contract prototypes;
- `scheduler_app.c`: Clock tree initialization, dual-task creation with return code checking, non-busy `vTaskDelay()` blocking, and scheduler startup;
- `FreeRTOSConfig.h`: Complete kernel configuration owned by the learner, including exception vector remappings, dynamic `SystemCoreClock` coherence, lowest interrupt priority assignment, and `heap_4` dimensioning.

### 1. Clock Integration & Dynamic Coherence
- Initializes system clock with requested profile (72 MHz HSE primary), falling back to 64 MHz HSI if HSE fails.
- `configCPU_CLOCK_HZ` dynamically tracks `SystemCoreClock`, ensuring exact 1000 Hz SysTick reload calculation (71,999 at 72 MHz; 63,999 at 64 MHz) across clock transitions.

### 2. Exception Vector Remapping & Kernel Priority
- Learner config maps port handlers:
  - `vPortSVCHandler -> SVC_Handler`
  - `xPortPendSVHandler -> PendSV_Handler`
  - `xPortSysTickHandler -> SysTick_Handler`
- Vector table entries 11 (SVCall), 14 (PendSV), and 15 (SysTick) resolve to FreeRTOS port implementations rather than `Default_Handler`.
- Upstream pinned ARM_CM3 port contract: `port.c` internally hardcodes `portMIN_INTERRUPT_PRIORITY = 255UL` and configures PendSV and SysTick via SHPR3 directly in `xPortStartScheduler()`. On STM32F103 (4-bit implemented priority), writing 255 sets the implemented upper 4 bits to `0xF0` (logical 15, lowest preemption urgency).

### 3. Dual-Task Priority & State Transitions
- Task A: Priority 2 (`tskIDLE_PRIORITY + 2`), stack $\ge 128\text{ words}$. Toggles PA1 and yields CPU to lower-priority tasks by transitioning to `Blocked` state via `vTaskDelay(pdMS_TO_TICKS(5))`.
- Task B: Priority 1 (`tskIDLE_PRIORITY + 1`), stack $\ge 128\text{ words}$. Toggles PA2 and executes compute loop while Task A is blocked.
- Return codes from `xTaskCreate()` are strictly validated against `pdPASS`.
- Kernel is launched via `vTaskStartScheduler()`.

### 4. Memory and Context Isolation
- Exclusive use of `heap_4` (`ucHeap` 10 KB). Complete absence of standard C library dynamic memory allocators (`malloc/calloc/realloc/free`).
- PendSV disassembly proves correct `mrs r0, psp`, `stmdb r0!, {r4-r11}`, `vTaskSwitchContext`, `ldmia r0!, {r4-r11}`, `msr psp, r0` sequence.
- SVC disassembly proves initial PSP setup for first task execution.

---

## Verification & Mutation Regression
The student validator (`challenge/validate.sh`) tests 14 distinct static, architectural, binary, and compilation contracts against the learner bundle.
The automated regression harness (`reviewer/test_m04_validator_mutations.sh`) proves validator rigor:
1. **Positive Control**: `reviewer/challenge-reference/` bundle -> **MUST PASS**.
2. **Negative Mutations** (13 mutation bundle families) -> **ALL MUST BE REJECTED**:
   - `mut1_broken_vectors`: learner config omits port handler remapping;
   - `mut2_inverted_priority`: Task A has lower priority than Task B;
   - `mut3_task_never_delays`: Task A never blocks, starving Task B;
   - `mut4_scheduler_not_started`: `vTaskStartScheduler()` omitted;
   - `mut5_libc_malloc_used`: calls prohibited standard libc `malloc()`;
   - `mut6_fixed_clock_hz`: hardcoded 72 MHz static clock instead of dynamic `SystemCoreClock`;
   - `mut7_wrong_tick_rate`: tick rate set to 100 Hz instead of 1000 Hz;
   - `mut8_invalid_heap_contract`: `configTOTAL_HEAP_SIZE` set to 512 B (insufficient for dual tasks + idle task);
   - `mut9_unchecked_task_create`: return code of `xTaskCreate` ignored;
   - `mut10_todo_unimplemented`: uncompleted TODO annotations remaining in bundle;
   - `mut_no_task_creation`: defines tasks and decoy pdPASS but omits `xTaskCreate` calls;
   - `mut_undersized_stack_contract`: sets `TASK_STACK_SIZE_WORDS` to 64 words in header;
   - `mut_decoy_delay`: places `vTaskDelay()` in an unused helper while actual `prvTaskA` never blocks.
