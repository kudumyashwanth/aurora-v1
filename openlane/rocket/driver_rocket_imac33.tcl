# imac33: RV64IMAC RocketTile at 33.3MHz (30ns) -- CLOSES the divider path (28.94ns single-cycle
# MulDiv iteration that missed 50MHz by -5.44ns). User chose IMAC@33MHz (keep full integer CPU, soft
# float, slower CPU clock domain) over restoring the FPU. CPU runs in its own 33MHz domain; tensor +
# fabric stay 50MHz (multi-clock SoC, axi_cdc_bridge at CPU port). Reuse imac1 synth netlist (gates are
# fine; only the clock target changes) -> skip ABC. Floorplan = rt13 proven-clean 7000x2600 (extracts
# SPEF clean -> real mcsta). GOAL: multi-corner mcsta WNS >= 0 at 30ns.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/rocket/rocket_tile -tag imac33 -overwrite

set ::env(CURRENT_NETLIST) /home/yashwanth/aurora_ip_releases/rocket_netlist_safe/RocketTile.synth.imac1.v
set ::env(CURRENT_SDC) /home/yashwanth/aurora_v1/openlane/rocket/rocket_tile/rocket_clean_33mhz.sdc
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
puts "=== IMAC33_DONE ==="
exit 0
