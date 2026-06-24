# asys1: synthesis ONLY of RocketAXISystem (minimal subsystem: tile + CLINT/PLIC/debug/bootrom +
# mem/mmio AXI, correct PMA, reset vector 0x80000000). Get cell count + the 16 SRAM macro instance
# names (new subsystem hierarchy) -> then write macro cfg + full PnR (asys2). imac33 settings.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/rocket/rocket_axisys -tag asys1 -overwrite
set ::env(PL_TARGET_DENSITY) 0.30
set ::env(FP_TAPCELL_DIST) 10
set ::env(ROUTING_CORES) 4
set ::env(RSZ_MULTICORNER_LIB) 1
set ::env(GRT_ADJUSTMENT) 0.1
set ::env(GRT_ALLOW_CONGESTION) 0
run_synthesis
puts "=== ASYS1_SYNTH_DONE ==="
exit 0
