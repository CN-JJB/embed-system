#include "FreeRTOS.h"
#include "task.h"
#include "clock.h"
#include "gpio.h"

/*
 * NOTE: Defect in Fixture f3:
 * Task stack depth is configured to 16 words (64 bytes).
 * On Cortex-M3, the initial hardware + software exception frame alone requires
 * 16 words (64 bytes). The moment any function is called or an interrupt
 * occurs, the stack overflows immediately, corrupting adjacent heap structures.
 */
#define UNDERSIZED_STACK_DEPTH   16

static volatile uint32_t g_sink = 0;

static void vWorkerTask(void *pvParameters)
{
    (void)pvParameters;
    volatile uint32_t local_buffer[16];

    for (uint32_t i = 0; i < 16; i++) {
        local_buffer[i] = i * 2;
    }

    for (;;) {
        for (uint32_t i = 0; i < 16; i++) {
            g_sink += local_buffer[i];
        }
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

int main(void)
{
    clock_init(CLOCK_PROFILE_72MHZ_HSE);
    gpio_init();

    xTaskCreate(vWorkerTask, "Worker", UNDERSIZED_STACK_DEPTH, NULL, 1, NULL);

    vTaskStartScheduler();

    for (;;) {
        __asm volatile ("wfi");
    }
}
