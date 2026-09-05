#include "FreeRTOS.h"
#include "task.h"
#include "clock.h"
#include "gpio.h"

static void vGateTask(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

void vApplicationIdleHook(void)
{
    vTaskDelay(pdMS_TO_TICKS(10));
}

int main(void)
{
    clock_init(CLOCK_PROFILE_72MHZ_HSE);
    gpio_init();

    xTaskCreate(vGateTask, "GateTask", 128, NULL, 1, NULL);

    vTaskStartScheduler();

    for (;;) {
        __asm volatile ("wfi");
    }
}
