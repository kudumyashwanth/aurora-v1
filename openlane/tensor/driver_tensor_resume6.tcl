# tc6: resume ROUTING from tc5's good CTS checkpoint (right-sized 4200 die, centered
# 2x2 macros, CTS timing MET). The improved floorplan cut HPWL ~23% but GRT with
# ALLOW_CONGESTION 0 still spun forever chasing zero overflow on the dense 256-MAC
# systolic datapath (same wall as tc4). Remedy: GRT_ALLOW_CONGESTION 1 so FastRoute
# accepts residual overflow and hands to detailed routing (TritonRoute) — on this
# better floorplan the residual congestion should be small enough to route clean.
package require openlane

set R /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster/runs/tc5

prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc6 -overwrite

set ::env(CURRENT_DEF)             $R/tmp/cts/13-tensor_core_hard.resized.def
set ::env(CURRENT_ODB)             $R/tmp/cts/13-tensor_core_hard.resized.odb
set ::env(CURRENT_SDC)             $R/tmp/cts/13-tensor_core_hard.resized.sdc
set ::env(CURRENT_NETLIST)         $R/tmp/cts/13-tensor_core_hard.resized.nl.v
set ::env(CURRENT_POWERED_NETLIST) $R/tmp/cts/13-tensor_core_hard.resized.pnl.v

set ::env(RSZ_MULTICORNER_LIB) 0
set ::env(ROUTING_CORES) 8
set ::env(GRT_ADJUSTMENT) 0.0
set ::env(GRT_ALLOW_CONGESTION) 1

run_routing
run_parasitics_sta
run_magic
run_magic_drc
run_magic_spice_export
run_lvs
run_magic_antenna_check
save_final_views
generate_final_summary_report
puts "=== TENSOR_TC6_DONE ==="
exit 0
