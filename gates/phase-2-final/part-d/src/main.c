#include <stdint.h>
#include "stm32f103xb.h"
#include "system_stm32f1xx.h"
#include "FreeRTOS.h"
#include "task.h"
#include "node_app.h"

int main(void)
{
    /* Initialize system clocks */
    SystemInit();
    SystemCoreClockUpdate();

    /* Initialize node application tasks and watchdog */
    node_app_init();

    /* Start FreeRTOS scheduler */
    vTaskStartScheduler();

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
