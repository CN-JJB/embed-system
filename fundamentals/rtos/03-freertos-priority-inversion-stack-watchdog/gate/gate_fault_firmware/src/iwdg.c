#include "iwdg.h"
#include "stm32f103xb.h"

#define IWDG_KEY_RELOAD     0xAAAAU
#define IWDG_KEY_ENABLE     0xCCCCU
#define IWDG_KEY_WRITE_EN   0x5555U

bool iwdg_init(uint8_t prescaler, uint16_t reload)
{
    /* 1. Unlock write access to PR and RLR registers */
    IWDG->KR = IWDG_KEY_WRITE_EN;

    /* GATE DEFECT: Unbounded loop waiting for PVU without timeout counter */
    while ((IWDG->SR & IWDG_SR_PVU) != 0) {
        __NOP();
    }

    /* 3. Configure prescaler */
    IWDG->PR = (prescaler & 0x07U);

    /* GATE DEFECT: Unbounded loop waiting for RVU without timeout counter */
    while ((IWDG->SR & IWDG_SR_RVU) != 0) {
        __NOP();
    }

    /* 5. Configure reload value */
    IWDG->RLR = (reload & 0x0FFFU);

    /* 6. Reload counter */
    IWDG->KR = IWDG_KEY_RELOAD;

    /* 7. Start watchdog */
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

    /* GATE DEFECT: Omits clearing reset flags via RCC->CSR |= RCC_CSR_RMVF */
    /* Software fails to clear stale hardware reset flags! */

    return is_iwdg_reset;
}
