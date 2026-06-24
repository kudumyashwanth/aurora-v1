# tc23: clear the last two residuals on the 4x4 (route/LVS/timing already clean in tc22).
# tc22 final state: tritonRoute 0, LVS "match uniquely", setup+hold MET all corners (+3.58/+0.07).
# Residuals: net_antenna 8 (ratios 400..3308 on met1/2/3) + Magic DRC 1 (one isolated nwell.4 tap at
# 168.17,229.79 -- FP_TAPCELL_DIST 13->10 did NOT change it, so it's an isolated nwell in a gap, not
# tap-row spacing). tc23 attacks both:
#   - ANTENNA: HEURISTIC_ANTENNA_THRESHOLD 90->30 (diodes on far more nets) + RUN_HEURISTIC_DIODE_INSERTION 1
#     + DIODE_ON_PORTS "in" + GRT_REPAIR_ANTENNAS 1 (reroutes worst nets on upper layers).
#   - NWELL TAP: PL_TARGET_DENSITY 0.20->0.24 to slightly cluster cells so stray nwells share a tap
#     (still below the ~0.45 met1-storm threshold) + FP_TAPCELL_DIST 8.
# Everything else kept from tc22 (DIE 1800, multi-corner resizer, hold margin 0.1, normal GRT).
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc23 -overwrite

set ::env(DIE_AREA) "0 0 1800 1800"
set ::env(CORE_AREA) "20 20 1780 1780"
set ::env(FP_SIZING) absolute
set ::env(PL_TARGET_DENSITY) 0.24

# nwell tap
set ::env(FP_TAPCELL_DIST) 8
# antenna
set ::env(RUN_HEURISTIC_DIODE_INSERTION) 1
set ::env(HEURISTIC_ANTENNA_THRESHOLD) 30
set ::env(DIODE_ON_PORTS) "in"
set ::env(GRT_REPAIR_ANTENNAS) 1
# timing (kept from tc22)
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
puts "=== TENSOR_TC23_DONE ==="
exit 0
