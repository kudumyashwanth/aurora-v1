# rt14: SQUARER-DIE re-harden to CLOSE MULTI-CORNER TIMING.
# ROOT CAUSE of rt13's failure (found 2026-06-20): rt13 reported "wns 0.00" only at SINGLE-corner
# STA; the MULTI-corner post-route SPEF STA (29/31-rcx_mcsta) is WNS -14.35 ns / 1027 violated
# setup endpoints. The 7000x2600 die (2.7:1 aspect) stretches the clock tree (capture clock
# reaches flops at 20-37 ns) -> real routed parasitics blow setup at multi-corner. Resizers
# (RSZ_MULTICORNER_LIB 1) ran but can't fix a floorplan-induced clock-tree problem.
# FIX: square ~4300x4300 die (same ~18.5M um2 area, ~1:1 aspect) + 16 SRAMs regridded from a
# 2x8 wide strip into a CENTERED 4x4 array (macro_placement_rt14.cfg) -> clock source reaches all
# logic within ~half the span -> shorter clock tree, less skew -> multi-corner setup should close.
# Reuse the rt12 synth netlist (layout-independent) -> skip ~50min ABC re-synth. Keep RSZ_MULTI
# CORNER_LIB 1 so the timing resizer optimizes against the corners that were failing.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/rocket/rocket_tile -tag rt14 -overwrite

# reuse synthesized gate netlist + clean SDC (same as rt13)
set ::env(CURRENT_NETLIST) /home/yashwanth/aurora_ip_releases/rocket_netlist_safe/RocketTile.synth.rt12.v
set ::env(CURRENT_SDC) /home/yashwanth/aurora_v1/openlane/rocket/rocket_tile/rocket_clean.sdc

# --- SQUARE floorplan (the timing fix) ---
set ::env(DIE_AREA) "0 0 4300 4300"
set ::env(CORE_AREA) "20 20 4280 4280"
set ::env(MACRO_PLACEMENT_CFG) /home/yashwanth/aurora_v1/openlane/rocket/rocket_tile/macro_placement_rt14.cfg
set ::env(PL_TARGET_DENSITY) 0.30
set ::env(FP_TAPCELL_DIST) 10

# --- timing closure: optimize against multi-corner (the failing analysis) ---
set ::env(RSZ_MULTICORNER_LIB) 1

# --- memory / routing safety (rt12 OOM'd from heuristic diodes, not these) ---
set ::env(ROUTING_CORES) 4
set ::env(RUN_HEURISTIC_DIODE_INSERTION) 0
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
puts "=== RT14_DONE ==="
exit 0
