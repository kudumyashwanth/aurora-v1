# Aurora SoC — CHIP top (macro-based) lint filelist
# aurora_soc_top_chip = 1 Rocket macro + 1 tensor macro + std-cell glue.
# Rocket macro is a black-box stub; tensor uses its real pre-harden RTL.

# ---- Clock & Reset ----
/home/yashwanth/aurora_v1/rtl/clock/clock_reset_controller.sv

# ---- Interconnect ----
/home/yashwanth/aurora_v1/rtl/interconnect/async_fifo.sv
/home/yashwanth/aurora_v1/rtl/interconnect/axi_cdc_bridge.sv
/home/yashwanth/aurora_v1/rtl/interconnect/axi_crossbar.sv
/home/yashwanth/aurora_v1/rtl/interconnect/rocket_axi_wrapper.sv

# ---- Memory ----
/home/yashwanth/aurora_v1/rtl/boot/boot_rom.sv
/home/yashwanth/aurora_v1/rtl/memory/sram_bank_array.sv

# ---- Peripherals ----
/home/yashwanth/aurora_v1/rtl/peripherals/uart.sv
/home/yashwanth/aurora_v1/rtl/peripherals/gpio.sv
/home/yashwanth/aurora_v1/rtl/peripherals/timer.sv
/home/yashwanth/aurora_v1/rtl/interrupt/interrupt_controller.sv

# ---- Tensor core (real pre-harden RTL, behavioral flop buffer) ----
/home/yashwanth/aurora_v1/rtl/tensor_cluster/mac_unit.sv
/home/yashwanth/aurora_v1/rtl/tensor_cluster/tensor_local_buffer.sv
/home/yashwanth/aurora_v1/rtl/tensor_cluster/systolic_array_16x16.sv
/home/yashwanth/aurora_v1/rtl/tensor_cluster/tensor_core.sv
/home/yashwanth/aurora_v1/openlane/tensor/tensor_core_hard.sv

# ---- Rocket macro (black-box stub for lint only) ----
/home/yashwanth/aurora_v1/rtl/stubs/RocketAXITileTop_stub.sv

# ---- Chip Top ----
/home/yashwanth/aurora_v1/rtl/top/aurora_soc_top_chip.sv
