package require openlane
prep -design /home/yashwanth/aurora_v1/openlane/tensor/tensor_cluster -tag tc1 -overwrite
run_synthesis
run_floorplan
puts "=== TENSOR_FP_DONE ==="
exit 0
