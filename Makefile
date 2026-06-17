# Aurora v1 AI SoC — Build System
# Requires Verilator 5.x (tested with 5.046)
# =============================================================

RTL_DIR   = rtl
SIM_DIR   = sim
BUILD_DIR = obj_dir
WAVE_FILE = aurora_wave.vcd
CVA6_DIR  = $(RTL_DIR)/cpu_cluster/cva6

CVA6_PKGS := \
  $(CVA6_DIR)/core/include/config_pkg.sv \
  $(CVA6_DIR)/core/include/cv64a6_imafdc_sv39_config_pkg.sv \
  $(CVA6_DIR)/core/include/build_config_pkg.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/cf_math_pkg.sv \
  $(CVA6_DIR)/vendor/pulp-platform/axi/src/axi_pkg.sv \
  $(CVA6_DIR)/core/include/riscv_pkg.sv \
  $(CVA6_DIR)/core/include/ariane_pkg.sv \
  $(CVA6_DIR)/core/include/std_cache_pkg.sv \
  $(CVA6_DIR)/core/include/wt_cache_pkg.sv \
  $(CVA6_DIR)/core/include/triggers_pkg.sv

CVA6_VENDOR := \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/lzc.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/rr_arb_tree.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/fifo_v3.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/fall_through_register.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/shift_reg.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/spill_register.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/spill_register_flushable.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/stream_arbiter.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/stream_arbiter_flushable.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/stream_demux.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/stream_mux.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/stream_fork.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/stream_join.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/stream_register.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/counter.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/id_queue.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/onehot_to_bin.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/popcount.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/plru_tree.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/lfsr.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/lfsr_8bit.sv \
  $(CVA6_DIR)/vendor/pulp-platform/tech_cells_generic/src/rtl/tc_sram.sv \
  $(CVA6_DIR)/common/local/util/sram.sv

CVA6_CORE := \
  $(CVA6_DIR)/core/cva6_fifo_v3.sv \
  $(CVA6_DIR)/core/alu.sv \
  $(CVA6_DIR)/core/branch_unit.sv \
  $(CVA6_DIR)/core/compressed_decoder.sv \
  $(CVA6_DIR)/core/controller.sv \
  $(CVA6_DIR)/core/csr_buffer.sv \
  $(CVA6_DIR)/core/csr_regfile.sv \
  $(CVA6_DIR)/core/decoder.sv \
  $(CVA6_DIR)/core/instr_realign.sv \
  $(CVA6_DIR)/core/id_stage.sv \
  $(CVA6_DIR)/core/issue_read_operands.sv \
  $(CVA6_DIR)/core/issue_stage.sv \
  $(CVA6_DIR)/core/ex_stage.sv \
  $(CVA6_DIR)/core/commit_stage.sv \
  $(CVA6_DIR)/core/amo_buffer.sv \
  $(CVA6_DIR)/core/load_unit.sv \
  $(CVA6_DIR)/core/store_unit.sv \
  $(CVA6_DIR)/core/store_buffer.sv \
  $(CVA6_DIR)/core/lsu_bypass.sv \
  $(CVA6_DIR)/core/load_store_unit.sv \
  $(CVA6_DIR)/core/multiplier.sv \
  $(CVA6_DIR)/core/mult.sv \
  $(CVA6_DIR)/core/serdiv.sv \
  $(CVA6_DIR)/core/ariane_regfile_ff.sv \
  $(CVA6_DIR)/core/perf_counters.sv \
  $(CVA6_DIR)/core/scoreboard.sv \
  $(CVA6_DIR)/core/raw_checker.sv \
  $(CVA6_DIR)/core/trigger_module.sv \
  $(CVA6_DIR)/core/pmp/src/pmp_entry.sv \
  $(CVA6_DIR)/core/pmp/src/pmp.sv \
  $(CVA6_DIR)/core/pmp/src/pmp_data_if.sv \
  $(CVA6_DIR)/core/frontend/btb.sv \
  $(CVA6_DIR)/core/frontend/bht.sv \
  $(CVA6_DIR)/core/frontend/ras.sv \
  $(CVA6_DIR)/core/frontend/instr_queue.sv \
  $(CVA6_DIR)/core/frontend/instr_scan.sv \
  $(CVA6_DIR)/core/frontend/frontend.sv \
  $(CVA6_DIR)/core/cache_subsystem/axi_adapter.sv \
  $(CVA6_DIR)/core/cache_subsystem/cache_ctrl.sv \
  $(CVA6_DIR)/core/cache_subsystem/miss_handler.sv \
  $(CVA6_DIR)/core/cache_subsystem/tag_cmp.sv \
  $(CVA6_DIR)/core/cache_subsystem/std_nbdcache.sv \
  $(CVA6_DIR)/core/cache_subsystem/std_cache_subsystem.sv \
  $(CVA6_DIR)/core/cache_subsystem/cva6_icache.sv \
  $(CVA6_DIR)/core/cache_subsystem/cva6_icache_axi_wrapper.sv \
  $(CVA6_DIR)/core/cva6_mmu/cva6_tlb.sv \
  $(CVA6_DIR)/core/cva6_mmu/cva6_shared_tlb.sv \
  $(CVA6_DIR)/core/cva6_mmu/cva6_ptw.sv \
  $(CVA6_DIR)/core/cva6_mmu/cva6_mmu.sv \
  $(CVA6_DIR)/core/cva6_accel_first_pass_decoder_stub.sv \
  $(CVA6_DIR)/core/cvxif_compressed_if_driver.sv \
  $(CVA6_DIR)/core/cvxif_issue_register_commit_if_driver.sv \
  $(CVA6_DIR)/core/cvxif_fu.sv \
  $(CVA6_DIR)/core/alu_wrapper.sv \
  $(CVA6_DIR)/core/macro_decoder.sv \
  $(CVA6_DIR)/core/cva6_rvfi_probes.sv \
  $(CVA6_DIR)/core/aes.sv \
  $(CVA6_DIR)/vendor/pulp-platform/common_cells/src/unread.sv \
  $(CVA6_DIR)/core/axi_shim.sv \
  $(CVA6_DIR)/core/cva6.sv


