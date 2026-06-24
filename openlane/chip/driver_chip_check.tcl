# driver_chip_check.tcl — FAST validation of the chip config before the multi-hour full run.
# Runs synthesis (blackbox port match, sv2v read, unmapped-cell check) + floorplan (macro
# placement coords, PDN macro hooks) + global placement. Stops before CTS/routing.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/chip -tag chk1 -overwrite
set ::env(CLOCK_PERIOD) 30.0
set ::env(PL_TARGET_DENSITY) 0.30
set ::env(FP_TAPCELL_DIST) 10
set ::env(ROUTING_CORES) 4
run_synthesis
run_floorplan
run_placement
puts "=== CHIP_CHECK_DONE ==="
exit 0
