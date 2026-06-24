# tc10: resume routing from tc9's post-CTS-resizer checkpoint after power-loss #2.
# tc9 (8x8 SIZE=8, 64-MAC) completed synth->floorplan->placement->CTS->resizer_timing
# (timing MET, WNS/TNS 0.00) and died mid global-route (GRT-0101 overflow iterations)
# when the laptop shut down. Clean checkpoint: runs/tc9/tmp/cts/15-*.resized.{def,odb,
# nl.v,pnl.v,sdc}. Re-enter at routing only -> saves the ~30-40min re-synth.
# Same safety flags as tc9: skip the two looping global-route resizers, let FastRoute
# accept residual congestion (GRT_ALLOW_CONGESTION 1). 8x8 = 110k cells < the 197k
# RocketTile that signed off clean, so routing is expected to converge here.
package require openlane

set R /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster/runs/tc9

prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc10 -overwrite

set ::env(CURRENT_DEF)             $R/tmp/cts/15-tensor_core_hard.resized.def
set ::env(CURRENT_ODB)             $R/tmp/cts/15-tensor_core_hard.resized.odb
set ::env(CURRENT_SDC)             $R/tmp/cts/15-tensor_core_hard.resized.sdc
set ::env(CURRENT_NETLIST)         $R/tmp/cts/15-tensor_core_hard.resized.nl.v
set ::env(CURRENT_POWERED_NETLIST) $R/tmp/cts/15-tensor_core_hard.resized.pnl.v

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
puts "=== TENSOR_TC10_DONE ==="
exit 0
