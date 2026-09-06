# Lab 01: Mutex vs Binary Semaphore Mechanics in FreeRTOS

## Objectives
- Inspect the internal structural differences between a FreeRTOS Mutex and a Binary Semaphore.
- Examine how `queue.c` distinguishes synchronization primitives using `ucQueueType`.
- Understand why binary semaphores cannot provide priority inheritance or ownership tracking.

## Architectural Deep Dive

In FreeRTOS V11.3.0, both semaphores and mutexes are implemented as queues under the hood, but with critical structural distinctions:

```c
/* Upstream queue.c definitions */
#define queueQUEUE_TYPE_BASE                  ( ( uint8_t ) 0U )
#define queueQUEUE_TYPE_MUTEX                 ( ( uint8_t ) 1U )
#define queueQUEUE_TYPE_COUNTING_SEMAPHORE    ( ( uint8_t ) 2U )
#define queueQUEUE_TYPE_BINARY_SEMAPHORE      ( ( uint8_t ) 3U )
#define queueQUEUE_TYPE_RECURSIVE_MUTEX       ( ( uint8_t ) 4U )
```

### 1. Ownership & `pxMutexHolder`
When a mutex is created with `xSemaphoreCreateMutex()`:
1. FreeRTOS creates a queue of length 1 and item size 0.
2. It initializes `pxQueue->u.xSemaphore.xMutexHolder = NULL`.
3. It gives the mutex initially (queue count = 1), so the first `xSemaphoreTake` succeeds.
4. When taken, `pxQueue->u.xSemaphore.xMutexHolder` records the `TaskHandle_t` of the taking task.
5. In contrast, a binary semaphore created with `xSemaphoreCreateBinary()`:
   - Is created empty (queue count = 0).
   - Does **NOT** record ownership (`pxMutexHolder` is not tracked).
   - Can be taken by Task A and given by Task B or an ISR (unidirectional signaling).

### 2. Why Binary Semaphores Cannot Do Priority Inheritance
Priority inheritance requires the kernel to know *which specific task* holds the contested resource so that its priority can be elevated. Because binary semaphores represent anonymous events without an owner, the kernel cannot determine whose priority to boost when a high-priority task blocks.

## Hands-on Inspection with GDB

Set breakpoints in `xQueueCreateMutex` and `xQueueCreateBinary`:
```gdb
(gdb) break xQueueCreateMutex
(gdb) break xQueueGenericCreate
(gdb) continue
```

Observe queue initialization:
```gdb
(gdb) print pxNewQueue->ucQueueType
$1 = 1 (queueQUEUE_TYPE_MUTEX)
(gdb) print pxNewQueue->u.xSemaphore.xMutexHolder
$2 = 0x0
```

## Review Questions
1. What happens if Task A takes a mutex and Task B attempts to `xSemaphoreGive` that mutex?
   *(Answer: In FreeRTOS, giving a mutex not held by the current task violates mutex ownership and asserts in debug builds).*
2. Why is `xSemaphoreTakeFromISR` prohibited on mutexes?
   *(Answer: Mutexes involve task ownership, priority inheritance, and potential blocking, none of which exist or are valid within an interrupt service routine).*
