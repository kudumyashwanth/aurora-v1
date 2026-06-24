# axi1: synthesis ONLY of RocketAXITileTop (Rocket RV64IMAC tile re-wrapped with a clean AXI4
# master via TLCacheCork+TLToAXI4). Goal of THIS run = produce the synth netlist + let us extract
# the 16 SRAM macro instance names (the wrapper adds a hierarchy prefix
# tile_prci_domain.element_reset_domain_rockettile.* over the imac names), then write the new
# macro_placement cfg and do full PnR (axi2) reusing this netlist. Same proven imac33 settings.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/rocket/rocket_axitile -tag axi1 -overwrite

set ::env(PL_TARGET_DENSITY) 0.35
set ::env(FP_TAPCELL_DIST) 10
set ::env(ROUTING_CORES) 4
set ::env(RUN_HEURISTIC_DIODE_INSERTION) 0
set ::env(RSZ_MULTICORNER_LIB) 1
set ::env(GRT_ADJUSTMENT) 0.1
set ::env(GRT_ALLOW_CONGESTION) 0

run_synthesis
puts "=== AXI1_SYNTH_DONE ==="
exit 0
