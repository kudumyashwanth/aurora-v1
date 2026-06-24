# imac3: DRC SHOT for RV64IMAC @33MHz. imac33 is functionally signed off (route0/timing-MET/LVS clean)
# but Magic DRC = 9504 nwell.4 decap-fill artifact on the 7000x2600 floorplan. rt14 proved a SQUARE die
# + centered macro grid drives nwell.4 -> ~1 (RV64GC), but rt14's SPARSE 4300/0.30 BROKE SPEF extraction.
# So: smaller SQUARE die (3500) at HIGHER density (0.40) for the ~110k IMAC core -> less decap fill (fewer
# nwell.4) AND dense enough to extract clean. 16 SRAM macros in a centered 4x4 grid, pin-facing row pairs
# (macro_placement_imac3.cfg). Reuse imac1 netlist + 30ns SDC (timing already proven). GOAL: route0 /
# LVS unique / mcsta WNS>=0 / DRC <<9504. If extraction breaks (0 rc segs) or LVS mismatches -> imac33 keeps.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/rocket/rocket_tile -tag imac3 -overwrite

set ::env(CURRENT_NETLIST) /home/yashwanth/aurora_ip_releases/rocket_netlist_safe/RocketTile.synth.imac1.v
set ::env(CURRENT_SDC) /home/yashwanth/aurora_v1/openlane/rocket/rocket_tile/rocket_clean_33mhz.sdc
set ::env(CLOCK_PERIOD) 30.0

# SQUARE floorplan + centered 4x4 macro grid (the DRC lever)
set ::env(DIE_AREA) "0 0 4000 4000"
set ::env(CORE_AREA) "20 20 3980 3980"
set ::env(MACRO_PLACEMENT_CFG) /home/yashwanth/aurora_v1/openlane/rocket/rocket_tile/macro_placement_imac3.cfg
set ::env(PL_TARGET_DENSITY) 0.33
set ::env(FP_TAPCELL_DIST) 10

set ::env(ROUTING_CORES) 4
set ::env(RUN_HEURISTIC_DIODE_INSERTION) 0
set ::env(RSZ_MULTICORNER_LIB) 1
set ::env(GRT_ADJUSTMENT) 0.1
set ::env(GRT_ALLOW_CONGESTION) 0

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
puts "=== IMAC2_DONE ==="
exit 0
