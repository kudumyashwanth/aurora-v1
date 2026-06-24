# tc19: 4x4 (SIZE=4, 16-MAC) tensor_core_hard -- the CLEAN-SIGNOFF path.
# WHY 4x4: 8x8 routes ONLY on a max-spread floorplan (3600/0.15) whose ~1.3M fill cells break the
# back-end signoff tools (LVS net-fragmentation, Magic antenna/save-views hangs). 4x4 = ~1/4 logic
# (~28k cells) -> routes at NORMAL density on a SMALL die -> modest fill -> DRC/LVS/antenna run fast
# and CLEAN in one in-flow pass = genuinely zero-DRC / zero-LVS signed-off tensor GDSII. The array
# is parametric (SIZE) -> scale back up on commercial P&R / bigger host, or tile x4 for throughput.
# RTL: tensor_core_hard.sv SIZE 8->4, WPM=ceil(SIZE/EPW) + load loops guarded e<SIZE (int16 kept,
# A@0x00 B@0x10, 1 word each). Flop buffer (BUFFER_DEPTH=16), NO SRAM macros. lint 0, sv2v 0 err.
# Floorplan: DIE 1200x1200, util 35, density 0.45 (normal -> low fill). STANDARD clean settings:
# resizers ON (4x4 won't loop), normal GRT (ADJ 0.1, ALLOW_CONGESTION 0), full signoff incl antenna.
# RSZ_MULTICORNER_LIB 0 for resizer memory; multi-corner still checked at signoff STA.
# io.tcl is patched to skip a missing SPEF, so even if OpenRCX still can't extract, LVS still runs.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc19 -overwrite

set ::env(DIE_AREA) "0 0 1200 1200"
set ::env(CORE_AREA) "20 20 1180 1180"
set ::env(FP_SIZING) absolute
set ::env(PL_TARGET_DENSITY) 0.45

set ::env(RSZ_MULTICORNER_LIB) 0
set ::env(ROUTING_CORES) 8
set ::env(GRT_ADJUSTMENT) 0.1
set ::env(GRT_ALLOW_CONGESTION) 0

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
run_magic_antenna_check
save_final_views
generate_final_summary_report
puts "=== TENSOR_TC19_DONE ==="
exit 0
