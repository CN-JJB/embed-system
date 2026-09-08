/**
 * =============================================================================
 * Minimal Course Runtime Glue (Preferred Policy A)
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M01 Reset, Startup, Linker Script, and Vector Table
 *
 * Rationale:
 *   When the toolchain compiles firmware with `-nostartfiles`, the standard
 *   GCC/newlib C runtime startfiles (crt0.o, crti.o, crtbegin.o, crtend.o, crtn.o)
 *   are suppressed.
 *
 *   However, newlib-nano's __libc_init_array() function contains calls to:
 *     - _init(): legacy pre-constructor hook (normally defined in crti.o/crtn.o)
 *     - Function pointers in .preinit_array and .init_array
 *
 *   Similarly, __libc_fini_array() references _fini().
 *
 *   To allow __libc_init_array() to execute correctly without pulling in
 *   toolchain CRT objects or creating hidden entry points, this file provides
 *   explicit, minimal stubs for _init() and _fini().
 *
 * Invariants:
 *   - No C++ runtime (libsupc++ / RTTI / exceptions).
 *   - No libc heap allocations (malloc / free / realloc).
 *   - No _sbrk implementation is pulled in when heap is unused.
 *   - No host OS syscalls or semi-hosting dependencies.
 * =============================================================================
 */

#include <stddef.h>

/**
 * @brief Stub for legacy C runtime initialization.
 * Called by newlib-nano __libc_init_array() before invoking .init_array entries.
 */
void _init(void)
{
    /* Intentionally empty: all hardware/bus initialization is performed
     * in SystemInit() and course Reset_Handler.
     */
}

/**
 * @brief Stub for legacy C runtime teardown.
 * Called by newlib-nano __libc_fini_array() if an image terminates.
 */
void _fini(void)
{
    /* Intentionally empty: embedded bare-metal firmware does not terminate. */
}
