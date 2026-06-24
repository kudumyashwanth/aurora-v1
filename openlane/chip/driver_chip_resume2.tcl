# Resume chip routing from chip1's post-resizer CTS checkpoint (timing already optimized at CTS),
# skipping re-synthesis/FP/placement/CTS. chip_rt routed but DETAILED route hit a LOCAL met1
# short-storm (336k met1 shorts; global route was CLEAN -- met1 only 27.76% used, ZERO overflow on
# all layers). The storm is local: signals can't fit on met1 alongside std-cell power rails in the
# dense glue/macro-pin regions. FIX: push signal routing up to met2 (RT_MIN_LAYER met2), leaving
# met1 for power rails + pin escapes. Global has ample met2/met3 headroom (28%/5%) to absorb the
# shifted demand, so unlike the congestion-bound tile tc13 this will NOT starve global routing.
package require openlane

set R /home/yashwanth/aurora_v1/openlane/chip/runs/chip1

prep -design /home/yashwanth/aurora_v1/openlane/chip -tag chip_rt2 -overwrite

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

# Local met1 short-storm fix: route signals on met2+, clock on met3+ (met1 = power rails + pin escape)
set ::env(RT_MIN_LAYER) met2
set ::env(RT_CLOCK_MIN_LAYER) met3

run_routing
run_parasitics_sta
run_magic
run_magic_drc
run_magic_spice_export
run_lvs
run_magic_antenna_check
save_final_views
generate_final_summary_report
puts "=== CHIP_RT2_DONE ==="
exit 0
