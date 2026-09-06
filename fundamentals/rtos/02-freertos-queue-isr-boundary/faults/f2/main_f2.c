#include "clock.h"
#include "gpio.h"
#include "timer.h"
#include "queue_app.h"
#include "FreeRTOS.h"
#include "task.h"
#include "core_cm3.h"

int main(void)
{
    clock_init(CLOCK_PROFILE_72MHZ_HSE);
    gpio_init();

    /* Priority Grouping defect: setting group 5 configures 2 bits of subpriority,
     * violating the ARM_CM3 port expectation that all priority bits are pre-emption bits.
     * vPortValidateInterruptPriority() will fail the AIRCR group assertion.
     */
    NVIC_SetPriorityGrouping(5);

    queue_app_init();

    timer2_init(100);
    timer2_start();

    vTaskStartScheduler();

    while (1) {
        __NOP();
    }

    return 0;
}
