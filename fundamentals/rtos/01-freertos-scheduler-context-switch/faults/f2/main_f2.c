#include "FreeRTOS.h"
#include "task.h"
#include "clock.h"
#include "gpio.h"
#include "stm32f103xb.h"

static void vBlinkTask(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        GPIOC->ODR ^= GPIO_ODR_ODR13;
        /* Requested 1000 ms periodic interval */
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

int main(void)
{
    /* Explicitly engage 64 MHz HSI fallback profile */
    clock_init(CLOCK_PROFILE_64MHZ_HSI);
    gpio_init();

    xTaskCreate(vBlinkTask, "Blink", 128, NULL, 1, NULL);

    vTaskStartScheduler();

    for (;;) {
        __asm volatile ("wfi");
    }
}
