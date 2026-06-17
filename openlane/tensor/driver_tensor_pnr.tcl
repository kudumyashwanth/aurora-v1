package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc3 -overwrite
set ::env(CURRENT_NETLIST) /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster/runs/tc1/results/synthesis/tensor_core_hard.v
set ::env(CURRENT_SDC) /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster/tensor_clean.sdc
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
puts "=== TENSOR_TC3_DONE ==="
exit 0
