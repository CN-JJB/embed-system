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

    RCC->APB1ENR |= RCC_APB1ENR_TIM2EN;
    NVIC_SetPriorityGrouping(0);
    NVIC_SetPriority(TIM2_IRQn, 6);
    NVIC_EnableIRQ(TIM2_IRQn);

    uint32_t timer_clk = SystemCoreClock;
    uint32_t prescaler = (timer_clk / 10000U);
    if (prescaler > 0) {
        prescaler -= 1;
    }
    TIM2->PSC = (uint16_t)prescaler;

    uint32_t arr = (10000U / freq_hz);
    if (arr > 0) {
        arr -= 1;
    }
    TIM2->ARR = (uint16_t)arr;

    TIM2->SR = 0;
    TIM2->EGR = TIM_EGR_UG;
    TIM2->SR = 0;

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
        TIM2->SR = (uint16_t)(~TIM_SR_UIF);
        __DSB();

        gpio_toggle_pa1();

        static uint32_t s_seq = 0;
        s_seq++;

        /* Context violation defect: calling task-context xQueueSend() from inside ISR.
         * xQueueSend() invokes portENTER_CRITICAL(), which asserts that VECTACTIVE == 0.
         */
        if (g_sample_queue != NULL) {
            BaseType_t xResult = xQueueSend(g_sample_queue, (const void *)&s_seq, 0);
            if (xResult == pdPASS) {
                g_isr_sent_count++;
            } else {
                g_isr_dropped_count++;
            }
        }
    }
}
