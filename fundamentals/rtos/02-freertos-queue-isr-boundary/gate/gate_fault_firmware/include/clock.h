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
    uint32_t pclk1_hz;      /* APB1 peripheral bus clock (PCLK1) in Hz */
    uint32_t pclk2_hz;      /* APB2 peripheral bus clock (PCLK2) in Hz */
} clock_frequencies_t;

bool clock_init(clock_profile_t profile);
void clock_get_frequencies(clock_frequencies_t *freqs);

#endif /* CLOCK_H */
