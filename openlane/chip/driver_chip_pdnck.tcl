# CHEAP CHECK: synth + floorplan + placement only. Validates the candidate clean-LVS config BEFORE a
# ~6.5h route. Candidate fixes (config.json): FP_PDN_CHECK_NODES=0 (finalize boundary pins) +
# FP_PDN_HORIZONTAL/VERTICAL_HALO 40 (keep chip power straps OFF the tensor so they don't float/fragment
# the power net) + PL_TARGET_DENSITY 0.45 (converge RePlAce, which diverged at 0.30 with the PDN present).
# PASS criteria: (1) PDN "[PSM-0040] All PDN stripes connected" (NOT PSM-0069) -> connected power net ->
# clean LVS; (2) VPWR/VGND boundary pins in the floorplan DEF; (3) placement reaches the end (no GPL-0307).
package require openlane

prep -design /home/yashwanth/aurora_v1/openlane/chip -tag chip_pdnck -overwrite

run_synthesis
run_floorplan

set rdef /home/yashwanth/aurora_v1/openlane/chip/runs/chip_pdnck/results/floorplan/aurora_soc_top_chip.def
puts "=== PDN/PIN CHECK ==="
if {[catch {exec grep -cE {USE POWER|USE GROUND} $rdef} np]} { set np 0 }
puts "POWER_PIN_LINES: $np"

run_placement
puts "=== PLACEMENT CONVERGED (no GPL-0307) ==="
puts "=== CHIP_PDNCK_DONE ==="
exit 0
