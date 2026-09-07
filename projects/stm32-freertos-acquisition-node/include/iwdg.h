#ifndef IWDG_H
#define IWDG_H

#include <stdint.h>
#include <stdbool.h>

/**
 * @brief Initialize Independent Watchdog (IWDG).
 *
 * STM32F103 IWDG is clocked by LSI (~40 kHz nominal, device dependent ~30-60 kHz).
 *
 * @param prescaler Prescaler divider code (e.g. 4 for /64).
 * @param reload 12-bit reload value (0 to 4095).
 * @return true if status registers updated within bounded loop, false otherwise.
 */
#define IWDG_PRESCALER_4    0x00
#define IWDG_PRESCALER_8    0x01
#define IWDG_PRESCALER_16   0x02
#define IWDG_PRESCALER_32   0x03
#define IWDG_PRESCALER_64   0x04
#define IWDG_PRESCALER_128  0x05
#define IWDG_PRESCALER_256  0x06

bool iwdg_init(uint8_t prescaler, uint16_t reload);

/**
 * @brief Refresh (kick) the watchdog counter with key 0xAAAA.
 */
void iwdg_refresh(void);

/**
 * @brief Check if previous system reset was triggered by IWDG, then clear reset flags.
 * @return true if IWDGRSTF was set, false otherwise.
 */
bool iwdg_check_and_clear_reset_cause(void);

#endif /* IWDG_H */
