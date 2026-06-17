# tc5: re-floorplan tensor_core_hard with a right-sized die (4200x4200, ~37% util)
# and a centered 2x2 SRAM cluster with 350um routing channels (was: 4 macros jammed
# in a corner of a 6500 die at 15% util -> HPWL 1.3e11, GRT overflow never cleared,
# tc2 crashed / tc3+tc4 stuck). Reuses tc1 synthesis netlist (no re-synth).
# GRT_ADJUSTMENT 0 + GRT_ALLOW_CONGESTION 0 come from config.json (balanced FP should
# not need congestion relief). Single-corner resizer + 8 cores for RAM safety.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc5 -overwrite
set ::env(CURRENT_NETLIST) /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster/runs/tc1/results/synthesis/tensor_core_hard.v
set ::env(CURRENT_SDC) /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster/tensor_clean.sdc
run_floorplan
run_placement
run_cts
run_resizer_timing
run_routing
run_parasitics_sta
run_magic
run_magic_drc
run_magic_spice_export
run_lvs
run_magic_antenna_check
save_final_views
generate_final_summary_report
puts "=== TENSOR_TC5_DONE ==="
exit 0
