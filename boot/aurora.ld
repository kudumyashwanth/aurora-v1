/* Aurora v1 Linker Script — boot ROM at 0x8000_0000.
 * Rocket bakes device regions (debug @0x0, bootrom @0x10000, CLINT, PLIC) into the
 * tile PMA at low addresses as non-cacheable/non-readable-as-data. The boot's `la`
 * (lui+addi, absolute, link-origin based) data references must land clear of those
 * device regions, so code+rodata live at 0x8000_0000. Instruction fetch is PC-relative
 * either way; it was the absolute DATA loads at 0x0 that hit the debug region and faulted. */
ENTRY(_start)

MEMORY {
    ROM  (rx)  : ORIGIN = 0x80000000, LENGTH = 64K
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
