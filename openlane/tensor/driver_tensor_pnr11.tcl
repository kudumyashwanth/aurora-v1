# tc11: ROOT-CAUSE FIX for the tc9/tc10 global-route congestion wall.
# Diagnosis: 8x8 synth/place/CTS all PASS (timing MET), but global routing drops into
# GRT-0103 "hard benchmark" overflow mode and won't converge -> structural routing
# congestion, NOT cell count. Cause: 37% util / 0.35 density on a routing-heavy systolic
# datapath with only 5 metal layers (sky130 limit) + 4 SRAM macros (69k blockages).
# FIX (timing/routability over area): loosen the floorplan to give FastRoute room --
# DIE 2800->3300 (+39% area), PL_TARGET_DENSITY 0.35->0.28, macros spread wider with
# ~900um channels (macro_placement_tc11.cfg). Full re-flow from synthesis since the die
# changed (tc9 CTS checkpoint is for the 2800 die, cannot be reused). Keep the safety
# flags so it still produces a routed result if any residual congestion remains.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc11 -overwrite

# --- looser floorplan to kill routing congestion ---
set ::env(DIE_AREA) "0 0 3300 3300"
set ::env(FP_SIZING) absolute
set ::env(PL_TARGET_DENSITY) 0.28
set ::env(MACRO_PLACEMENT_CFG) /home/yashwanth/aurora_v1/openlane/tensor/macro_placement_tc11.cfg

# --- proven safety flags (same as tc9/tc10) ---
set ::env(RSZ_MULTICORNER_LIB) 0
set ::env(ROUTING_CORES) 8
set ::env(GRT_ADJUSTMENT) 0.0
set ::env(GRT_ALLOW_CONGESTION) 1
set ::env(GLB_RESIZER_DESIGN_OPTIMIZATIONS) 0
set ::env(GLB_RESIZER_TIMING_OPTIMIZATIONS) 0

run_synthesis
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
puts "=== TENSOR_TC11_DONE ==="
exit 0
