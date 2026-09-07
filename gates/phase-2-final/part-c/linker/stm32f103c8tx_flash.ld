/*
 * =============================================================================
 * Original Pedagogical Linker Script for STM32F103C8T6 (64 KB Flash, 20 KB RAM)
 * =============================================================================
 * Course: Embedded Systems Foundations — Phase 2 MCU Bare-Metal
 * Module: P2-M01 Reset, Startup, Linker Script, and Vector Table
 *
 * Designed from first principles using GNU Binutils LD documentation and
 * STM32F103x8 electrical/memory architecture specifications (RM0008, DS5319).
 *
 * Memory Configuration:
 *   FLASH : Origin 0x08000000, Length  64 KB (0x10000)
 *   RAM   : Origin 0x20000000, Length  20 KB (0x05000)
 *
 * Provenance Note:
 *   This linker script is entirely original pedagogical coursework.
 *   Written from official GNU ld manual and STM32F103 memory map specifications.
 * =============================================================================
 */

ENTRY(Reset_Handler)

MEMORY
{
    FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 64K
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 20K
}

/* Initial stack pointer at top of 20 KB SRAM (0x20005000) */
_estack = ORIGIN(RAM) + LENGTH(RAM);

/* Minimum required stack allocation (1 KB) for runtime safety check */
_min_stack_size = 0x400;

SECTIONS
{
    /* Vector Table placed at beginning of Flash memory */
    .isr_vector :
    {
        . = ALIGN(4);
        KEEP(*(.isr_vector))
        . = ALIGN(4);
    } > FLASH

    /* Program code, inlined functions, and exception tables */
    .text :
    {
        . = ALIGN(4);
        *(.text)
        *(.text*)
        *(.glue_7)
        *(.glue_7t)
        *(.eh_frame)
        KEEP (*(.init))
        KEEP (*(.fini))
        . = ALIGN(4);
        _etext = .;
    } > FLASH

    /* Read-only data (constants, string literals) */
    .rodata :
    {
        . = ALIGN(4);
        *(.rodata)
        *(.rodata*)
        . = ALIGN(4);
    } > FLASH

    /* C runtime constructor arrays: preserved for __libc_init_array() */
    .preinit_array :
    {
        . = ALIGN(4);
        PROVIDE_HIDDEN (__preinit_array_start = .);
        KEEP (*(.preinit_array*))
        PROVIDE_HIDDEN (__preinit_array_end = .);
        . = ALIGN(4);
    } > FLASH

    .init_array :
    {
        . = ALIGN(4);
        PROVIDE_HIDDEN (__init_array_start = .);
        KEEP (*(SORT(.init_array.*)))
        KEEP (*(.init_array*))
        PROVIDE_HIDDEN (__init_array_end = .);
        . = ALIGN(4);
    } > FLASH

    .fini_array :
    {
        . = ALIGN(4);
        PROVIDE_HIDDEN (__fini_array_start = .);
        KEEP (*(SORT(.fini_array.*)))
        KEEP (*(.fini_array*))
        PROVIDE_HIDDEN (__fini_array_end = .);
        . = ALIGN(4);
    } > FLASH

    /* LMA address of initialized data in Flash */
    _sidata = LOADADDR(.data);

    /* Initialized data: VMA in RAM, loaded from Flash (LMA) */
    .data :
    {
        . = ALIGN(4);
        _sdata = .;
        *(.data)
        *(.data*)
        . = ALIGN(4);
        _edata = .;
    } > RAM AT > FLASH

    /* Uninitialized data (BSS): zero-initialized at reset in RAM */
    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss)
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > RAM

    /* User stack reservation check in RAM */
    ._user_stack :
    {
        . = ALIGN(8);
        PROVIDE ( _stack_start = . );
        . = . + _min_stack_size;
        . = ALIGN(8);
        PROVIDE ( _stack_end = . );
    } > RAM

    /* Discard unused unwinding tables to prevent unneeded bloat */
    /DISCARD/ :
    {
        *(.ARM.exidx*)
        *(.ARM.extab*)
    }
}

/* Static link assertions enforcing physical MCU limits */
ASSERT(_ebss + _min_stack_size <= ORIGIN(RAM) + LENGTH(RAM),
       "Linker Error: SRAM exhausted! BSS and stack exceed 20 KB capacity.")

ASSERT(LOADADDR(.data) + SIZEOF(.data) <= ORIGIN(FLASH) + LENGTH(FLASH),
       "Linker Error: Flash exhausted! Firmware image exceeds 64 KB capacity.")
