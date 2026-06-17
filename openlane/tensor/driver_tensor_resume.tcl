# Resume tensor_core_hard routing from tc3's post-resizer-timing CTS checkpoint.
# tc3 died at step 14 (global-route design resizer) from a power loss, NOT a crash.
# tc2 had crashed at the same step inside FastRoute overflow-removal ("hard
# benchmark" path, updateRouteType1 vector-OOB assertion). To avoid re-triggering
# that, give the router maximum resources (GRT_ADJUSTMENT 0) AND let it accept
# residual congestion instead of escalating into the buggy overflow path
# (GRT_ALLOW_CONGESTION 1). Same RAM discipline (single-corner resizer, 8 cores).
package require openlane

set R /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster/runs/tc3

prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc4 -overwrite

set ::env(CURRENT_DEF)             $R/tmp/cts/13-tensor_core_hard.resized.def
set ::env(CURRENT_ODB)             $R/tmp/cts/13-tensor_core_hard.resized.odb
set ::env(CURRENT_SDC)             $R/tmp/cts/13-tensor_core_hard.resized.sdc
set ::env(CURRENT_NETLIST)         $R/tmp/cts/13-tensor_core_hard.resized.nl.v
set ::env(CURRENT_POWERED_NETLIST) $R/tmp/cts/13-tensor_core_hard.resized.pnl.v

# RAM safety
set ::env(RSZ_MULTICORNER_LIB) 0
set ::env(ROUTING_CORES) 8

# Avoid the FastRoute overflow-removal crash: max tracks + tolerate residual overflow.
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
puts "=== TENSOR_TC4_DONE ==="
exit 0
