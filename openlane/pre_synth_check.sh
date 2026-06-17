#!/usr/bin/env bash
set -euo pipefail

AURORA_ROOT="${HOME}/aurora_v1"
RTL="${AURORA_ROOT}/rtl"
CVA6="${RTL}/cpu_cluster/cva6"
CHECK_DIR="${AURORA_ROOT}/openlane/pre_check"
CONV_DIR="${CHECK_DIR}/converted"

mkdir -p "$CONV_DIR"

echo "[CHECK] Step 1: Converting ALL RTL (CVA6 + Aurora) with sv2v..."

sv2v \
  -DVERILATOR -DSYNTHESIS \
  -I "${CVA6}/core/include" \
  -I "${CVA6}/vendor/pulp-platform/common_cells/include" \
  -I "${CVA6}/vendor/pulp-platform/axi/include" \
  \
  "${CVA6}/core/include/riscv_pkg.sv" \
  "${CVA6}/core/include/ariane_pkg.sv" \
  "${CVA6}/core/include/config_pkg.sv" \
  "${CVA6}/core/include/cv64a6_imafdc_sv39_config_pkg.sv" \
  "${CVA6}/core/include/std_cache_pkg.sv" \
  "${CVA6}/core/include/wt_cache_pkg.sv" \
  "${CVA6}/core/include/build_config_pkg.sv" \
  "${CVA6}/core/include/triggers_pkg.sv" \
  "${CVA6}/core/include/aes_pkg.sv" \
  \
  "${CVA6}/vendor/pulp-platform/common_cells/src/cf_math_pkg.sv" \
  "${CVA6}/vendor/pulp-platform/common_cells/src/fifo_v3.sv" \
  "${CVA6}/vendor/pulp-platform/common_cells/src/lzc.sv" \
  "${CVA6}/vendor/pulp-platform/common_cells/src/rr_arb_tree.sv" \
  "${CVA6}/vendor/pulp-platform/common_cells/src/spill_register.sv" \
  "${CVA6}/vendor/pulp-platform/common_cells/src/stream_arbiter.sv" \
  "${CVA6}/vendor/pulp-platform/common_cells/src/stream_arbiter_flushable.sv" \
  "${CVA6}/vendor/pulp-platform/common_cells/src/stream_demux.sv" \
  "${CVA6}/vendor/pulp-platform/common_cells/src/stream_mux.sv" \
  "${CVA6}/vendor/pulp-platform/common_cells/src/popcount.sv" \
  "${CVA6}/vendor/pulp-platform/common_cells/src/onehot_to_bin.sv" \
  "${CVA6}/vendor/pulp-platform/common_cells/src/shift_reg.sv" \
  "${CVA6}/vendor/pulp-platform/common_cells/src/lfsr.sv" \
  "${CVA6}/vendor/pulp-platform/common_cells/src/delta_counter.sv" \
  "${CVA6}/vendor/pulp-platform/common_cells/src/counter.sv" \
  "${CVA6}/vendor/pulp-platform/common_cells/src/fall_through_register.sv" \
  "${CVA6}/vendor/pulp-platform/common_cells/src/stream_fifo.sv" \
  "${CVA6}/vendor/pulp-platform/axi/src/axi_pkg.sv" \
  "${CVA6}/common/local/util/sram.sv" \
  "${CVA6}/common/local/util/sram_cache.sv" \
  "${CVA6}/core/cvfpu/src/fpnew_pkg.sv" \
  "${CVA6}/core/cvfpu/src/fpnew_cast_multi.sv" \
  "${CVA6}/core/cvfpu/src/fpnew_classifier.sv" \
  "${CVA6}/core/cvfpu/vendor/opene906/E906_RTL_FACTORY/gen_rtl/clk/rtl/gated_clk_cell.v" \
  "${CVA6}/core/cvfpu/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_ctrl.v" \
  "${CVA6}/core/cvfpu/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_ff1.v" \
  "${CVA6}/core/cvfpu/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_pack_single.v" \
  "${CVA6}/core/cvfpu/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_prepare.v" \
  "${CVA6}/core/cvfpu/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_round_single.v" \
  "${CVA6}/core/cvfpu/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_special.v" \
  "${CVA6}/core/cvfpu/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_srt_single.v" \
  "${CVA6}/core/cvfpu/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/pa_fdsu_top.v" \
  "${CVA6}/core/cvfpu/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fpu/rtl/pa_fpu_dp.v" \
  "${CVA6}/core/cvfpu/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fpu/rtl/pa_fpu_frbus.v" \
  "${CVA6}/core/cvfpu/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fpu/rtl/pa_fpu_src_type.v" \
  "${CVA6}/core/cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_ctrl.v" \
  "${CVA6}/core/cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_double.v" \
  "${CVA6}/core/cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_ff1.v" \
  "${CVA6}/core/cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_pack.v" \
  "${CVA6}/core/cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_prepare.v" \
  "${CVA6}/core/cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_round.v" \
  "${CVA6}/core/cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_scalar_dp.v" \
  "${CVA6}/core/cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt_radix16_bound_table.v" \
  "${CVA6}/core/cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt_radix16_with_sqrt.v" \
  "${CVA6}/core/cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_srt.v" \
  "${CVA6}/core/cvfpu/vendor/openc910/C910_RTL_FACTORY/gen_rtl/vfdsu/rtl/ct_vfdsu_top.v" \
  "${CVA6}/core/cvfpu/src/fpnew_divsqrt_th_32.sv" \
  "${CVA6}/core/cvfpu/src/fpnew_divsqrt_th_64_multi.sv" \
  "${CVA6}/core/cvfpu/src/fpnew_divsqrt_multi.sv" \
  "${CVA6}/core/cvfpu/src/fpnew_fma_multi.sv" \
  "${CVA6}/core/cvfpu/src/fpnew_fma.sv" \
  "${CVA6}/core/cvfpu/src/fpnew_noncomp.sv" \
  "${CVA6}/core/cvfpu/src/fpnew_opgroup_block.sv" \
  "${CVA6}/core/cvfpu/src/fpnew_opgroup_fmt_slice.sv" \
  "${CVA6}/core/cvfpu/src/fpnew_opgroup_multifmt_slice.sv" \
  "${CVA6}/core/cvfpu/src/fpnew_rounding.sv" \
  "${CVA6}/core/cvfpu/src/fpnew_top.sv" \
  "${CVA6}/core/cvfpu/src/fpu_div_sqrt_mvp/hdl/defs_div_sqrt_mvp.sv" \
  "${CVA6}/core/cvfpu/src/fpu_div_sqrt_mvp/hdl/control_mvp.sv" \
  "${CVA6}/core/cvfpu/src/fpu_div_sqrt_mvp/hdl/div_sqrt_top_mvp.sv" \
  "${CVA6}/core/cvfpu/src/fpu_div_sqrt_mvp/hdl/iteration_div_sqrt_mvp.sv" \
  "${CVA6}/core/cvfpu/src/fpu_div_sqrt_mvp/hdl/norm_div_sqrt_mvp.sv" \
  "${CVA6}/core/cvfpu/src/fpu_div_sqrt_mvp/hdl/nrbd_nrsc_mvp.sv" \
  "${CVA6}/core/cvfpu/src/fpu_div_sqrt_mvp/hdl/preprocess_mvp.sv" \
  "${CVA6}/core/fpu_wrap.sv" \
  \
  "${CVA6}/core/pmp/src/pmp_entry.sv" \
  "${CVA6}/core/pmp/src/pmp.sv" \
  "${CVA6}/core/cva6_mmu/cva6_tlb.sv" \
  "${CVA6}/core/cva6_mmu/cva6_ptw.sv" \
  "${CVA6}/core/cva6_mmu/cva6_shared_tlb.sv" \
  "${CVA6}/core/cva6_mmu/cva6_mmu.sv" \
  "${CVA6}/core/cache_subsystem/wt_dcache_ctrl.sv" \
  "${CVA6}/core/cache_subsystem/wt_dcache_mem.sv" \
  "${CVA6}/core/cache_subsystem/wt_dcache_missunit.sv" \
  "${CVA6}/core/cache_subsystem/wt_dcache_wbuffer.sv" \
  "${CVA6}/core/cache_subsystem/wt_dcache.sv" \
  "${CVA6}/core/cache_subsystem/wt_axi_adapter.sv" \
  "${CVA6}/core/cache_subsystem/cva6_icache.sv" \
  "${CVA6}/core/cache_subsystem/cva6_icache_axi_wrapper.sv" \
  "${CVA6}/core/cache_subsystem/wt_cache_subsystem.sv" \
  "${CVA6}/core/frontend/btb.sv" \
  "${CVA6}/core/frontend/bht.sv" \
  "${CVA6}/core/frontend/ras.sv" \
  "${CVA6}/core/frontend/instr_scan.sv" \
  "${CVA6}/core/frontend/instr_queue.sv" \
  "${CVA6}/core/frontend/frontend.sv" \
  "${CVA6}/core/compressed_decoder.sv" \
  "${CVA6}/core/decoder.sv" \
  "${CVA6}/core/scoreboard.sv" \
  "${CVA6}/core/alu.sv" \
  "${CVA6}/core/serdiv.sv" \
  "${CVA6}/core/multiplier.sv" \
  "${CVA6}/core/mult.sv" \
  "${CVA6}/core/branch_unit.sv" \
  "${CVA6}/core/load_unit.sv" \
  "${CVA6}/core/store_unit.sv" \
  "${CVA6}/core/store_buffer.sv" \
  "${CVA6}/core/lsu_bypass.sv" \
  "${CVA6}/core/load_store_unit.sv" \
  "${CVA6}/core/csr_regfile.sv" \
  "${CVA6}/core/commit_stage.sv" \
  "${CVA6}/core/controller.sv" \
  "${CVA6}/core/issue_read_operands.sv" \
  "${CVA6}/core/issue_stage.sv" \
  "${CVA6}/core/id_stage.sv" \
  "${CVA6}/core/ex_stage.sv" \
  "${CVA6}/core/instr_realign.sv" \
  "${CVA6}/core/perf_counters.sv" \
  "${CVA6}/core/axi_shim.sv" \
  "${CVA6}/core/cva6_fifo_v3.sv" \
  "${CVA6}/core/ariane_regfile_ff.sv" \
  "${CVA6}/core/cva6_accel_first_pass_decoder_stub.sv" \
  "${CVA6}/core/cvxif_fu.sv" \
  "${CVA6}/core/raw_checker.sv" \
  "${CVA6}/core/cva6.sv" \
  \
  "${RTL}/clock/clock_reset_controller.sv" \
  "${RTL}/boot/boot_rom.sv" \
  "${RTL}/memory/sram_bank_array.sv" \
  "${RTL}/interconnect/async_fifo.sv" \
  "${RTL}/interconnect/axi_crossbar.sv" \
  "${RTL}/interconnect/axi_cdc_bridge.sv" \
  "${RTL}/peripherals/uart.sv" \
  "${RTL}/peripherals/gpio.sv" \
  "${RTL}/peripherals/timer.sv" \
  "${RTL}/interrupt/interrupt_controller.sv" \
  "${RTL}/dma/dma_engine_complete.sv" \
  "${RTL}/tensor_cluster/mac_unit.sv" \
  "${RTL}/tensor_cluster/tensor_local_buffer.sv" \
  "${RTL}/tensor_cluster/systolic_array_16x16.sv" \
  "${RTL}/tensor_cluster/tensor_core.sv" \
  "${RTL}/tensor_cluster/tensor_cluster_top.sv" \
  "${RTL}/cpu_cluster/cva6_axi_wrapper.sv" \
  "${RTL}/cpu_cluster/cpu_mem_bridge.sv" \
  "${RTL}/cpu_cluster/cpu_cluster_top.sv" \
  "${RTL}/top/aurora_soc_top.sv" \
  > "${CONV_DIR}/aurora_soc_combined.v" 2>&1

LINE_COUNT=$(wc -l < "${CONV_DIR}/aurora_soc_combined.v")
echo "[CHECK] sv2v done. Converted file: ${LINE_COUNT} lines"

echo "[CHECK] Step 2: Yosys elaboration check..."

yosys -p "
  read_verilog -I${CVA6}/core/include ${CONV_DIR}/aurora_soc_combined.v
  hierarchy -check -top aurora_soc_top
  check
" 2>&1 | tee "${CHECK_DIR}/elab_check.log"

if grep -q "^ERROR\|^Error: " "${CHECK_DIR}/elab_check.log"; then
    echo ""
    echo "[FAIL] Elaboration failed:"
    grep "^ERROR\|^Error: " "${CHECK_DIR}/elab_check.log" | head -20
    exit 1
else
    echo ""
    echo "[PASS] RTL elaboration PASSED — safe to run OpenLane!"
fi
