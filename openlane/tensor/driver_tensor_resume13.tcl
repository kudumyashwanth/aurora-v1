# tc13: resume routing from tc12's post-CTS-resizer checkpoint with the met1 fix.
# tc12 (8x8 flop-buffer, pure std-cell, no macros) BROKE the global-route wall:
# global routing CONVERGED with 0 overflow on every layer. BUT detailed routing
# DIVERGED -- 1.1M -> 1.3M shorts, growing each iteration, overwhelmingly on MET1
# (651k->771k) then met2. Root cause = met1 short-storm: met1 is consumed by std-cell
# power rails, and the dense systolic pin pattern leaves no room for signal routing on
# met1. Global is clean (gcell-average) but detailed can't legalize met1 locally.
# FIX: raise the signal min routing layer met1 -> met2 (RT_MIN_LAYER). Frees met1 for
# power/pins; signals route on met2-met5 which have ample headroom (global usage 28-44%).
# Routing-only change -> reuse tc12's CTS checkpoint (timing already MET), skip re-synth.
package require openlane

set R /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster/runs/tc12

prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc13 -overwrite

set ::env(CURRENT_DEF)             $R/tmp/cts/14-tensor_core_hard.resized.def
set ::env(CURRENT_ODB)             $R/tmp/cts/14-tensor_core_hard.resized.odb
set ::env(CURRENT_SDC)             $R/tmp/cts/14-tensor_core_hard.resized.sdc
set ::env(CURRENT_NETLIST)         $R/tmp/cts/14-tensor_core_hard.resized.nl.v
set ::env(CURRENT_POWERED_NETLIST) $R/tmp/cts/14-tensor_core_hard.resized.pnl.v

# --- THE FIX: signals avoid met1 (power-rail layer) -> kills the met1 short-storm ---
set ::env(RT_MIN_LAYER) met2
set ::env(RT_CLOCK_MIN_LAYER) met3

set ::env(RSZ_MULTICORNER_LIB) 0
set ::env(ROUTING_CORES) 8
set ::env(GRT_ADJUSTMENT) 0.0
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
puts "=== TENSOR_TC13_DONE ==="
exit 0
