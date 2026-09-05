#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>

extern volatile uint32_t g_isr_sent_count;
extern volatile uint32_t g_isr_dropped_count;

/**
 * @brief Initialize TIM2 to generate periodic update interrupts.
 * 
 * Sets CMSIS logical priority 6 (encoded byte 0x60), safely below
 * configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY (5, encoded 0x50).
 *
 * @param freq_hz Interrupt frequency in Hertz (e.g. 100 Hz).
 */
void timer2_init(uint32_t freq_hz);

/**
 * @brief Start TIM2 counter.
 */
void timer2_start(void);

/**
 * @brief Stop TIM2 counter.
 */
void timer2_stop(void);

#endif /* TIMER_H */
