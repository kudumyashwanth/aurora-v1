# tc12: ROOT-CAUSE FIX for the tc2-tc11 global-route congestion wall.
# Diagnosis (from tc11's 16-global.log): GRT-0004 "Blockages: 73302" + met1 26% derated.
# The 4 SRAM macros (8KB buffer) are the congestion source -- yet the 8x8 tile only ever
# uses ~2 buffer words. FIX: tensor_local_buffer is now the behavioral FLOP buffer at
# BUFFER_DEPTH=16 (sv2v regenerated, no sky130_sram macro). Block is now PURE STD-CELL:
# zero macro blockages, no macro-corner congestion pull -> FastRoute should clear overflow
# and reach detailed routing -> DRC/LVS/GDS. Real SRAM returns at full 16x16/4-tile scale.
# Floorplan: DIE 2800 (placement/CTS already proven there in tc9), density 0.30, PDN 360
# (frees met1). No MACRO_PLACEMENT_CFG / FP_PDN_MACRO_HOOKS (no macros).
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc12 -overwrite

set ::env(DIE_AREA) "0 0 2800 2800"
set ::env(FP_SIZING) absolute
set ::env(PL_TARGET_DENSITY) 0.30

# --- proven safety flags (still harmless; should not be needed without macros) ---
set ::env(RSZ_MULTICORNER_LIB) 0
set ::env(ROUTING_CORES) 8
set ::env(GRT_ADJUSTMENT) 0.0
set ::env(GRT_ALLOW_CONGESTION) 1
set ::env(GLB_RESIZER_DESIGN_OPTIMIZATIONS) 0
set ::env(GLB_RESIZER_TIMING_OPTIMIZATIONS) 0

run_synthesis
run_floorplan
run_placement
run_cts
run_resizer_timing
run_routing
run_parasitics_sta
run_magic
run_magic_drc
run_magic_spice_export
run_lvs
run_magic_antenna_check
save_final_views
generate_final_summary_report
puts "=== TENSOR_TC12_DONE ==="
exit 0
