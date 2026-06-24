# Resume chip routing from chip1's post-resizer CTS checkpoint. THIRD attempt.
# chip_rt  (met1 legal, no relief): detailed route was CONVERGING (438k->306k met1 shorts) but host
#          died mid-iteration. Slow.
# chip_rt2 (RT_MIN_LAYER met2 hard ban): FAILED with DRT-0155 -- std-cell pins are physically on met1,
#          so a hard met1 ban always leaves a met1 pin-access guide that TritonRoute rejects. WRONG lever.
# chip_rt3 (THIS): keep met1 LEGAL (no DRT-0155) but SOFT-DERATE met1 via GRT_LAYER_ADJUSTMENTS so global
#          biases signals up to met2/met3, thinning the met1 demand that causes the local short-storm.
#          SAFE: global has huge headroom (met1 demand 2.18M of 7.85M = 28%; derate 0.6 -> cap 3.14M still
#          > demand), so this will NOT starve global into GRT-0103 (unlike the congestion-bound tile tc14).
#          Strictly better than bare chip_rt: detailed route starts with far fewer met1 conflicts.
package require openlane

set R /home/yashwanth/aurora_v1/openlane/chip/runs/chip1

prep -design /home/yashwanth/aurora_v1/openlane/chip -tag chip_rt3 -overwrite

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

# Soft met1 relief: derate met1 routing resources 60% so global routes signals on met2+ where possible,
# while met1 stays LEGAL for pin access + the residual. Order: li1,met1,met2,met3,met4,met5.
set ::env(GRT_LAYER_ADJUSTMENTS) "0,0.6,0,0,0,0"

run_routing
run_parasitics_sta
run_magic
run_magic_drc
run_magic_spice_export
run_lvs
run_magic_antenna_check
save_final_views
generate_final_summary_report
puts "=== CHIP_RT3_DONE ==="
exit 0
