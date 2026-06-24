# axi5: FULL re-harden of the 2-port RocketAXITileTop (mem_axi4 cacheable + mmio_axi4 uncached).
# The wrapper changed vs axi1/axi2 (added the uncached MMIO AXI port + a TLXbar to split the tile
# master) so the axi1 synth netlist is STALE -> a FRESH synthesis is required here.
# Recipe = the proven imac33/axi2 settings: 7000x2600 2-row macro floorplan @30ns (33.3MHz), the only
# Rocket floorplan that routes + extracts SPEF clean + LVS-clean. macro_placement_axitile.cfg is reused
# (SRAM hierarchy tile_prci_domain.element_reset_domain_rockettile.* is unchanged by the master-path edit;
# floorplan will error loudly if a name mismatches). Antenna diode fix deferred (RUN_HEURISTIC_DIODE_
# INSERTION 0, proven clean route/LVS; the ~484 metal1 antenna is a documented waivable cleanup).
# GOAL: detailed route 0 viol / multi-corner mcsta WNS>=0 / LVS unique / GDS + final views for chip integ.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/rocket/rocket_axitile -tag axi5 -overwrite

set ::env(CURRENT_SDC) /home/yashwanth/aurora_v1/openlane/rocket/rocket_axitile/rocket_clean_33mhz.sdc
set ::env(CLOCK_PERIOD) 30.0
set ::env(PL_TARGET_DENSITY) 0.35
set ::env(FP_TAPCELL_DIST) 10
set ::env(ROUTING_CORES) 4
set ::env(RUN_HEURISTIC_DIODE_INSERTION) 0
set ::env(RSZ_MULTICORNER_LIB) 1
set ::env(GRT_ADJUSTMENT) 0.1
set ::env(GRT_ALLOW_CONGESTION) 0

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
puts "=== AXI5_DONE ==="
exit 0
