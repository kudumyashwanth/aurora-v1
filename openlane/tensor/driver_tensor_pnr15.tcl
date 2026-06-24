# tc15: MAX-SPREAD floorplan to kill the tc12 LOCAL met1 short-storm.
# Squeeze established by tc12/tc13/tc14:
#   - tc12 (2800 die, density 0.30, full met1): global converges (0 overflow) but detailed
#     DIVERGES, 1.1M->1.3M shorts almost all on MET1. The 0-overflow is a gcell-AVERAGE;
#     locally the systolic pin cluster packs met1 over capacity (on top of power rails).
#   - tc13 (ban met1) & tc14 (met1 at 27%): global STARVES -> GRT-0103. Global needs met1.
# So the fix must keep met1 FULLY available (for global) while LOWERING LOCAL cell/pin
# density (for detailed). Lever = spread the cells maximally: bigger die + very low
# PL_TARGET_DENSITY so the placer distributes the systolic array thinly instead of clumping
# it at 0.30 local density. Full met1 -> global still converges like tc12. Lower local pin
# density -> detailed routing gets met1 room -> shorts should fall instead of diverge.
# Die changes -> full reflow from synthesis (tc12 CTS checkpoint is for the 2800 die).
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc15 -overwrite

# --- max-spread floorplan: big die, very low density, full met1 ---
set ::env(DIE_AREA) "0 0 3600 3600"
set ::env(CORE_AREA) "20 20 3580 3580"
set ::env(FP_SIZING) absolute
set ::env(PL_TARGET_DENSITY) 0.15
set ::env(RT_MIN_LAYER) met1
set ::env(RT_CLOCK_MIN_LAYER) met3
set ::env(GRT_ADJUSTMENT) 0.0

set ::env(RSZ_MULTICORNER_LIB) 0
set ::env(ROUTING_CORES) 8
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
puts "=== TENSOR_TC15_DONE ==="
exit 0
