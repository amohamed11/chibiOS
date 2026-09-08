ENTRY(_start)

SECTIONS
{
    /* MBR loads kernel into RAM at physical address 0x10000 */
    . = 0x10000;

    .text ALIGN(4) : {
        *(.text .text.*)
    }

    .rodata ALIGN(4) : {
        *(.rodata .rodata.*)
    }

    .data ALIGN(4) : {
        *(.data .data.*)
    }

    .bss ALIGN(4) : {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    }

    _kernel_end = .;

    /DISCARD/ : {
        *(.comment)
        *(.note.*)
        *(.eh_frame)
    }
}
