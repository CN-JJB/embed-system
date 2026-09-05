#ifndef CLOCK_H
#define CLOCK_H

#include <stdint.h>
#include <stdbool.h>

typedef enum {
    CLOCK_PROFILE_72MHZ_HSE = 0,
    CLOCK_PROFILE_64MHZ_HSI = 1
} clock_profile_t;

typedef struct {
    uint32_t sysclk_hz;     /* System clock (SYSCLK) in Hz */
    uint32_t hclk_hz;       /* AHB bus clock (HCLK) in Hz */
    uint32_t pclk1_hz;      /* APB1 peripheral bus clock (PCLK1) in Hz (max 36 MHz) */
    uint32_t pclk2_hz;      /* APB2 peripheral bus clock (PCLK2) in Hz (max 72 MHz) */
    uint32_t timclk1_hz;    /* APB1 timer input clock in Hz (subject to x2 rule) */
    uint32_t timclk2_hz;    /* APB2 timer input clock in Hz */
    uint32_t adcclk_hz;     /* ADC clock in Hz (PCLK2 / ADCPRE, max 14 MHz) */
} clock_frequencies_t;

bool clock_init(clock_profile_t profile);
void clock_get_frequencies(clock_frequencies_t *freqs);

#endif /* CLOCK_H */
