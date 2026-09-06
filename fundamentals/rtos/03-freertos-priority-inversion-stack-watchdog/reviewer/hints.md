# P2-M06 Socratic Hint Ladder

> For guidance during labs, faults, and challenge without revealing code.

---

## Lab 01 & 02: Mutex vs Binary Semaphore & Priority Inversion
- **Hint 1**: Does a binary semaphore record which task took it? Where in the TCB or queue structure is that information stored?
- **Hint 2**: If Task High blocks on a resource held by Task Low, how can the scheduler help Task Low finish faster if the scheduler doesn't know who holds the resource?
- **Hint 3**: When simulating a workload in a real-time experiment, what is the critical difference between burning CPU cycles in a loop versus calling `vTaskDelay()`?

---

## Lab 03: Priority Inheritance Mechanics
- **Hint 1**: What happens to `pxTCB->uxPriority` when `xTaskPriorityInherit()` runs? Where is the task's original priority saved?
- **Hint 2**: If Task Low is elevated to Priority 3, can Task Medium (Priority 2) preempt it when Task Medium unblocks?
- **Hint 3**: When Task Low gives back the mutex, how does the kernel restore its original priority?

---

## Lab 04 & 05: Stack Watermarks & Overflow Checks
- **Hint 1**: What pattern does FreeRTOS write to a task's stack when the task is created?
- **Hint 2**: `uxTaskGetStackHighWaterMark()` returns a number. What are the units of that number? If it returns 32 on a 32-bit Cortex-M3 processor, how many bytes of headroom remain?
- **Hint 3**: How does `configCHECK_FOR_STACK_OVERFLOW = 2` differ from `= 1`? What does Method 2 check that Method 1 misses?

---

## Lab 06 & 07: Watchdog & System Recovery
- **Hint 1**: Why does STM32F103 RM0008 require writing `0x5555` before writing to `IWDG->PR` or `IWDG->RLR`?
- **Hint 2**: What status bits in `IWDG->SR` must be 0 before modifying prescaler or reload values? Why must this wait have a timeout?
- **Hint 3**: If you refresh the watchdog from a hardware timer ISR, will the watchdog detect when all your tasks are deadlocked?
