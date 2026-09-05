# P2-M04 Socratic Hints & Pedagogical Guidance

## Challenge Hints (Dual-Task Scheduler & Context Integration)

### Level 1: Clock Coherence
- How does `configCPU_CLOCK_HZ` ensure a 1000 Hz SysTick downcounter period when the clock tree switches between 72 MHz HSE and 64 MHz HSI?
- What global CMSIS variable tracks the core frequency, and where should it be referenced?

### Level 2: Vector Table Integration
- How does the startup vector table link to FreeRTOS port handlers?
- Check `FreeRTOSConfig.h`: what `#define` statements map `vPortSVCHandler`, `xPortPendSVHandler`, and `xPortSysTickHandler` to `SVC_Handler`, `PendSV_Handler`, and `SysTick_Handler`?

### Level 3: Dual-Task Scheduling Dynamics
- If Task A has priority 2 (`tskIDLE_PRIORITY + 2`) and Task B has priority 1 (`tskIDLE_PRIORITY + 1`), how does Task B ever get CPU time?
- Why must Task A explicitly transition to the `Blocked` list using `vTaskDelay(pdMS_TO_TICKS(5))`? What does the scheduler do when Task A blocks?

## Gate Hints (Scheduler Lockup & Kernel Invariant)

### Level 1: Kernel Readiness Invariant
- Under what condition does FreeRTOS execute the Idle task?
- What fundamental invariant must always hold regarding the number of tasks in the Ready state?

### Level 2: Hook Function Execution Context
- Check `FreeRTOSConfig.h`: what hook functions are enabled (`configUSE_...`)?
- In which task's context does `vApplicationIdleHook()` execute?

### Level 3: Task State Transitions
- What state does a task transition to when it calls `vTaskDelay()`?
- If the Idle task is placed onto the Delayed list while all application tasks are also blocked, how many tasks remain in the Ready list?
- Look at `vTaskSwitchContext()`: what happens when `taskSELECT_HIGHEST_PRIORITY_TASK()` finds an empty ready list?
