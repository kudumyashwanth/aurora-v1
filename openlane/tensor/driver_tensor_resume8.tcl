# tc8: resume routing from tc7's CTS checkpoint, but SKIP the two global-route-driven
# resizers that loop forever on this congested 256-MAC datapath.
# run_routing calls: resizer_design (GLB_RESIZER_DESIGN_OPTIMIZATIONS) ->
# resizer_timing (GLB_RESIZER_TIMING_OPTIMIZATIONS) -> global_routing -> detailed_routing.
# The two resizers iterate resize->reroute on a congested global route and never
# converge (tc6/tc7 each spun >1h CPU). They are optional post-CTS polish; timing is
# already MET at CTS (+0.00 WNS). Disable both -> flow goes straight to a single bounded
# FastRoute global route (GRT_ALLOW_CONGESTION 1 accepts residual overflow) then
# TritonRoute detailed routing, which is far more robust than FastRoute's overflow loop.
# This gets us a real routed DEF + DRV count.
package require openlane

set R /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster/runs/tc7

prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc8 -overwrite

set ::env(CURRENT_DEF)             $R/tmp/cts/13-tensor_core_hard.resized.def
set ::env(CURRENT_ODB)             $R/tmp/cts/13-tensor_core_hard.resized.odb
set ::env(CURRENT_SDC)             $R/tmp/cts/13-tensor_core_hard.resized.sdc
set ::env(CURRENT_NETLIST)         $R/tmp/cts/13-tensor_core_hard.resized.nl.v
set ::env(CURRENT_POWERED_NETLIST) $R/tmp/cts/13-tensor_core_hard.resized.pnl.v

set ::env(RSZ_MULTICORNER_LIB) 0
set ::env(ROUTING_CORES) 8
set ::env(GRT_ADJUSTMENT) 0.0
set ::env(GRT_ALLOW_CONGESTION) 1

# Skip the looping global-route resizers; go straight to global + detailed routing.
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
puts "=== TENSOR_TC8_DONE ==="
exit 0
