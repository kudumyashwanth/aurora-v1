# FULL chip flow on the CLEAN-LVS config validated by chip_pdnck (synth+FP+placement passed):
#   FP_PDN_CHECK_NODES=0 (boundary pins) + FP_PDN_HORIZONTAL/VERTICAL_HALO=40 (straps OFF the tensor ->
#   PDN-0110 floating-strap warnings 980->0 -> power net CONNECTS as one -> LVS won't fragment) +
#   PL_TARGET_DENSITY 0.45 (RePlAce CONVERGES; diverged at 0.30 with the PDN present). 5500 die, orig macros.
# Routing recipe = proven chip_rt3: met1 soft derate + GLB_RESIZER skip + GRT_ALLOW_CONGESTION 1 + 4 cores.
# Target: signed-off full-chip GDSII -- route -> SPEF/STA (MET) -> DRC -> LVS "Circuits match uniquely".
package require openlane

prep -design /home/yashwanth/aurora_v1/openlane/chip -tag chip_final -overwrite

set ::env(ROUTING_CORES) 4
set ::env(RSZ_MULTICORNER_LIB) 1
set ::env(GRT_ADJUSTMENT) 0
set ::env(GRT_ALLOW_CONGESTION) 1
set ::env(GLB_RESIZER_DESIGN_OPTIMIZATIONS) 0
set ::env(GLB_RESIZER_TIMING_OPTIMIZATIONS) 0
set ::env(GRT_LAYER_ADJUSTMENTS) "0,0.6,0,0,0,0"

run_synthesis
run_floorplan
run_placement
run_cts
run_routing
run_parasitics_sta
run_magic
run_magic_drc
run_magic_spice_export
run_lvs
puts "=== CHIP_FINAL_LVS_DONE ==="
run_magic_antenna_check
save_final_views
generate_final_summary_report
puts "=== CHIP_FINAL_DONE ==="
exit 0
