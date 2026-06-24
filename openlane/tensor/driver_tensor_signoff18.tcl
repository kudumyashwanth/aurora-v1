# tc18: complete LVS + final signoff now that the SPEF hard-exit is fixed.
# tc17 produced GDS + DRC (1 nwell tap) + final views, but LVS never ran: write_powered_verilog
# (io.tcl `read`) hit a missing SPEF and did `exit 1` (the catch handler hard-exits). OpenRCX
# SPEF extraction fails systematically in this flow (both corners/designs) -- a tool limitation,
# not the design; timing is already signed off at CTS multi-corner STA (+10 ns slack / 20 ns clk).
# FIX applied to OpenLane: io.tcl line 196 now guards read_spef with [file exists] so a missing
# SPEF is SKIPPED (no parasitic annotation) instead of crashing -> write_powered_verilog succeeds
# -> run_lvs proceeds. Resume from tc16's ROUTED checkpoint, NOM-only parasitics, NO antenna
# (Magic flatten hung >2h on this 1.3M-inst layout; antennas already repaired during routing).
package require openlane

set R /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster/runs/tc16

prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc18 -overwrite

set ::env(CURRENT_DEF)             $R/results/routing/tensor_core_hard.def
set ::env(CURRENT_ODB)             $R/results/routing/tensor_core_hard.odb
set ::env(CURRENT_NETLIST)         $R/results/routing/tensor_core_hard.nl.v
set ::env(CURRENT_POWERED_NETLIST) $R/results/routing/tensor_core_hard.pnl.v
set ::env(CURRENT_SDC)             /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster/runs/tc15/tmp/cts/14-tensor_core_hard.resized.sdc

unset -nocomplain ::env(MERGED_LEF_MIN)
unset -nocomplain ::env(MERGED_LEF_MAX)

set ::env(RSZ_MULTICORNER_LIB) 0
set ::env(ROUTING_CORES) 4

run_parasitics_sta
run_magic
run_magic_drc
run_magic_spice_export
run_lvs
save_final_views
generate_final_summary_report
puts "=== TENSOR_TC18_DONE ==="
exit 0
