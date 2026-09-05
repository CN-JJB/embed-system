#include "clock.h"
#include "gpio.h"
#include "FreeRTOS.h"
#include "queue.h"
#include "task.h"
#include "core_cm3.h"
#include "stm32f103xb.h"

#define GATE_QUEUE_LENGTH   8
#define GATE_ITEM_SIZE      sizeof(uint32_t)

static QueueHandle_t s_telemetry_queue = NULL;
volatile uint32_t g_telemetry_sent = 0;
volatile uint32_t g_telemetry_received = 0;

static void prvTelemetryDispatchTask(void *pvParameters)
{
    (void)pvParameters;
    uint32_t packet = 0;

    for (;;) {
        /* Defect 2: Non-blocking poll (timeout 0) causes 100% CPU starvation
         * instead of blocking indefinitely with portMAX_DELAY.
         */
        if (xQueueReceive(s_telemetry_queue, &packet, 0) == pdPASS) {
            gpio_toggle_pa2();
            g_telemetry_received++;
        }
    }
}

void TIM2_IRQHandler(void)
{
    if ((TIM2->SR & TIM_SR_UIF) != 0) {
        TIM2->SR = (uint16_t)(~TIM_SR_UIF);
        __DSB();

        gpio_toggle_pa1();

        static uint32_t s_packet_id = 0;
        s_packet_id++;

        BaseType_t xHigherPriorityTaskWoken = pdFALSE;

        if (s_telemetry_queue != NULL) {
            xQueueSendFromISR(s_telemetry_queue, &s_packet_id, &xHigherPriorityTaskWoken);
            g_telemetry_sent++;
        }

        /* Defect 3: Missing portYIELD_FROM_ISR(xHigherPriorityTaskWoken) */
        (void)xHigherPriorityTaskWoken;
    }
}

int main(void)
{
    clock_init(CLOCK_PROFILE_72MHZ_HSE);
    gpio_init();

    /* Priority Grouping */
    NVIC_SetPriorityGrouping(0);

    /* Create telemetry queue */
    s_telemetry_queue = xQueueCreate(GATE_QUEUE_LENGTH, GATE_ITEM_SIZE);
    configASSERT(s_telemetry_queue != NULL);

    /* Create telemetry dispatch task at Priority 3 */
    xTaskCreate(prvTelemetryDispatchTask, "TelemTx", 256, NULL, 3, NULL);

    /* Peripheral TIM2 Bring-up */
    RCC->APB1ENR |= RCC_APB1ENR_TIM2EN;

    /* Defect 1: Priority set to logical 3 (encoded 0x30).
     * Violates configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY (5, encoded 0x50)!
     */
    NVIC_SetPriority(TIM2_IRQn, 3);
    NVIC_EnableIRQ(TIM2_IRQn);

    TIM2->PSC = 7199;
    TIM2->ARR = 99;
    TIM2->SR = 0;
    TIM2->EGR = TIM_EGR_UG;
    TIM2->SR = 0;
    TIM2->DIER |= TIM_DIER_UIE;
    TIM2->CR1 |= TIM_CR1_CEN;

    vTaskStartScheduler();

    while (1) {
        __NOP();
    }

    return 0;
}
