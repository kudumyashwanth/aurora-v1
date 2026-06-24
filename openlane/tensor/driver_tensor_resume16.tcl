# tc16: resume tc15 routing with FEWER CORES to fix the OOM (not a routing failure).
# tc15 (max-spread: 3600 die, density 0.15, full met1) was WORKING: global converged (0
# overflow, no GRT-0103) and detailed routing was doing FAR better than tc12 -- 124k
# violations and PLATEAUING at 40% (vs tc12's 272k and climbing). But it got OOM-KILLED
# ("child killed: kill signal", 15.96 GB at 40%): the bigger 3600 die = more routing gcells
# = more memory, and 8 ROUTING_CORES * per-worker memory blew past the 18 GB docker cap.
# FIX: same floorplan (tc15 CTS checkpoint, timing MET wns/tns 0.00), but ROUTING_CORES 8->4
# to halve detailed-route peak memory (base DB ~6-7 GB + ~half the worker memory -> ~11-12 GB
# peak, safe under 18 GB). Routing-only -> resume from tc15's CTS checkpoint, skip re-synth.
package require openlane

set R /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster/runs/tc15

prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc16 -overwrite

set ::env(CURRENT_DEF)             $R/tmp/cts/14-tensor_core_hard.resized.def
set ::env(CURRENT_ODB)             $R/tmp/cts/14-tensor_core_hard.resized.odb
set ::env(CURRENT_SDC)             $R/tmp/cts/14-tensor_core_hard.resized.sdc
set ::env(CURRENT_NETLIST)         $R/tmp/cts/14-tensor_core_hard.resized.nl.v
set ::env(CURRENT_POWERED_NETLIST) $R/tmp/cts/14-tensor_core_hard.resized.pnl.v

set ::env(RT_MIN_LAYER) met1
set ::env(RT_CLOCK_MIN_LAYER) met3
set ::env(GRT_ADJUSTMENT) 0.0

# --- THE FIX: fewer detailed-route workers -> lower peak memory, no OOM ---
set ::env(ROUTING_CORES) 4

set ::env(RSZ_MULTICORNER_LIB) 0
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
puts "=== TENSOR_TC16_DONE ==="
exit 0
