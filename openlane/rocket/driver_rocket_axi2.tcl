# axi2: full PnR + signoff of RocketAXITileTop (AXI4-master Rocket tile) at 33.3MHz (30ns),
# reusing the axi1 synth netlist (skip ABC). Floorplan = imac33's proven-clean 7000x2600 2-row
# macro layout (the only Rocket floorplan that routes + extracts SPEF clean + LVS-clean).
# macro_placement_axitile.cfg = imac names with the wrapper prefix
# tile_prci_domain.element_reset_domain_rockettile.* (verified against the axi1 netlist).
# GOAL: detailed route 0 viol / multi-corner mcsta WNS>=0 / LVS unique / GDS.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/rocket/rocket_axitile -tag axi2 -overwrite

set ::env(CURRENT_NETLIST) /home/yashwanth/aurora_v1/openlane/rocket/rocket_axitile/runs/axi1/results/synthesis/RocketAXITileTop.v
set ::env(CURRENT_SDC) /home/yashwanth/aurora_v1/openlane/rocket/rocket_axitile/rocket_clean_33mhz.sdc
set ::env(CLOCK_PERIOD) 30.0

set ::env(PL_TARGET_DENSITY) 0.35
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
puts "=== AXI2_DONE ==="
exit 0
