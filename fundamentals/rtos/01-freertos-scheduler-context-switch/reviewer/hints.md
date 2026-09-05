# P2-M04 Socratic Hints & Pedagogical Guidance

## Challenge Hints (Dual-Task Scheduler & Telemetry)

### Level 1: Conceptual Understanding
- Why does a periodic sensor task using `vTaskDelay()` gradually drift over time if another task preempts it?
- Look up `vTaskDelayUntil()`. What is the significance of the first parameter `pxPreviousWakeTime`?

### Level 2: Memory & Thread Safety
- The telemetry structure is written by the Telemetry task and read by `app_tasks_get_telemetry()`. What prevents a context switch from occurring halfway through copying a 32-bit field?
- FreeRTOS provides `taskENTER_CRITICAL()` and `taskEXIT_CRITICAL()`. What Cortex-M register do these macros manipulate?

### Level 3: Stack Headroom
- How does `uxTaskGetStackHighWaterMark()` determine how much unused stack remains?
- If `TASK_STACK_SIZE_WORDS` is 128, how many bytes of RAM are allocated for the task stack?

---

## Gate Hints (NVIC Priority Masking Defect)

### Level 1: Symptoms & Scope
- Disassemble `PendSV_Handler` using `arm-none-eabi-objdump -d build/firmware.elf`. Look at the instruction setting `BASEPRI` right before calling `vTaskSwitchContext()`.
- What value is being loaded into `r0` before `msr BASEPRI, r0`?

### Level 2: Architectural Details
- Read STM32F103 Reference Manual (RM0008) section on NVIC priority registers and Cortex-M3 Technical Reference Manual on `BASEPRI`.
- How many priority bits are physically implemented on STM32F103 (`__NVIC_PRIO_BITS`)?
- Which bit positions in an 8-bit priority byte do these implemented bits occupy?

### Level 3: The Calculation
- If you write the binary value `0b00000101` (5) to a register whose lower 4 bits are hardwired to zero, what is the resulting value inside the register?
- How should `configMAX_SYSCALL_INTERRUPT_PRIORITY` be defined to ensure the priority level 5 is shifted into bits [7:4]?
