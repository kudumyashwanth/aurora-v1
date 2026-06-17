# tc7: congestion-relief re-floorplan. tc5/tc6 proved 0.45 density on a 4200 die was
# too tight for the routing-bound 256-MAC systolic datapath — the routing-design GRT
# looped resize->reroute for ~1h chasing overflow. Attack congestion three ways:
#   1. bigger die 5000x5000 (~27% util) -> spreads the dense MAC array
#   2. PL_TARGET_DENSITY 0.30 -> more routing tracks between cells
#   3. FP_PDN pitch 180->360 -> frees met1 (was 30% eaten by power straps) + met4
# Centered 2x2 macros (no corner hotspot) re-centered for the 5000 die. GRT_ALLOW_
# CONGESTION 1 bounds each GRT pass. Reuses tc1 synth netlist. Single-corner + 8 cores.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc7 -overwrite
set ::env(CURRENT_NETLIST) /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster/runs/tc1/results/synthesis/tensor_core_hard.v
set ::env(CURRENT_SDC) /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster/tensor_clean.sdc
set ::env(RSZ_MULTICORNER_LIB) 0
set ::env(ROUTING_CORES) 8
set ::env(GRT_ADJUSTMENT) 0.0
set ::env(GRT_ALLOW_CONGESTION) 1
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
puts "=== TENSOR_TC7_DONE ==="
exit 0
