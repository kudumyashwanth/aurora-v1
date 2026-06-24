# Resume ROUTING from chip_final's CTS checkpoint (0.45 density placement -- the ONLY density that
# converges RePlAce; PDN connected via halo 40 -> PDN-0110 floating straps 0; boundary power pins present).
# chip_final's first route used met1 derate 0.6 which OVER-STARVED met1 on the denser 0.45 placement
# (86.91% reduction -> 2.27M cap -> GRT-0103). FIX: gentler derate 0.3 (denser cells already consume more
# met1 base, so less layer-adjustment is needed). Routing-only resume -> fast feedback, no re-placement.
package require openlane

set R /home/yashwanth/aurora_v1/openlane/chip/runs/chip_final

prep -design /home/yashwanth/aurora_v1/openlane/chip -tag chip_route2 -overwrite

set ::env(CURRENT_DEF)             $R/results/cts/aurora_soc_top_chip.def
set ::env(CURRENT_ODB)             $R/results/cts/aurora_soc_top_chip.odb
set ::env(CURRENT_SDC)             $R/results/cts/aurora_soc_top_chip.sdc
set ::env(CURRENT_NETLIST)         $R/results/placement/aurora_soc_top_chip.nl.v
set ::env(CURRENT_POWERED_NETLIST) $R/results/placement/aurora_soc_top_chip.pnl.v

set ::env(ROUTING_CORES) 4
set ::env(RSZ_MULTICORNER_LIB) 1
set ::env(GRT_ADJUSTMENT) 0
set ::env(GRT_ALLOW_CONGESTION) 1
set ::env(GLB_RESIZER_DESIGN_OPTIMIZATIONS) 0
set ::env(GLB_RESIZER_TIMING_OPTIMIZATIONS) 0
set ::env(GRT_LAYER_ADJUSTMENTS) "0,0.3,0,0,0,0"

run_routing
run_parasitics_sta
run_magic
run_magic_drc
run_magic_spice_export
run_lvs
puts "=== CHIP_ROUTE2_LVS_DONE ==="
run_magic_antenna_check
save_final_views
generate_final_summary_report
puts "=== CHIP_ROUTE2_DONE ==="
exit 0
