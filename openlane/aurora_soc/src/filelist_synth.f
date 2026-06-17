# Aurora SoC — Synthesis filelist (OpenLane / Yosys)
# Uses cpu_cluster_stub.v in place of the full CVA6 core.
# CVA6 is integrated as a pre-hardened macro at tape-out.

# ---- Clock & Reset ----
/home/yashwanth/aurora_v1/rtl/clock/clock_reset_controller.sv

# ---- Interconnect ----
/home/yashwanth/aurora_v1/rtl/interconnect/async_fifo.sv
/home/yashwanth/aurora_v1/rtl/interconnect/axi_cdc_bridge.sv
/home/yashwanth/aurora_v1/rtl/interconnect/axi_crossbar.sv

# ---- Memory ----
/home/yashwanth/aurora_v1/rtl/boot/boot_rom.sv
/home/yashwanth/aurora_v1/rtl/memory/sram_bank_array.sv

# ---- DMA ----
/home/yashwanth/aurora_v1/rtl/dma/dma_engine_complete.sv

# ---- Peripherals ----
/home/yashwanth/aurora_v1/rtl/peripherals/uart.sv
/home/yashwanth/aurora_v1/rtl/peripherals/gpio.sv
/home/yashwanth/aurora_v1/rtl/peripherals/timer.sv
/home/yashwanth/aurora_v1/rtl/interrupt/interrupt_controller.sv

# ---- Tensor Cluster ----
/home/yashwanth/aurora_v1/rtl/tensor_cluster/mac_unit.sv
/home/yashwanth/aurora_v1/rtl/tensor_cluster/tensor_local_buffer.sv
/home/yashwanth/aurora_v1/rtl/tensor_cluster/systolic_array_16x16.sv
/home/yashwanth/aurora_v1/rtl/tensor_cluster/tensor_core.sv
/home/yashwanth/aurora_v1/rtl/tensor_cluster/tensor_cluster_top.sv

# ---- CPU Cluster (black-box stub — CVA6 integrated separately) ----
/home/yashwanth/aurora_v1/rtl/cpu_cluster/cpu_cluster_stub.v

# ---- SoC Top ----
/home/yashwanth/aurora_v1/rtl/top/aurora_soc_top.sv
