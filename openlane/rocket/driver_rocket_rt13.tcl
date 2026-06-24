# rt13: clean Rocket nwell.4 via HIGHER DENSITY (less decap fill) -- memory-careful (rt12 OOM'd).
# rt12 failed: FP_TAPCELL_DIST 6 + heuristic diodes bloated the design -> global router OOM-killed
# (18GB cap) -> no detailed route -> garbage 1.9M DRC. rt11 (route+LVS clean, 9326 nwell.4) stands.
# DIAGNOSIS: rt11's 9326 nwell.4 are UNIFORM in the decap-heavy fill (256k decap cells at 0.25
# density / 30% util on a 7000x2600 die). The untapped nwells live in decap fill regions.
# FIX (memory-FREE lever): raise PL_TARGET_DENSITY 0.25 -> 0.35 so there's LESS empty space ->
# LESS decap fill -> fewer untapped-nwell regions. Plus a MODEST tap bump 13 -> 10 (NOT the
# OOM-causing 6). Keep memory low: ROUTING_CORES 2, NO heuristic diode insertion (it bloated rt12;
# GRT_REPAIR_ANTENNAS still handles antennas during global route).
# Reuse the saved rt12 synth netlist -> skip the ~50min ABC re-synth (density is post-synth anyway).
package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/rocket/rocket_tile -tag rt13 -overwrite

# reuse synthesized gate netlist (saved to safety after rt12 synth)
set ::env(CURRENT_NETLIST) /home/yashwanth/aurora_ip_releases/rocket_netlist_safe/RocketTile.synth.rt12.v
set ::env(CURRENT_SDC) /home/yashwanth/aurora_v1/openlane/rocket/rocket_tile/rocket_clean.sdc

# --- nwell.4 fix: less decap fill (free) + modest tap bump ---
set ::env(PL_TARGET_DENSITY) 0.35
set ::env(FP_TAPCELL_DIST) 10
# --- memory safety (avoid the rt12 OOM) ---
set ::env(ROUTING_CORES) 2
set ::env(RUN_HEURISTIC_DIODE_INSERTION) 0
set ::env(RSZ_MULTICORNER_LIB) 1
set ::env(GRT_ADJUSTMENT) 0.1
set ::env(GRT_ALLOW_CONGESTION) 0

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
puts "=== RT13_DONE ==="
exit 0
