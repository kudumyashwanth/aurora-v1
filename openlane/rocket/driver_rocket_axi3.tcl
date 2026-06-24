# axi3: ANTENNA-CLEAN rerun of RocketAXITileTop. axi2 was route/timing/LVS clean but had 484 metal1
# antenna violations (no diode shot taken). Reuse axi1 synth netlist + axi2's proven 7000x2600 floorplan,
# add the diode-insertion combo that drove the tensor 4x4 antenna 102->0. Everything else identical to axi2.
# GOAL: antenna -> ~0 while keeping route 0 / mcsta WNS>=0 / LVS unique. WATCH: dense diodes can congest/
# OOM on this 23GB host (memory: FP_TAPCELL_DIST 6 OOM'd) -- heuristic-diode is lighter, should be fine.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/rocket/rocket_axitile -tag axi3 -overwrite

set ::env(CURRENT_NETLIST) /home/yashwanth/aurora_v1/openlane/rocket/rocket_axitile/runs/axi1/results/synthesis/RocketAXITileTop.v
set ::env(CURRENT_SDC) /home/yashwanth/aurora_v1/openlane/rocket/rocket_axitile/rocket_clean_33mhz.sdc
set ::env(CLOCK_PERIOD) 30.0

set ::env(PL_TARGET_DENSITY) 0.35
set ::env(FP_TAPCELL_DIST) 10
set ::env(ROUTING_CORES) 4
set ::env(RSZ_MULTICORNER_LIB) 1
set ::env(GRT_ADJUSTMENT) 0.1
set ::env(GRT_ALLOW_CONGESTION) 0

# antenna cleanup knobs (the tensor 102->0 combo)
set ::env(RUN_HEURISTIC_DIODE_INSERTION) 1
set ::env(HEURISTIC_ANTENNA_THRESHOLD) 30
set ::env(DIODE_ON_PORTS) "in"
set ::env(GRT_REPAIR_ANTENNAS) 1

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
puts "=== AXI3_DONE ==="
exit 0
