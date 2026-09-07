#include "interrupt_config.h"
#include "stm32f103xb.h"
#include "core_cm3.h"

QueueHandle_t g_event_queue = NULL;

void interrupt_config_init(void)
{
    /*
     * Reference fix: EXTI0 calls FreeRTOS FromISR APIs (xQueueSendFromISR).
     * In Cortex-M3, interrupt numerical priority must be logically >= 5
     * (hardware byte >= 0x50, configMAX_SYSCALL_INTERRUPT_PRIORITY).
     * Setting logical priority 6 (hardware byte 0x60 = 96) satisfies the syscall boundary.
     */
    NVIC_SetPriority(EXTI0_IRQn, 6);
    NVIC_EnableIRQ(EXTI0_IRQn);
}

void EXTI0_IRQHandler(void)
{
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;
    uint32_t event_token = 0x55AA55AAU;

    if (EXTI->PR & EXTI_PR_PR0) {
        /* Clear pending flag in EXTI */
        EXTI->PR = EXTI_PR_PR0;

        /* Post event token to queue from ISR context */
        if (g_event_queue != NULL) {
            xQueueSendFromISR(g_event_queue, &event_token, &xHigherPriorityTaskWoken);
            portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
        }
    }
}
