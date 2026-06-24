# rt12: clean up RocketTile DRC (route + LVS already clean in rt11).
# rt11 state: detailed route 0 violations, LVS "Circuits match uniquely", but 9512 Magic DRC:
#   - 9326 nwell.4 ("nwell must contain metal-connected N+ tap") -- UNIFORM across the whole die
#     (~186 per 500um bin), a systematic tap-coverage gap in the decap-heavy fill (256k decap cells)
#     at FP_TAPCELL_DIST 13. NOT an artifact (tensor had 1; Rocket has 9326).
#   - 151 met3.3d + 35 met4.5b (wide-metal spacing, secondary -- likely PDN; revisit if they persist).
# FIX (this run): FP_TAPCELL_DIST 13 -> 6 (much denser well taps -> crush the uniform nwell.4) +
#   RUN_HEURISTIC_DIODE_INSERTION 1 / HEURISTIC_ANTENNA_THRESHOLD 30 (antenna). Keep rt11's proven
#   floorplan (DIE 7000x2600, util 30, density 0.25 -- Rocket routes clean there, no spread needed)
#   and RSZ_MULTICORNER_LIB 1 (hold). ROUTING_CORES 4 for detailed-route memory (197k cells, 23GB host).
# rt11's synth netlist was in rt2 (deleted) -> re-synthesize from config VERILOG_FILES.
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/rocket/rocket_tile -tag rt12 -overwrite

set ::env(CURRENT_SDC) /home/yashwanth/aurora_v1/openlane/rocket/rocket_tile/rocket_clean.sdc

# --- nwell.4 fix: dense well taps ---
set ::env(FP_TAPCELL_DIST) 6
# --- antenna fix ---
set ::env(RUN_HEURISTIC_DIODE_INSERTION) 1
set ::env(HEURISTIC_ANTENNA_THRESHOLD) 30
# --- timing / memory ---
set ::env(RSZ_MULTICORNER_LIB) 1
set ::env(ROUTING_CORES) 4
set ::env(GRT_ADJUSTMENT) 0.1
set ::env(GRT_ALLOW_CONGESTION) 0

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
puts "=== RT12_DONE ==="
exit 0
