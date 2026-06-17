# aurora_boot.S — Aurora v1 AI Demo Boot Program
# Option C: Boot → Init → DMA matrix data → Run tensor core → Print result via UART
#
# Memory Map:
#   0x0000_0000  Boot ROM (this code)
#   0x1000_0000  SRAM (4MB) — matrices stored here
#   0x2000_0000  UART  (0x00=DATA, 0x04=STATUS)
#   0x3000_0000  GPIO  (0x00=OUT, 0x08=DIR)
#   0x5000_0000  Tensor Cluster
#     Core 0:  0x5000_0000 (0x00=CTRL, 0x04=STATUS, 0x08=A_ADDR, 0x0C=B_ADDR, 0x10=C_ADDR, 0x14=CONFIG)
#
# Matrix layout in SRAM:
#   0x1000_0000  Matrix A (16x16 x int8 = 256 bytes)
#   0x1000_0100  Matrix B (16x16 x int8 = 256 bytes)
#   0x1000_0200  Matrix C result (16x16 x int32 = 1024 bytes)

.section .text
.global _start

# ─── Hardware addresses ───────────────────────────────────────────────────────
.equ SRAM_BASE,    0x10000000
.equ UART_BASE,    0x20000000
.equ GPIO_BASE,    0x30000000
.equ TENSOR_BASE,  0x50000000

.equ UART_DATA,    0x00
.equ UART_STATUS,  0x04
.equ UART_TX_FULL, 0x08        # bit 3 = TX FIFO full (STATUS = {rx_full,rx_empty,tx_full,tx_empty,2'b00})

.equ GPIO_OUT,     0x00
.equ GPIO_DIR,     0x08

.equ TC_CTRL,      0x00        # [0]=start [1]=reset
.equ TC_STATUS,    0x04        # [0]=idle  [1]=busy [2]=done
.equ TC_A_ADDR,    0x08
.equ TC_B_ADDR,    0x0C
.equ TC_C_ADDR,    0x10
.equ TC_CONFIG,    0x14        # [7:0]=rows [15:8]=cols [23:16]=inner

.equ MAT_A,        0x10000000  # Matrix A in SRAM
.equ MAT_B,        0x10000100  # Matrix B in SRAM
.equ MAT_C,        0x10000200  # Result C in SRAM

# ─── Entry point ──────────────────────────────────────────────────────────────
_start:
    # Only hart 0 runs the demo; secondary harts park (avoids 4 cores
    # racing on the UART FIFO and tensor core registers).
    csrr t0, mhartid
    bnez t0, secondary_park

    # Set up stack at top of SRAM
    li   sp, 0x103FF000

    # ── Step 1: Init GPIO — set all 32 pins as output, set pin 0 high (LED on) ──
    li   t0, GPIO_BASE
    li   t1, 0xFFFFFFFF
    sw   t1, GPIO_DIR(t0)       # all outputs
    li   t1, 0x00000001
    sw   t1, GPIO_OUT(t0)       # pin 0 = 1 (boot indicator)

    # ── Step 2: Print banner ───────────────────────────────────────────────────
    la   a0, msg_banner
    call uart_print

    # ── Step 3: Fill Matrix A with identity-like pattern (diagonal = 1) ───────
    la   a0, msg_init_matrix
    call uart_print

    li   t0, MAT_A
    li   t1, 256               # 16*16 bytes
    li   t2, 0
fill_a:
    # A[i][j] = 1 if i==j else 0  (identity matrix scaled)
    # Simpler: A[i] = (i % 17) to create interesting pattern
    li   t3, 17
    rem  t3, t2, t3
    sb   t3, 0(t0)
    addi t0, t0, 1
    addi t2, t2, 1
    blt  t2, t1, fill_a

    # ── Step 4: Fill Matrix B with constant 2 ─────────────────────────────────
    li   t0, MAT_B
    li   t1, 256
    li   t2, 0
fill_b:
    li   t3, 2
    sb   t3, 0(t0)
    addi t0, t0, 1
    addi t2, t2, 1
    blt  t2, t1, fill_b

    # ── Step 5: Zero Matrix C ──────────────────────────────────────────────────
    li   t0, MAT_C
    li   t1, 1024
    li   t2, 0
