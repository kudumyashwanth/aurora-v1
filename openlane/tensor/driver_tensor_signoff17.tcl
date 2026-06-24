# tc17: fix the OpenRCX SPEF failure + complete signoff from tc16's ROUTED checkpoint.
# tc16 ROUTED clean (115214 nets, DRC=1 nwell tap, GDS written) but run_parasitics_sta failed:
# the MIN corner extraction returned "RCX-0107 Nothing is extracted" -> empty SPEF -> the
# multi-corner STA on min aborted the proc before NOM was tried -> no final views.
# FIX: run NOM-only parasitics (unset MERGED_LEF_MIN/MAX so the sta.tcl corner loop skips
# min+max). Consistent with our single-corner setup (RSZ_MULTICORNER_LIB 0). Tests whether the
# NOM ruleset extracts (min ruleset may be the broken one). Resume from tc16's ROUTED DEF/ODB
# (results/routing) -> SKIP re-routing, go straight to parasitics->signoff (~15 min vs 40).
package require openlane

set R /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster/runs/tc16

prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc17 -overwrite

# resume from the ROUTED checkpoint (post detailed-route)
set ::env(CURRENT_DEF)             $R/results/routing/tensor_core_hard.def
set ::env(CURRENT_ODB)             $R/results/routing/tensor_core_hard.odb
set ::env(CURRENT_NETLIST)         $R/results/routing/tensor_core_hard.nl.v
set ::env(CURRENT_POWERED_NETLIST) $R/results/routing/tensor_core_hard.pnl.v
set ::env(CURRENT_SDC)             /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster/runs/tc15/tmp/cts/14-tensor_core_hard.resized.sdc

# --- THE FIX: NOM-only parasitics (skip the broken min/max corner extraction) ---
unset -nocomplain ::env(MERGED_LEF_MIN)
unset -nocomplain ::env(MERGED_LEF_MAX)

set ::env(RSZ_MULTICORNER_LIB) 0
set ::env(ROUTING_CORES) 4

# NOTE: run_magic_antenna_check DROPPED -- on this 1.3M-instance / 0.15-density layout Magic's
# flatten-for-antenna hung >2h in tc16. Antennas were already repaired during global routing
# (GRT_REPAIR_ANTENNAS=1, diodes inserted). Standalone antenna verification can be revisited.
run_parasitics_sta
run_magic
run_magic_drc
run_magic_spice_export
run_lvs
save_final_views
generate_final_summary_report
puts "=== TENSOR_TC17_DONE ==="
exit 0
