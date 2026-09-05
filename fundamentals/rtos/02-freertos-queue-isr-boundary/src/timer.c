#include "timer.h"
#include "gpio.h"
#include "queue_app.h"
#include "stm32f103xb.h"
#include "core_cm3.h"
#include "FreeRTOS.h"
#include "queue.h"

volatile uint32_t g_isr_sent_count = 0;
volatile uint32_t g_isr_dropped_count = 0;

void timer2_init(uint32_t freq_hz)
{
    if (freq_hz == 0) {
        freq_hz = 100;
    }

    /* Enable TIM2 clock on APB1 */
    RCC->APB1ENR |= RCC_APB1ENR_TIM2EN;

    /* Ensure priority grouping is 0 (4 bits of pre-emption priority) */
    NVIC_SetPriorityGrouping(0);

    /* Set TIM2 logical priority 6 (encoded byte 0x60).
     * This is strictly within the FreeRTOS syscall boundary (priority 5, encoded 0x50).
     */
    NVIC_SetPriority(TIM2_IRQn, 6);

    /* Enable TIM2 interrupt in NVIC */
    NVIC_EnableIRQ(TIM2_IRQn);

    /* Prescaler to obtain 10 kHz base frequency */
    uint32_t timer_clk = SystemCoreClock; /* On STM32F1 with APB1 div=2, timer clk is x2 = SYSCLK */
    uint32_t prescaler = (timer_clk / 10000U);
    if (prescaler > 0) {
        prescaler -= 1;
    }
    TIM2->PSC = (uint16_t)prescaler;

    /* Auto-reload for requested frequency */
    uint32_t arr = (10000U / freq_hz);
    if (arr > 0) {
        arr -= 1;
    }
    TIM2->ARR = (uint16_t)arr;

    /* Clear update event flag and generate an update event to reload PSC */
    TIM2->SR = 0;
    TIM2->EGR = TIM_EGR_UG;
    TIM2->SR = 0;

    /* Enable Update Interrupt */
    TIM2->DIER |= TIM_DIER_UIE;
}

void timer2_start(void)
{
    TIM2->CR1 |= TIM_CR1_CEN;
}

void timer2_stop(void)
{
    TIM2->CR1 &= ~TIM_CR1_CEN;
}

void TIM2_IRQHandler(void)
{
    if ((TIM2->SR & TIM_SR_UIF) != 0) {
        /* Clear update interrupt flag */
        TIM2->SR = (uint16_t)(~TIM_SR_UIF);
        __DSB();

        /* Diagnostic marker: toggle PA1 on ISR entry */
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

        /* Request PendSV if a higher priority task was unblocked */
        portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
    }
}
