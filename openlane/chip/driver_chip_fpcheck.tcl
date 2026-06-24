# FAST PDN-validation check: synth + floorplan ONLY (stop after PDN), then report whether the denser
# 7500x4800 floorplan fixes the PDN connectivity failure (chip1 7500x5500 = PSM-0069 fail, 980 unconnected
# nodes, no top-level VPWR/VGND pins -> LVS blocked). Do NOT route (~6.5h) until PDN connects + power pins
# exist. Looking for: "[PSM-0040] All PDN stripes connected" (not PSM-0069) and VPWR/VGND SPECIAL pins in
# the floorplan DEF.
package require openlane

prep -design /home/yashwanth/aurora_v1/openlane/chip -tag chip_fpck2 -overwrite

run_synthesis
run_floorplan

# Report PDN verdict + power pins. Check the floorplan RESULT def (post-PDN).
set rdef /home/yashwanth/aurora_v1/openlane/chip/runs/chip_fpck2/results/floorplan/aurora_soc_top_chip.def
puts "=== checking FP result DEF: $rdef ==="
if {[catch {exec grep -nE {USE POWER|USE GROUND} $rdef} pins]} {
  puts "POWER_PINS: NONE FOUND"
} else {
  puts "POWER_PINS_FOUND:\n$pins"
}
puts "=== CHIP_FPCK_DONE ==="
exit 0
