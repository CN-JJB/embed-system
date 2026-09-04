ENTRY(Reset_Handler)

MEMORY
{
    FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 64K
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 20K
}

_estack = ORIGIN(RAM) + LENGTH(RAM);
_min_stack_size = 0x400;

SECTIONS
{
    .isr_vector :
    {
        KEEP(*(.isr_vector))
        . = . + 2;
    } > FLASH

    .text :
    {
        *(.text)
        *(.text*)
        _etext = .;
    } > FLASH

    .rodata :
    {
        *(.rodata)
        *(.rodata*)
    } > FLASH

    .init_array :
    {
        PROVIDE_HIDDEN (__init_array_start = .);
        KEEP (*(SORT(.init_array.*)))
        KEEP (*(.init_array*))
        PROVIDE_HIDDEN (__init_array_end = .);
    } > FLASH

    _sidata = LOADADDR(.data);

    .data :
    {
        _sdata = .;
        *(.data)
        *(.data*)
        _edata = .;
    } > RAM AT > FLASH

    .bss :
    {
        _sbss = .;
        *(.bss)
        *(.bss*)
        *(COMMON)
        _ebss = .;
    } > RAM
}
