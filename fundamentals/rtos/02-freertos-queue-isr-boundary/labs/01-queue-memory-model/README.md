# Lab 01: FreeRTOS Queue Memory Architecture and Copy Semantics

## Objective
Analyze the internal structure of a FreeRTOS `Queue_t`, trace item storage allocation, understand copy-by-value semantics (`memcpy`), and contrast small fixed data structures with pointer-passing pipelines.

## Prerequisites
- P2-M04: Task creation, priority levels, and `heap_4.c` block allocation.
- Understanding of C pointers, storage duration, and object lifetimes (Phase 1 M01/M02).

## Estimated Time
- 45 minutes (MUST load).

## AI Mode
- **AI-Hint**: Socratic questions on queue internals and copy semantics.

## Architectural Principles

### 1. The `Queue_t` Internal Layout
In `vendor/freertos/queue.c`, a queue consists of a control header `Queue_t` followed immediately by contiguous storage:
```c
typedef struct QueueDefinition {
    int8_t *pcHead;           /* Points to the beginning of the queue storage area */
    int8_t *pcWriteTo;        /* Points to the next free byte in the storage area */
    union {
        QueuePointers_t xQueue;
        SemaphoreData_t xSemaphore;
    } u;
    List_t xTasksWaitingToSend;    /* Tasks blocked waiting to post to full queue */
    List_t xTasksWaitingToReceive; /* Tasks blocked waiting to read from empty queue */
    volatile UBaseType_t uxMessagesWaiting; /* Current items in queue */
    UBaseType_t uxLength;          /* Maximum items queue can hold */
    UBaseType_t uxItemSize;        /* Size of each item in bytes */
    ...
} xQUEUE;
```
When `xQueueCreate(uxQueueLength, uxItemSize)` is invoked:
1. It computes total RAM required: `sizeof(Queue_t) + (uxQueueLength * uxItemSize)`.
2. It requests a single contiguous memory block from `pvPortMalloc()`.
3. `pcHead` points to the start of the storage buffer; `pcWriteTo` advances by `uxItemSize` for every enqueued item.

### 2. Copy-by-Value vs Pointer Passing
- **Copy-by-Value**: For small items (e.g. `uint32_t`, timestamps, sensor measurements), data is copied into the queue buffer:
  ```c
  uint32_t sample = 0x12345678;
  xQueueSend(xQueue, &sample, 0);
  /* The memory location of 'sample' can immediately expire or be overwritten without affecting the queue */
  ```
- **Pointer Passing**: For large payloads (e.g. 128-byte ADC DMA buffers), copying the entire buffer incurs significant CPU and latency penalties. Instead, the pointer is enqueued:
  ```c
  uint16_t *p_buffer = get_filled_dma_buffer();
  xQueueSend(xQueue, &p_buffer, 0);
  ```
  **Critical Lifetime Warning**: The queue copies only the 4-byte pointer value. It does **not** manage buffer allocation, retention, or thread safety. Passing a pointer to stack-allocated memory (`uint16_t local_buf[128]`) will cause silent corruption as soon as the calling function returns.

## Lab Procedure
1. Inspect `src/queue_app.c` where `g_sample_queue` is allocated with `QUEUE_APP_LENGTH = 10` and `QUEUE_APP_ITEM_SIZE = sizeof(uint32_t)`.
2. Calculate the exact byte footprint allocated by `xQueueCreate(10, 4)`:
   - Header: ~76 bytes (depending on config options)
   - Buffer: $10 \times 4 = 40$ bytes
   - Total: ~116 to 128 bytes from `ucHeap`.
3. In GDB, set a breakpoint after `queue_app_init()`, inspect the `Queue_t` struct fields, and verify `uxLength == 10` and `uxItemSize == 4`.

> **Status**: Static structure VERIFIED; live GDB memory dump UNVERIFIED (Headless automated build).
