#include <stdint.h>

#define PERIPH_BASE 0x40000000u
#define DEMO_CTRL_OFFSET 0x00001000u
#define DEMO_ENABLE (1u << 3)
#define DEMO_MODE_MASK (3u << 4)

/*
 * Treat DEMO_CTRL as an ordinary read/write control register for the core
 * exercise. The learner must still discuss why register-specific semantics
 * can make generic read-modify-write unsafe.
 */
static uint32_t *demo_ctrl(void)
{
    return (uint32_t *)(PERIPH_BASE + DEMO_CTRL_OFFSET);
}

void demo_enable_mode2(void)
{
    uint32_t *reg = demo_ctrl();
    uint32_t value = *reg;

    value &= ~DEMO_MODE_MASK;
    value |= DEMO_ENABLE | (2u << 4);

    *reg = value;
}
