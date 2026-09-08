#include <stdint.h>
#include "stm32f103xb.h"
#include "system_stm32f1xx.h"
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "interrupt_config.h"

#define QUEUE_LENGTH    8
#define QUEUE_ITEM_SIZE sizeof(uint32_t)

static void worker_task(void *pvParameters)
{
    (void)pvParameters;
    uint32_t received_token = 0;

    while (1) {
        if (xQueueReceive(g_event_queue, &received_token, portMAX_DELAY) == pdPASS) {
            /* Process token */
            (void)received_token;
        }
    }
}

int main(void)
{
    /* Initialize clocks */
    SystemInit();
    SystemCoreClockUpdate();

    /* Create event queue */
    g_event_queue = xQueueCreate(QUEUE_LENGTH, QUEUE_ITEM_SIZE);
    configASSERT(g_event_queue != NULL);

    /* Create consumer worker task (Priority 3) */
    BaseType_t ret = xTaskCreate(
        worker_task,
        "Task_Worker",
        configMINIMAL_STACK_SIZE + 64,
        NULL,
        3,
        NULL
    );
    configASSERT(ret == pdPASS);

    /* Initialize external interrupt hardware */
    interrupt_config_init();

    /* Start FreeRTOS preemptive scheduler */
    vTaskStartScheduler();

    /* Trap if scheduler ever returns */
    while (1) {
        __NOP();
    }

    return 0;
}

void vAssertCalled(const char *pcFile, unsigned long ulLine)
{
    (void)pcFile;
    (void)ulLine;
    __disable_irq();
    while (1) {
        __NOP();
    }
}

void vApplicationMallocFailedHook(void)
{
    __disable_irq();
    while (1) {
        __NOP();
    }
}

void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName)
{
    (void)xTask;
    (void)pcTaskName;
    __disable_irq();
    while (1) {
        __NOP();
    }
}
