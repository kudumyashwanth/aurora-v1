# tc20: 4x4 at MODERATE density -- the met1 sweet spot for a CLEAN signoff.
# tc19 (4x4, DIE 1200 / density 0.45): detailed routing CONVERGED but PLATEAUED at ~57k violations
# (~40k met1 shorts) -- 0.45 is too dense, met1 (power rails + signal) over capacity locally.
# tc20: spread the cells for met1 relief WITHOUT the 8x8's fill explosion. DIE 1200->1800,
# PL_TARGET_DENSITY 0.45->0.20. 4x4 has ~1/4 the wiring of 8x8 (which cleared met1 only at 0.15),
# so 0.20 should clear met1 here. Fill ~350k instances (vs the 8x8's 1.3M that hung the back-end)
# -> DRC/LVS/antenna still run fast/clean. Standard flow: resizers ON (4x4 won't loop), normal GRT.
# 29537 cells (291810 um2) confirmed at SIZE=4. Flop buffer, no SRAM macros. io.tcl SPEF-skip patch
# in place as safety net (OpenRCX may now extract OK at this small scale -> real multi-corner STA).
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc20 -overwrite

set ::env(DIE_AREA) "0 0 1800 1800"
set ::env(CORE_AREA) "20 20 1780 1780"
set ::env(FP_SIZING) absolute
set ::env(PL_TARGET_DENSITY) 0.20

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
puts "=== TENSOR_TC20_DONE ==="
exit 0
