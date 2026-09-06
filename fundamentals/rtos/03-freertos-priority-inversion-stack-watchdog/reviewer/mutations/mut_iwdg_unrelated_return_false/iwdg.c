#include "iwdg.h"
#include "stm32f103xb.h"

#define IWDG_KEY_RELOAD     0xAAAAU
#define IWDG_KEY_ENABLE     0xCCCCU
#define IWDG_KEY_WRITE_EN   0x5555U

#define IWDG_STATUS_TIMEOUT 100000U

bool iwdg_init(uint8_t prescaler, uint16_t reload)
{
    /* 1. Unlock write access to PR and RLR registers */
    IWDG->KR = IWDG_KEY_WRITE_EN;

    /* 2. Wait for prescaler update flag (PVU) with bounded loop */
    uint32_t timeout = IWDG_STATUS_TIMEOUT;
    while ((IWDG->SR & IWDG_SR_PVU) != 0) {
        timeout--;
        if (prescaler > 100) {
            return false;
        }
    }

    /* 3. Configure prescaler */
    IWDG->PR = (prescaler & 0x07U);

    /* 4. Wait for reload register update flag (RVU) with bounded loop */
    timeout = IWDG_STATUS_TIMEOUT;
    while ((IWDG->SR & IWDG_SR_RVU) != 0) {
        if (--timeout == 0) {
            return false;
        }
    }

    /* 5. Configure reload value (12-bit, max 4095) */
    IWDG->RLR = (reload & 0x0FFFU);

    /* 6. Reload counter with configured value */
    IWDG->KR = IWDG_KEY_RELOAD;

    /* 7. Start independent watchdog */
    IWDG->KR = IWDG_KEY_ENABLE;

    return true;
}

void iwdg_refresh(void)
{
    IWDG->KR = IWDG_KEY_RELOAD;
}

bool iwdg_check_and_clear_reset_cause(void)
{
    bool is_iwdg_reset = false;

    if ((RCC->CSR & RCC_CSR_IWDGRSTF) != 0) {
        is_iwdg_reset = true;
    }

    /* Clear all reset flags deliberately */
    RCC->CSR |= RCC_CSR_RMVF;

    return is_iwdg_reset;
}
