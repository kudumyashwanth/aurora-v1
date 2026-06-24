# axi4: FINAL Rocket-AXI4 macro = RocketAXITileTop WITH single-beat fragmenter (de-burst in Chisel)
# + antenna diode fix folded in. Supersedes axi2 (which had bursts + 484 antenna). Fresh synth from the
# fragmenter RTL (rocket_axitile_mem_clean.v), then full PnR/signoff @30ns on imac33's proven 7000x2600
# 2-row floorplan. SRAM macro names UNCHANGED by the fragmenter (it's in the master-port chain, not the
# caches) so macro_placement_axitile.cfg still valid.
# GOAL: route 0 / mcsta WNS>=0 all corners / LVS unique / antenna ~0 / GDS = clean AXI4 Rocket macro.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/rocket/rocket_axitile -tag axi4 -overwrite

set ::env(PL_TARGET_DENSITY) 0.35
set ::env(FP_TAPCELL_DIST) 10
set ::env(ROUTING_CORES) 4
set ::env(RSZ_MULTICORNER_LIB) 1
set ::env(GRT_ADJUSTMENT) 0.1
set ::env(GRT_ALLOW_CONGESTION) 0

# antenna cleanup combo (drove tensor 4x4 antenna 102->0)
set ::env(RUN_HEURISTIC_DIODE_INSERTION) 1
set ::env(HEURISTIC_ANTENNA_THRESHOLD) 30
set ::env(DIODE_ON_PORTS) "in"
set ::env(GRT_REPAIR_ANTENNAS) 1

run_synthesis
set ::env(CURRENT_SDC) /home/yashwanth/aurora_v1/openlane/rocket/rocket_axitile/rocket_clean_33mhz.sdc

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
puts "=== AXI4_DONE ==="
exit 0
