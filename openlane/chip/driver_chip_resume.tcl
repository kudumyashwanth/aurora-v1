# Resume chip routing from chip1's post-resizer CTS checkpoint (timing already optimized at CTS),
# skipping re-synthesis/FP/placement/CTS. The first full run (chip1) reached CTS fine but its
# global-route resizer hit GRT-0232 (congestion too high) and aborted -> SPEF/STA/Magic then ran on
# an unrouted design (garbage). FIX: skip the two GLB_RESIZER global-route optimizations and let
# TritonRoute route with congestion relief (GRT_ALLOW_CONGESTION 1) -- proven recipe from the
# tensor/Rocket macro runs. Routing-only resume so each attempt is fast.
package require openlane

set R /home/yashwanth/aurora_v1/openlane/chip/runs/chip1

prep -design /home/yashwanth/aurora_v1/openlane/chip -tag chip_rt -overwrite

set ::env(CURRENT_DEF)             $R/tmp/cts/15-aurora_soc_top_chip.resized.def
set ::env(CURRENT_ODB)             $R/tmp/cts/15-aurora_soc_top_chip.resized.odb
set ::env(CURRENT_SDC)             $R/tmp/cts/15-aurora_soc_top_chip.resized.sdc
set ::env(CURRENT_NETLIST)         $R/tmp/cts/15-aurora_soc_top_chip.resized.nl.v
set ::env(CURRENT_POWERED_NETLIST) $R/tmp/cts/15-aurora_soc_top_chip.resized.pnl.v

set ::env(ROUTING_CORES) 4
set ::env(RSZ_MULTICORNER_LIB) 1
set ::env(GRT_ADJUSTMENT) 0
set ::env(GRT_ALLOW_CONGESTION) 1
set ::env(GLB_RESIZER_DESIGN_OPTIMIZATIONS) 0
set ::env(GLB_RESIZER_TIMING_OPTIMIZATIONS) 0

run_routing
run_parasitics_sta
run_magic
run_magic_drc
run_magic_spice_export
run_lvs
run_magic_antenna_check
save_final_views
generate_final_summary_report
puts "=== CHIP_RT_DONE ==="
exit 0
