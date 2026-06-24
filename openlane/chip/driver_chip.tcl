# driver_chip.tcl — full-chip Aurora v1 SoC PnR: aurora_soc_top_chip
#   = RocketAXITileTop macro (axi5, 7000x2600 @ bottom) + tensor_core_hard macro (tc23, 1800x1800)
#     + std-cell glue (crossbar/CDC/wrapper/boot_rom/sram/uart/gpio/timer/irq), single 33MHz clock.
# Die 7500x5500. Both macros placed via macro_placement_chip.cfg; PDN hooks both VPWR/VGND.
# Safety: launch via run_chip.sh -> docker --memory=18g --memory-swap=20g (never freeze the host).
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/chip -tag chip1 -overwrite

set ::env(CLOCK_PERIOD) 30.0
set ::env(PL_TARGET_DENSITY) 0.30
set ::env(FP_TAPCELL_DIST) 10
set ::env(ROUTING_CORES) 4
set ::env(RSZ_MULTICORNER_LIB) 1
set ::env(RUN_HEURISTIC_DIODE_INSERTION) 0
# Skip the global-route-driven resizers: on this macro-heavy chip they hit GRT-0232 (congestion
# too high) and never let TritonRoute run. Timing is already met at CTS; let the robust detailed
# router route it with congestion relief (proven recipe from the tensor/Rocket macro runs).
set ::env(GLB_RESIZER_DESIGN_OPTIMIZATIONS) 0
set ::env(GLB_RESIZER_TIMING_OPTIMIZATIONS) 0
set ::env(GRT_ADJUSTMENT) 0
set ::env(GRT_ALLOW_CONGESTION) 1

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
puts "=== CHIP1_DONE ==="
exit 0
