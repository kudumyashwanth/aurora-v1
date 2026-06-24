#!/usr/bin/env bash
# Build the full-chip SoC sim: aurora_soc_top_chip (2-port Rocket macro behavioral RTL +
# tensor real RTL + real crossbar/CDC/boot_rom/sram/peripherals) under tb_aurora_chip.
# Rocket = behavioral sv2v (rocket_axitile_mem_clean.v, 101 mods) + behavioral cache SRAMs.
# -fno-gate dodges a Verilator V3Gate optimizer ICE on async_fifo (tool bug, not RTL).
set -e
cd /home/yashwanth/aurora_v1

RTL=(
  rtl/clock/clock_reset_controller.sv
  rtl/interconnect/async_fifo.sv
  rtl/interconnect/axi_cdc_bridge.sv
  rtl/interconnect/axi_crossbar.sv
  rtl/interconnect/rocket_axi_wrapper.sv
  rtl/boot/boot_rom.sv
  rtl/memory/sram_bank_array.sv
  rtl/peripherals/uart.sv
  rtl/peripherals/gpio.sv
  rtl/peripherals/timer.sv
  rtl/interrupt/interrupt_controller.sv
  rtl/tensor_cluster/mac_unit.sv
  rtl/tensor_cluster/tensor_local_buffer.sv
  rtl/tensor_cluster/systolic_array_16x16.sv
  rtl/tensor_cluster/tensor_core.sv
  openlane/tensor/tensor_core_hard.sv
  rtl/top/aurora_soc_top_chip.sv
  openlane/rocket/syn/rocket_axitile_mem_clean.v
  sim/models/rocket_sram_behav.v
  sim/tb/tb_aurora_chip.sv
)

verilator --cc --exe --build -sv --trace \
  --top-module tb_aurora_chip \
  -Mdir build_chip \
  -fno-gate \
  -Wno-fatal \
  -Wno-WIDTH -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE -Wno-UNUSED \
  -Wno-PINMISSING -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-DECLFILENAME \
  -Wno-CASEOVERLAP -Wno-CMPCONST -Wno-MULTIDRIVEN -Wno-LATCH \
  --top-module tb_aurora_chip \
  -o Vtb_aurora_chip \
  sim/main_chip.cpp \
  "${RTL[@]}"

echo "BUILD OK -> build_chip/Vtb_aurora_chip"
