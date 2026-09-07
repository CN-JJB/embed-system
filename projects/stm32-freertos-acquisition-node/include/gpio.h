#ifndef GPIO_H
#define GPIO_H

#include <stdint.h>
#include <stdbool.h>

void gpio_init(void);

/* PA1: DMA ISR / Process marker */
void gpio_set_pa1(void);
void gpio_clear_pa1(void);
void gpio_toggle_pa1(void);

/* PA2: Task_Compute active marker */
void gpio_set_pa2(void);
void gpio_clear_pa2(void);

/* PA3: Task_Health active marker */
void gpio_set_pa3(void);
void gpio_clear_pa3(void);

/* PA4: Diagnostic resource held marker */
void gpio_set_pa4(void);
void gpio_clear_pa4(void);

/* PC13: LED */
void gpio_set_led(void);
void gpio_clear_led(void);
void gpio_toggle_led(void);

#endif /* GPIO_H */
