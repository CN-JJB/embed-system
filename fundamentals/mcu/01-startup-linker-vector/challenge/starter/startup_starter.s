/* P2-M01 Challenge Starter Startup Assembly (INCOMPLETE)
 * Learner TODO:
 * 1. Define vector table with initial MSP and Reset_Handler
 * 2. Implement Reset_Handler to copy .data, clear .bss, call SystemInit, __libc_init_array, and main
 */

    .syntax unified
    .cpu cortex-m3
    .thumb

    .section .isr_vector, "a", %progbits
    .type g_pfnVectors, %object
g_pfnVectors:
    /* TODO: Vector table */
    .size g_pfnVectors, .-g_pfnVectors

    .section .text.Reset_Handler
    .weak Reset_Handler
    .type Reset_Handler, %function
Reset_Handler:
    /* TODO: Implement reset initialization sequence */
    b .
    .size Reset_Handler, .-Reset_Handler
