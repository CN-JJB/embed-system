#include "iwdg.h"
#include "stm32f103xb.h"

#define IWDG_KEY_RELOAD     0xAAAAU
#define IWDG_KEY_ENABLE     0xCCCCU
#define IWDG_KEY_WRITE_EN   0x5555U

#define IWDG_STATUS_TIMEOUT 100000U

bool iwdg_init(uint8_t prescaler, uint16_t reload)
{
    /* TODO: Unlock write access to PR and RLR registers (write 0x5555 to IWDG->KR) */
    (void)prescaler;
    (void)reload;

    /* TODO: Wait for prescaler update flag (PVU) with bounded loop */

    /* TODO: Configure prescaler and wait for reload update flag (RVU) with bounded loop */

    /* TODO: Configure reload value and load/start watchdog */

    return false;
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
