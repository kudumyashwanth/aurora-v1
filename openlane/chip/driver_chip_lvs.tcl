# PATH B: get LVS on the PROVEN chip_rt3 routed design (routed, timing MET, DRC=1) instead of
# regenerating everything (the FP_PDN_CHECK_NODES=0 full flow diverges at RePlAce placement on this
# macro-dominated chip). chip_rt3's ONLY defect was that write_powered_def aborted "No power ports at
# top-level" -- the VPWR/VGND NETS exist (every cell connects via the PDN) but had no boundary BTerm.
# FIX: power_utils.py patched to synthesize the missing boundary power/ground ports from the nets.
# Resume the signoff tail from chip_rt3's routed checkpoint: re-extract layout (magic) -> spice -> LVS.
# Stop after LVS (skip antenna_check/save_final_views which HANG ~2h on this 1.9M-instance layout).
package require openlane

set R /home/yashwanth/aurora_v1/openlane/chip/runs/chip_rt3

prep -design /home/yashwanth/aurora_v1/openlane/chip -tag chip_lvs -overwrite

set ::env(CURRENT_DEF)             $R/results/routing/aurora_soc_top_chip.def
set ::env(CURRENT_ODB)             $R/results/routing/aurora_soc_top_chip.odb
set ::env(CURRENT_NETLIST)         $R/results/routing/aurora_soc_top_chip.nl.v
set ::env(CURRENT_POWERED_NETLIST) $R/results/routing/aurora_soc_top_chip.pnl.v

run_magic
run_magic_spice_export
run_lvs
puts "=== CHIP_LVS_DONE ==="
exit 0