AURORA_SRCS := \
  $(RTL_DIR)/clock/clock_reset_controller.sv \
  $(RTL_DIR)/interconnect/async_fifo.sv \
  $(RTL_DIR)/interconnect/axi_cdc_bridge.sv \
  $(RTL_DIR)/interconnect/axi_crossbar.sv \
  $(RTL_DIR)/interrupt/interrupt_controller.sv \
  $(RTL_DIR)/memory/sram_bank_array.sv \
  $(RTL_DIR)/boot/boot_rom.sv \
  $(RTL_DIR)/dma/dma_engine_complete.sv \
  $(RTL_DIR)/peripherals/uart.sv \
  $(RTL_DIR)/peripherals/gpio.sv \
  $(RTL_DIR)/peripherals/timer.sv \
  $(RTL_DIR)/tensor_cluster/mac_unit.sv \
  $(RTL_DIR)/tensor_cluster/systolic_array_16x16.sv \
  $(RTL_DIR)/tensor_cluster/tensor_local_buffer.sv \
  $(RTL_DIR)/tensor_cluster/tensor_core.sv \
  $(RTL_DIR)/tensor_cluster/tensor_cluster_top.sv \
  $(RTL_DIR)/cpu_cluster/cva6_axi_wrapper.sv \
  $(RTL_DIR)/cpu_cluster/cpu_cluster_top.sv \
  $(RTL_DIR)/top/aurora_soc_top.sv

TB_SOURCE  = $(SIM_DIR)/tb/tb_aurora_soc.sv
CPP_SOURCE = $(SIM_DIR)/main.cpp

# CVA6's VLT file — works correctly with Verilator 5.x
CVA6_VLT   = $(CVA6_DIR)/verilator_config.vlt

ALL_RTL    := $(CVA6_PKGS) $(CVA6_VENDOR) $(CVA6_CORE) $(AURORA_SRCS)
EXECUTABLE = $(BUILD_DIR)/Vtb_aurora_soc

INC_FLAGS := \
  +incdir+$(CVA6_DIR)/core/include \
  +incdir+$(CVA6_DIR)/vendor/pulp-platform/common_cells/include \
  +incdir+$(CVA6_DIR)/vendor/pulp-platform/axi/include \
  +incdir+$(CVA6_DIR)/common/local/util

# Verilator 5.x flags — VLT file handles CVA6-specific lint waivers
VFLAGS := \
  --cc \
  --trace \
  --exe \
  --build \
  --top-module tb_aurora_soc \
  -Wno-fatal \
  -Wno-TIMESCALEMOD \
  -Wno-MULTITOP \
  -Wno-CASEINCOMPLETE \
  -Wno-UNOPTFLAT \
  -Wno-BLKANDNBLK \
  -Wno-WIDTH \
  -Wno-UNUSED \
  -Wno-PINMISSING \
  $(INC_FLAGS) \
  --language 1800-2017

