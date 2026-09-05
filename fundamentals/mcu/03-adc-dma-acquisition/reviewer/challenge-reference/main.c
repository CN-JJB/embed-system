#include "acquisition.h"
#include "stm32f103xb.h"
#include "core_cm3.h"

int main(void)
{
    /* Assume system clock initialized by course startup */
    if (acquisition_pipeline_init(72000000U) != 0) {
        while (1) {
            __NOP();
        }
    }

    while (1) {
        __WFI();
    }
}
