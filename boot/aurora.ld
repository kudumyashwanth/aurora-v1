/* Aurora v1 Linker Script — boot from ROM at 0x0000_0000 */
ENTRY(_start)

MEMORY {
    ROM  (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
    SRAM (rwx) : ORIGIN = 0x10000000, LENGTH = 4M
}

SECTIONS {
    .text : {
        *(.text)
        *(.text.*)
    } > ROM

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } > ROM

    .data : {
        *(.data)
    } > SRAM

    .bss : {
        *(.bss)
        *(COMMON)
    } > SRAM
}