zero_c:
    sw   zero, 0(t0)
    addi t0, t0, 4
    addi t2, t2, 4
    blt  t2, t1, zero_c

    # ── Step 6: Configure Tensor Core 0 ───────────────────────────────────────
    la   a0, msg_tensor_start
    call uart_print

    li   t0, TENSOR_BASE

    # Reset tensor core first
    li   t1, 0x2
    sw   t1, TC_CTRL(t0)
    li   t1, 0x0
    sw   t1, TC_CTRL(t0)

    # Set matrix addresses
    li   t1, MAT_A
    sw   t1, TC_A_ADDR(t0)
    li   t1, MAT_B
    sw   t1, TC_B_ADDR(t0)
    li   t1, MAT_C
    sw   t1, TC_C_ADDR(t0)

    # Config: 16x16x16 matrix multiply
    li   t1, 0x101010           # rows=16, cols=16, inner=16
    sw   t1, TC_CONFIG(t0)

    # ── Step 7: Start tensor core ──────────────────────────────────────────────
    li   t1, 0x1
    sw   t1, TC_CTRL(t0)       # start=1

    # ── Step 8: Wait for done (poll STATUS[2]) ─────────────────────────────────
    li   t2, 0x4               # done bit
wait_done:
    lw   t1, TC_STATUS(t0)
    and  t3, t1, t2
    beqz t3, wait_done

    # ── Step 9: Print result ───────────────────────────────────────────────────
    la   a0, msg_done
    call uart_print

    # Read first result word C[0][0] and print it
    li   t0, MAT_C
    lw   a0, 0(t0)
    call uart_print_hex

    la   a0, msg_newline
    call uart_print

    la   a0, msg_gops
    call uart_print

    # ── Step 10: Blink GPIO to show completion ─────────────────────────────────
    li   t0, GPIO_BASE
blink:
    li   t1, 0xAAAAAAAA
    sw   t1, GPIO_OUT(t0)
    li   t2, 100000
delay1:
    addi t2, t2, -1
    bnez t2, delay1

    li   t1, 0x55555555
    sw   t1, GPIO_OUT(t0)
    li   t2, 100000
delay2:
    addi t2, t2, -1
    bnez t2, delay2

    j    blink                  # loop forever blinking

# ─── Secondary hart park loop ─────────────────────────────────────────────────
secondary_park:
    wfi
    j    secondary_park

# ─── UART functions ───────────────────────────────────────────────────────────

# uart_putc: send char in a0
uart_putc:
    li   t0, UART_BASE
.wait_tx:
    lw   t1, UART_STATUS(t0)
    andi t1, t1, UART_TX_FULL
    bnez t1, .wait_tx
    sw   a0, UART_DATA(t0)
    ret

# uart_print: print null-terminated string at a0
uart_print:
    mv   t4, ra                 # save return address
    mv   t5, a0                 # save string pointer
.next_char:
    lb   a0, 0(t5)
    beqz a0, .print_done
    call uart_putc
    addi t5, t5, 1
    j    .next_char
.print_done:
    mv   ra, t4
    ret

# uart_print_hex: print a0 as 8-digit hex
uart_print_hex:
    mv   t4, ra
    mv   t6, a0
    li   t5, 28                 # shift amount (start from MSB nibble)
.hex_loop:
    srl  a0, t6, t5
    andi a0, a0, 0xF
    li   t3, 10
    blt  a0, t3, .is_digit
    addi a0, a0, 55             # 'A'-10
    j    .hex_send
.is_digit:
    addi a0, a0, 48             # '0'
.hex_send:
    call uart_putc
    addi t5, t5, -4
    bge  t5, zero, .hex_loop
    mv   ra, t4
    ret

# ─── Strings ──────────────────────────────────────────────────────────────────
.section .rodata

# NOTE: uart_print stops at the first NUL — each message must be a single
# string (.ascii for continuation lines, .string only on the last).
msg_banner:
    .ascii  "\r\n========================================\r\n"
    .ascii  "    AURORA v1 AI SoC BOOT\r\n"
    .ascii  "    4x CVA6 + 1024 MAC Tensor Cores\r\n"
    .ascii  "    204 GOPS INT8 @ 200MHz\r\n"
    .string "========================================\r\n"

msg_init_matrix:
    .string "[1] Initializing matrices in SRAM...\r\n"

msg_tensor_start:
    .string "[2] Running 16x16 matrix multiply on Tensor Core 0...\r\n"

msg_done:
    .string "[3] DONE! C[0][0] = 0x"

msg_gops:
    .ascii  "\r\n[4] Aurora Tensor Core: OPERATIONAL\r\n"
    .ascii  "    Peak performance: 204 GOPS INT8\r\n"
    .string "    Aurora v1 AI SoC is ALIVE!\r\n\r\n"

msg_newline:
    .string "\r\n"
