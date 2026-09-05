#include <stddef.h>
#include <stdint.h>
#include "stm32f103xb.h"
#include "core_cm3.h"

void _init(void)
{
}

void _fini(void)
{
}

/**
 * @brief FreeRTOS assertion failure hook.
 * Traps in infinite loop with interrupts disabled.
 */
void vAssertCalled(const char *pcFile, unsigned long ulLine)
{
    (void)pcFile;
    (void)ulLine;
    __disable_irq();
    while (1) {
        __NOP();
    }
}

/**
 * @brief FreeRTOS dynamic allocation failure hook.
 * Traps in infinite loop if heap_4 runs out of memory.
 */
void vApplicationMallocFailedHook(void)
{
    __disable_irq();
    while (1) {
        __NOP();
    }
}
