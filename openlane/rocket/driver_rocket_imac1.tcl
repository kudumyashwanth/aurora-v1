# imac1: FIRST harden of RV64IMAC RocketTile (FPU removed -> kills the ~34ns fpuOpt.ifpu
# critical path that failed -14.35ns multi-corner on RV64GC). Goal of THIS run = PROVE timing
# closes, so use rt13's PROVEN-clean floorplan (7000x2600, 2-row macro placement) which is the
# only Rocket floorplan that extracts SPEF clean (rt14's 4x4 grid gave DRC=1 but broke OpenRCX
# extraction -> no mcsta). DRC (nwell-fill) optimization is a SEPARATE later run once timing is
# proven. Synthesize FRESH from the IMAC RTL (config VERILOG_FILES now = rocket_rv64imac_mem_clean.v).
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/rocket/rocket_tile -tag imac1 -overwrite

# nwell.4 lever + memory safety (rt13 proven settings)
set ::env(PL_TARGET_DENSITY) 0.35
set ::env(FP_TAPCELL_DIST) 10
set ::env(ROUTING_CORES) 4
set ::env(RUN_HEURISTIC_DIODE_INSERTION) 0
set ::env(RSZ_MULTICORNER_LIB) 1
set ::env(GRT_ADJUSTMENT) 0.1
set ::env(GRT_ALLOW_CONGESTION) 0

run_synthesis
# use the clean clock-only SDC for all PnR/STA (avoids synthesis.sdc set_driving_cell STA-0574)
set ::env(CURRENT_SDC) /home/yashwanth/aurora_v1/openlane/rocket/rocket_tile/rocket_clean.sdc

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
puts "=== IMAC1_DONE ==="
exit 0
