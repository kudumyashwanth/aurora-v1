# tc22: FINAL clean signoff of the 4x4 (re-run of tc21 after a disk-full truncated its reports).
# tc21 confirmed the route stays clean (0 violations) and hold improved -0.06 -> -0.04 with hold
# margin 0.12, but disk filled before DRC/LVS/antenna/final reports wrote. (Freed 44G of old runs.)
# tc22 closes it properly:
#   - HOLD: RSZ_MULTICORNER_LIB 1 (29k-cell 4x4 fits memory easily -> real multi-corner setup+hold
#     fixing, the correct way to clear the fast-corner -0.04ns hold) + GLB_RESIZER_HOLD_SLACK_MARGIN 0.1
#   - TAP DRC: FP_TAPCELL_DIST 10 (kept from tc21)
#   - ANTENNA: RUN_HEURISTIC_DIODE_INSERTION 1 (kept)
# Same proven clean-route floorplan DIE 1800 / density 0.20, normal GRT. Full reflow.
# TARGET: tritonRoute 0, Magic DRC 0, antenna ~0, LVS match, setup+hold MET all corners = SIGNED OFF.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc22 -overwrite

set ::env(DIE_AREA) "0 0 1800 1800"
set ::env(CORE_AREA) "20 20 1780 1780"
set ::env(FP_SIZING) absolute
set ::env(PL_TARGET_DENSITY) 0.20

set ::env(FP_TAPCELL_DIST) 10
set ::env(RUN_HEURISTIC_DIODE_INSERTION) 1
set ::env(RSZ_MULTICORNER_LIB) 1
set ::env(GLB_RESIZER_HOLD_SLACK_MARGIN) 0.1

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
puts "=== TENSOR_TC22_DONE ==="
exit 0
