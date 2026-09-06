# Lab 03: Upstream FreeRTOS Priority Inheritance Mechanics in `tasks.c`

## Objectives
- Trace the internal FreeRTOS kernel routines implementing priority inheritance.
- Understand the state transitions between `pxReadyTasksLists` during priority boosting and disinheritance.
- Inspect the role of `uxBasePriority` in restoring task priority.

## Upstream Kernel Code Walkthrough (`tasks.c`)

### 1. Priority Elevation: `xTaskPriorityInherit`

When a higher priority task blocks on a mutex held by a lower priority task, `xQueueSemaphoreTake()` calls:

```c
BaseType_t xTaskPriorityInherit( TaskHandle_t const pxMutexHolder )
{
    TCB_t * const pxTCB = pxMutexHolder;
    BaseType_t xReturn = pdFALSE;

    if( pxMutexHolder != NULL )
    {
        /* Check if the mutex holder's priority is lower than current task */
        if( pxTCB->uxPriority < pxCurrentTCB->uxPriority )
        {
            /* Adjust the priority in the event list if blocked on something else */
            if( ( listIS_CONTAINED_WITHIN( &( pxReadyTasksLists[ pxTCB->uxPriority ] ), &( pxTCB->xStateListItem ) ) != pdFALSE ) )
            {
                /* Remove from current ready list */
                if( uxListRemove( &( pxTCB->xStateListItem ) ) == ( UBaseType_t ) 0 )
                {
                    portRESET_READY_PRIORITY( pxTCB->uxPriority, uxTopReadyPriority );
                }

                /* Temporarily elevate priority */
                pxTCB->uxPriority = pxCurrentTCB->uxPriority;

                /* Insert into the higher priority ready list */
                prvAddTaskToReadyList( pxTCB );
            }
            else
            {
                /* Just update priority attribute if not in ready list */
                pxTCB->uxPriority = pxCurrentTCB->uxPriority;
            }

            xReturn = pdTRUE;
        }
    }
    return xReturn;
}
```

### 2. Priority Restoration: `xTaskPriorityDisinherit`

When `Task_Low` releases the mutex (`xSemaphoreGive`), `queue.c` calls `xTaskPriorityDisinherit()`:

```c
BaseType_t xTaskPriorityDisinherit( TaskHandle_t const pxMutexHolder )
{
    TCB_t * const pxTCB = pxMutexHolder;
    BaseType_t xReturn = pdFALSE;

    if( pxMutexHolder != NULL )
    {
        /* Check if the task's priority was actually boosted */
        if( pxTCB->uxPriority != pxTCB->uxBasePriority )
        {
            /* Remove from elevated ready list */
            if( uxListRemove( &( pxTCB->xStateListItem ) ) == ( UBaseType_t ) 0 )
            {
                portRESET_READY_PRIORITY( pxTCB->uxPriority, uxTopReadyPriority );
            }

            /* Restore original base priority */
            pxTCB->uxPriority = pxTCB->uxBasePriority;

            /* Return to original priority ready list */
            prvAddTaskToReadyList( pxTCB );

            xReturn = pdTRUE;
        }
    }
    return xReturn;
}
```

## Run B Execution Trace (Mutex with Priority Inheritance)

1. `Task_Low` (Prio 1, Base 1) acquires `xSharedLock` (created via `xSemaphoreCreateMutex()`).
2. `Task_Low` signals `Task_High`.
3. `Task_High` preempts Low and calls `xSemaphoreTake(xSharedLock)`.
4. High blocks. Kernel invokes `xTaskPriorityInherit(pxLowTCB)`.
5. Low's priority is boosted to **Priority 3** (`uxPriority = 3`, `uxBasePriority = 1`).
6. Low resumes execution.
7. Low signals `Task_Medium` (Priority 2).
8. `Task_Medium` becomes ready, BUT Priority 2 < Priority 3! **Medium CANNOT preempt Low!**
9. Low finishes its ~5 ms workload unhindered, calls `xSemaphoreGive()`.
10. In `xSemaphoreGive()`, Low's priority is restored to Priority 1 (`uxPriority = 1`).
11. High immediately wakes and preempts Low! High executes its critical section and completes within ~1 ms.
12. Finally, `Task_Medium` gets the CPU.

**Delay Experienced by Task High under Run B:**
$$T_{\text{delay}} \approx T_{\text{Low Workload}} \approx 5\text{ ms}$$
The 20 ms interference from `Task_Medium` has been completely eliminated!

## Review Questions
1. Does priority inheritance prevent nested inversions?
   *(Answer: Yes, FreeRTOS tracks chained inheritance if a task holding mutex A blocks on mutex B, transitively elevating mutex holders).*
2. Does priority inheritance prevent deadlock?
   *(Answer: No! If Task 1 holds M1 and requests M2 while Task 2 holds M2 and requests M1, priority inheritance will simply boost both tasks to the highest priority, but both remain deadlocked).*
