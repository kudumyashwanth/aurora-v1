# tc21: FINAL CLEANUP of the 4x4 -- drive DRC, antenna, and hold to ZERO.
# tc20 (4x4, DIE 1800/0.20) is the clean-signoff base: detailed route 0 violations, LVS "Circuits
# match uniquely", post-route multi-corner SPEF STA setup MET (+3.26..3.31ns all corners), GDS done.
# Residuals to clear: Magic DRC = 1 (single nwell.4 missing N+ tap), net_antenna = 102, hold = -0.06ns
# (uniform across corners). All three are config-level:
#   - TAP DRC:  FP_TAPCELL_DIST 13 -> 10  (denser well taps -> full nwell tap coverage)
#   - ANTENNA:  RUN_HEURISTIC_DIODE_INSERTION 1 (proactive diodes) + GRT_REPAIR_ANTENNAS already on
#   - HOLD:     GLB_RESIZER_HOLD_SLACK_MARGIN 0.05 -> 0.12 (more hold buffers -> clear the 60ps)
# Keep everything that produced the clean route: DIE 1800/0.20, RSZ_MULTICORNER_LIB 0, normal GRT.
# Full reflow (tap dist + heuristic diodes are floorplan/pre-route stage). 29537-cell 4x4, fast.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc21 -overwrite

set ::env(DIE_AREA) "0 0 1800 1800"
set ::env(CORE_AREA) "20 20 1780 1780"
set ::env(FP_SIZING) absolute
set ::env(PL_TARGET_DENSITY) 0.20

# --- cleanup knobs ---
set ::env(FP_TAPCELL_DIST) 10
set ::env(RUN_HEURISTIC_DIODE_INSERTION) 1
set ::env(GLB_RESIZER_HOLD_SLACK_MARGIN) 0.12

set ::env(RSZ_MULTICORNER_LIB) 0
set ::env(ROUTING_CORES) 8
set ::env(GRT_ADJUSTMENT) 0.1
set ::env(GRT_ALLOW_CONGESTION) 0

run_synthesis
run_floorplan
run_placement
run_cts
run_routing
run_parasitics_sta
run_magic
run_magic_drc
run_magic_spice_export
run_lvs
run_magic_antenna_check
save_final_views
generate_final_summary_report
puts "=== TENSOR_TC21_DONE ==="
exit 0
