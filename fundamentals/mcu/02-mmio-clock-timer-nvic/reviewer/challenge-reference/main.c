#include <stdint.h>
#include <stdbool.h>
#include "pwm.h"
#include "clock.h"
#include "stm32f103xb.h"
#include "core_cm3.h"

int main(void)
{
    /* Initialize clock to 72 MHz (or 64 MHz fallback) */
    clock_frequencies_t freqs;
    bool clock_ok = clock_init(CLOCK_PROFILE_72MHZ_HSE);
    if (!clock_ok) {
        clock_init(CLOCK_PROFILE_64MHZ_HSI);
    }
    clock_get_frequencies(&freqs);

    /* Initialize 4-channel software PWM at 100 Hz (10 kHz tick) */
    pwm_init(freqs.timclk1_hz);

    /* Set 4 distinct duty cycles:
     * PA0: 10%
     * PA1: 25%
     * PA2: 50%
     * PA3: 75%
     */
    pwm_set_duty(0, 10);
    pwm_set_duty(1, 25);
    pwm_set_duty(2, 50);
    pwm_set_duty(3, 75);

    while (1) {
        __WFI();
    }

    return 0;
}
