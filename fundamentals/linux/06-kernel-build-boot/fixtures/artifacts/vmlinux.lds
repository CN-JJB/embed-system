OUTPUT_ARCH(arm)
ENTRY(stext)

SECTIONS
{
    . = 0xC0008000;
    .head.text : {
        *(.head.text)
    }

    . = 0xC0800000;
    .text : {
        *(.text)
    }

    .rodata : {
        *(.rodata*)
    }

    .data : {
        *(.data*)
    }

    .bss : {
        *(.bss*)
    }
}
