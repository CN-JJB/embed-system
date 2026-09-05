# P2-M05 Challenge Solution & Architectural Rationale

## Core Implementation Details

The challenge requires the student to connect a hardware timer interrupt (`TIM2_IRQHandler`) to a consumer task (`Task_Consumer`) via a FreeRTOS queue under strict Cortex-M3 priority and API constraints.

### 1. `FreeRTOSConfig.h` Interrupt Priority Setup
```c
#define configPRIO_BITS                              4
#define configLIBRARY_LOWEST_INTERRUPT_PRIORITY      15
#define configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY 5

#define configKERNEL_INTERRUPT_PRIORITY         (configLIBRARY_LOWEST_INTERRUPT_PRIORITY << (8 - configPRIO_BITS))
#define configMAX_SYSCALL_INTERRUPT_PRIORITY    (configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY << (8 - configPRIO_BITS))
```
**Rationale**:
On STM32F103, 4 priority bits are implemented in bits [7:4] of each NVIC priority register byte. Setting `configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY = 5` means that logical priority 5 corresponds to byte value `0x50`. The kernel masks interrupts at or below this priority level when entering critical sections.

### 2. Cortex-M3 Priority Grouping
```c
NVIC_SetPriorityGrouping(0);
```
**Rationale**:
Setting priority grouping to 0 assigns all 4 implemented bits as preemption priority bits. If this is omitted or configured with subpriority bits, `vPortValidateInterruptPriority()` detects that the AIRCR priority grouping does not match the maximum allowed preemption bits and asserts.

### 3. Queue Creation and Blocking Receive
```c
g_sample_queue = xQueueCreate(10, sizeof(uint32_t));
configASSERT(g_sample_queue != NULL);

xTaskCreate(prvConsumerTask, "Consumer", 256, NULL, 3, NULL);
```
Inside `prvConsumerTask()`:
```c
xQueueReceive(g_sample_queue, &rx_val, portMAX_DELAY);
```
**Rationale**:
`portMAX_DELAY` blocks the task indefinitely until data arrives, allowing the CPU to execute lower-priority tasks or idle (`__WFI`). Priority 3 ensures that when the ISR enqueues an item, the unblocked task has higher priority than the currently running task, triggering preemption.

### 4. Interrupt Handler and Deferred Context Switch
```c
void TIM2_IRQHandler(void)
{
    if ((TIM2->SR & TIM_SR_UIF) != 0) {
        TIM2->SR = (uint16_t)(~TIM_SR_UIF);
        __DSB();

        gpio_toggle_pa1();

        static uint32_t s_seq = 0;
        s_seq++;

        BaseType_t xHigherPriorityTaskWoken = pdFALSE;

        if (g_sample_queue != NULL) {
            BaseType_t xResult = xQueueSendFromISR(g_sample_queue, (const void *)&s_seq, &xHigherPriorityTaskWoken);
            if (xResult == pdPASS) {
                g_isr_sent_count++;
            } else {
                g_isr_dropped_count++;
            }
        }

        portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
    }
}
```
**Rationale**:
- `xQueueSendFromISR()` is non-blocking.
- `xHigherPriorityTaskWoken` is initialized to `pdFALSE`. When `xTaskRemoveFromEventList()` unblocks `Task_Consumer` (prio 3), it detects `unblocked_prio > current_prio` and sets `*pxHigherPriorityTaskWoken = pdTRUE`.
- `portYIELD_FROM_ISR(xHigherPriorityTaskWoken)` sets bit 28 (`PENDSVSET`) in `SCB->ICSR`. As soon as `TIM2_IRQHandler` returns, the CPU tail-chains into `PendSV_Handler` and performs the context switch.