.PHONY: all sim build wave clean status help

all: sim

sim: $(EXECUTABLE)
	@echo "======================================="
	@echo "  Running Aurora v1 Simulation (CVA6)"
	@echo "======================================="
	@./$(EXECUTABLE)
	@echo ""
	@echo "✅ Aurora v1 simulation complete!"
	@echo "📊 Waveform: $(WAVE_FILE)"

$(EXECUTABLE): $(ALL_RTL) $(TB_SOURCE) $(CPP_SOURCE)
	@echo "Compiling Aurora v1 RTL with CVA6..."
	@echo "  CVA6 pkgs  : $(words $(CVA6_PKGS))"
	@echo "  CVA6 vendor: $(words $(CVA6_VENDOR))"
	@echo "  CVA6 core  : $(words $(CVA6_CORE))"
	@echo "  Aurora     : $(words $(AURORA_SRCS))"
	@echo "  Total      : $(words $(ALL_RTL)) RTL files"
	verilator $(VFLAGS) $(CVA6_VLT) $(ALL_RTL) $(TB_SOURCE) $(CPP_SOURCE)

sim-picorv32:
	@echo "Building with PicoRV32 (~30s)..."
	rm -rf $(BUILD_DIR)
	verilator --cc --trace --exe --build \
	  --top-module tb_aurora_soc \
	  -Wno-fatal -Wno-TIMESCALEMOD -Wno-CASEINCOMPLETE \
	  -Wno-WIDTH -Wno-UNUSED -Wno-PINMISSING \
	  $(RTL_DIR)/clock/clock_reset_controller.sv \
	  $(RTL_DIR)/interconnect/async_fifo.sv \
	  $(RTL_DIR)/interconnect/axi_cdc_bridge.sv \
	  $(RTL_DIR)/interconnect/axi_crossbar.sv \
	  $(RTL_DIR)/interrupt/interrupt_controller.sv \
	  $(RTL_DIR)/memory/sram_bank_array.sv \
	  $(RTL_DIR)/boot/boot_rom.sv \
	  $(RTL_DIR)/dma/dma_engine_complete.sv \
	  $(RTL_DIR)/peripherals/uart.sv \
	  $(RTL_DIR)/peripherals/gpio.sv \
	  $(RTL_DIR)/peripherals/timer.sv \
	  $(RTL_DIR)/tensor_cluster/mac_unit.sv \
	  $(RTL_DIR)/tensor_cluster/systolic_array_16x16.sv \
	  $(RTL_DIR)/tensor_cluster/tensor_local_buffer.sv \
	  $(RTL_DIR)/tensor_cluster/tensor_core.sv \
	  $(RTL_DIR)/tensor_cluster/tensor_cluster_top.sv \
	  $(RTL_DIR)/cpu_cluster/picorv32_core.sv \
	  $(RTL_DIR)/cpu_cluster/cpu_mem_bridge.sv \
	  $(RTL_DIR)/cpu_cluster/riscv_cpu_wrapper.sv \
	  $(RTL_DIR)/cpu_cluster/cpu_cluster_top_picorv32.sv \
	  $(RTL_DIR)/top/aurora_soc_top.sv \
	  $(TB_SOURCE) $(CPP_SOURCE)
	./$(EXECUTABLE)

wave: $(WAVE_FILE)
	gtkwave $(WAVE_FILE) &

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR) $(WAVE_FILE)
	@echo "✅ Clean complete"

status:
	@echo "=== Aurora v1 Status ==="
	@echo "Verilator : $$(verilator --version | head -1)"
	@echo "CVA6      : $$([ -d $(CVA6_DIR) ] && echo '✅' || echo '❌')"
	@echo "CVA6 VLT  : $$([ -f $(CVA6_VLT) ] && echo '✅' || echo '❌')"
	@echo "Built     : $$([ -f $(EXECUTABLE) ] && echo '✅' || echo '❌')"

help:
	@echo "make sim           CVA6 build (Linux-capable, Verilator 5.x)"
	@echo "make sim-picorv32  PicoRV32 build (fast ~30s)"
	@echo "make wave          GTKWave"
	@echo "make clean         Remove artifacts"
	@echo "make status        Check environment"
