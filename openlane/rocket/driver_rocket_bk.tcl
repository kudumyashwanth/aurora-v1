package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/rocket/rocket_tile -tag rt11 -overwrite
set R /home/yashwanth/aurora_v1/openlane/rocket/rocket_tile/runs/rt2
set ::env(CURRENT_NETLIST) $R/results/synthesis/RocketTile.v
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
puts "=== RT11_DONE ==="
exit 0
