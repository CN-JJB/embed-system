#include "clock.h"
#include "gpio.h"
#include "timer.h"
#include "stm32f103xb.h"
#include "core_cm3.h"

int main(void)
{
    clock_init(CLOCK_PROFILE_72MHZ_HSE);
    gpio_init();
    tim2_init_1khz(72000000U);

    while (1) {
        /* Non-atomic read-modify-write on shared GPIOA->ODR in Thread mode */
        GPIOA->ODR |= GPIO_ODR_ODR2;
        for (volatile int i = 0; i < 50; ++i) {
            __NOP();
        }
        GPIOA->ODR &= ~GPIO_ODR_ODR2;
        for (volatile int i = 0; i < 50; ++i) {
            __NOP();
        }
    }

    return 0;
}
