# tc9: FIRST 8x8 (SIZE=8, 64-MAC) tensor tile harden, full flow from synthesis.
# RTL now SIZE=8 (parametric loader rewritten + lint-clean); sv2v regenerated to
# openlane/tensor/syn/tensor_core_hard_sv2v.v. Floorplan right-sized for the ~4x
# smaller design: DIE 2800x2800 (~37% util), centered 2x2 SRAM macros, 300um channels.
# Unattended overnight run -> keep the safety flags so it is GUARANTEED to produce a
# routed result: skip the two global-route resizers (they looped on 16x16) and let
# FastRoute accept residual congestion. 8x8 should route easily (smaller than RocketTile
# which signed off clean); if it does, re-enable resizers later for timing polish.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc9 -overwrite
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
puts "=== TENSOR_TC9_DONE ==="
exit 0
