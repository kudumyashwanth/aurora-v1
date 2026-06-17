# Aurora SoC Timing Constraints
# Target: GF180MCU, 50 MHz (20ns period)

# ============================================================
# Clock Definitions
# ============================================================

# Primary system clock (50 MHz) — matches aurora_soc_top port name
create_clock -name clk_sys -period 20.0 [get_ports clk]

# Clock uncertainty and transition
set_clock_uncertainty 0.5 [get_clocks clk_sys]
set_clock_transition  0.3 [get_clocks clk_sys]

# ============================================================
# Input / Output Delays
# ============================================================

# 40% of clock period for external I/O
set input_delay_value  [expr 20.0 * 0.4]
set output_delay_value [expr 20.0 * 0.4]

# All inputs except clock and reset
set all_inputs_except_clk_rst [remove_from_collection \
    [all_inputs] \
    [get_ports {clk rst_n}]]

set_input_delay  $input_delay_value  -clock clk_sys $all_inputs_except_clk_rst
set_output_delay $output_delay_value -clock clk_sys [all_outputs]

# ============================================================
# False Paths
# ============================================================

# Async active-low reset is not a timed path
set_false_path -from [get_ports rst_n]

# ============================================================
# Multi-Cycle Paths
# ============================================================

# Tensor core systolic array — 2-cycle accumulate pipeline
set_multicycle_path 2 -setup \
    -from [get_cells -hierarchical -filter {REF_NAME =~ mac_unit*}] \
    -to   [get_cells -hierarchical -filter {REF_NAME =~ mac_unit*}]

set_multicycle_path 1 -hold \
    -from [get_cells -hierarchical -filter {REF_NAME =~ mac_unit*}] \
    -to   [get_cells -hierarchical -filter {REF_NAME =~ mac_unit*}]

# DMA descriptor fetch — 2-cycle memory latency
set_multicycle_path 2 -setup \
    -from [get_cells -hierarchical -filter {REF_NAME =~ dma_engine*}] \
    -to   [get_cells -hierarchical -filter {REF_NAME =~ dma_engine*}]

set_multicycle_path 1 -hold \
    -from [get_cells -hierarchical -filter {REF_NAME =~ dma_engine*}] \
    -to   [get_cells -hierarchical -filter {REF_NAME =~ dma_engine*}]

# ============================================================
# Load / Drive Strength
# ============================================================

# Output load (standard PCB trace)
set_load 10.0 [all_outputs]

# Input drive strength
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__buf_8 \
    -pin Z $all_inputs_except_clk_rst

# ============================================================
# Area Optimization Hint
# ============================================================

set_max_area 0
