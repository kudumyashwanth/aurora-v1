# tc14: BIASED-MET1 fix for the tc12 detailed-route met1 short-storm.
# tc12 (met1-met5): global converged (0 overflow) but detailed DIVERGED, 1.1M->1.3M shorts,
#   almost all on MET1 -- global's 40% met1 usage is a gcell-AVERAGE; locally (dense systolic
#   region) met1 was effectively over capacity on top of power rails -> detailed couldn't legalize.
# tc13 (met2-met5, met1 banned for signals): global STARVED -> GRT-0103. Too aggressive.
# tc14 = the middle path: keep met1 LEGAL but BIAS global away from it via a per-layer
#   adjustment (GRT_LAYER_ADJUSTMENTS met1=0.6 -> global may use only ~40% of met1). Global
#   still converges (met2-5 full + 40% met1) AND met1 keeps slack for detailed legalization.
#   No DRT_MIN_LAYER -> global/detailed stay consistent (both can use met1; global just prefers not).
# Routing-only change -> resume from tc12's CTS checkpoint (timing MET), skip re-synth.
# GRT_LAYER_ADJUSTMENTS order = TECH_METAL_LAYERS = li1,met1,met2,met3,met4,met5.
package require openlane

set R /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster/runs/tc12

prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc14 -overwrite

set ::env(CURRENT_DEF)             $R/tmp/cts/14-tensor_core_hard.resized.def
set ::env(CURRENT_ODB)             $R/tmp/cts/14-tensor_core_hard.resized.odb
set ::env(CURRENT_SDC)             $R/tmp/cts/14-tensor_core_hard.resized.sdc
set ::env(CURRENT_NETLIST)         $R/tmp/cts/14-tensor_core_hard.resized.nl.v
set ::env(CURRENT_POWERED_NETLIST) $R/tmp/cts/14-tensor_core_hard.resized.pnl.v

# --- THE FIX: bias global routing off met1 (keep it legal, just under-used) ---
set ::env(RT_MIN_LAYER) met1
set ::env(RT_CLOCK_MIN_LAYER) met3
set ::env(GRT_ADJUSTMENT) 0.0
set ::env(GRT_LAYER_ADJUSTMENTS) "0,0.6,0,0,0,0"

set ::env(RSZ_MULTICORNER_LIB) 0
set ::env(ROUTING_CORES) 8
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
puts "=== TENSOR_TC14_DONE ==="
exit 0
