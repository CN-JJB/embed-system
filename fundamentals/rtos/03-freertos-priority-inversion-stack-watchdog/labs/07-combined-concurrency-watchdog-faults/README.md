# Lab 07: Combined Concurrency and Watchdog Fault Topology

## Objectives
- Analyze systemic failure cascades where concurrency hazards (priority inversion, deadlock) trigger hardware watchdog resets.
- Establish an architectural pattern for multi-task health auditing.
- Avoid the fatal anti-pattern of refreshing the watchdog from an unmonitored task or timer ISR.

## The Fatal Anti-Pattern: Unmonitored Watchdog Refresh

Consider this naive implementation:
```c
/* FATAL ANTI-PATTERN */
void vTimerISR(void) {
    iwdg_refresh(); /* Refreshes watchdog every 10 ms from hardware timer! */
}
```
**Why this is catastrophic:**
If `Task_High` enters an infinite loop, or if `Task_High` and `Task_Low` become permanently deadlocked, the hardware timer ISR continues to fire and refresh the watchdog! The hardware watchdog will never trigger a reset, and the physical embedded system remains locked up indefinitely while appearing "alive" to the watchdog.

## Coordinated Health Monitoring Pattern

In a robust RTOS architecture:
1. Every critical task maintains a heartbeat counter or timestamp.
2. A single `Task_Health` (running at the lowest active priority or periodic supervisory priority) audits:
   - Whether each monitored task has advanced its heartbeat counter within its allowable deadline.
   - Whether each monitored task's stack watermark has dropped below safety limits (`uxTaskGetStackHighWaterMark() * 4 < THRESHOLD`).
3. Only if **ALL** checks pass does `Task_Health` call `iwdg_refresh()`.
4. If a lower-priority task is starved due to priority inversion, or if any task deadlocks, its heartbeat stops updating. `Task_Health` refuses to refresh the IWDG, allowing the hardware down-counter to expire and safely reset the MCU into a known recovery state.

## Review Questions
1. If `Task_Health` runs at Priority 1, what happens during unbounded priority inversion where Medium runs forever?
   *(Answer: Task_Health is starved, the watchdog expires, and the system resets, terminating the hung state).*
2. What diagnostic information should be saved before a watchdog reset?
   *(Answer: In production systems, non-volatile backup registers (RTC BKP) or flash log sectors are used to record task IDs, program counters, and stack watermarks before reset).*
