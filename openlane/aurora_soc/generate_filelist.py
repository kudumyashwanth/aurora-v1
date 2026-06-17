#!/usr/bin/env python3
"""
generate_filelist.py
Generates filelist.f for Aurora SoC OpenLane synthesis.
Run from ~/aurora_v1 directory.
"""

import os
import sys
from pathlib import Path

PROJECT_ROOT = Path(os.environ.get("AURORA_ROOT", Path.home() / "aurora_v1"))
RTL_ROOT = PROJECT_ROOT / "rtl"
OUTPUT = PROJECT_ROOT / "openlane" / "aurora_soc" / "src" / "filelist.f"

# ----------------------------------------------------------------
# File ordering matters for Yosys elaboration.
# Packages/includes first, then leaf modules, then top-level.
# ----------------------------------------------------------------

ORDERED_FILES = [
    # ── Packages & includes (must come first) ──────────────────────
    "cpu_cluster/cva6/core/include/riscv_pkg.sv",
    "cpu_cluster/cva6/core/include/ariane_pkg.sv",
    "cpu_cluster/cva6/core/include/config_pkg.sv",
    "cpu_cluster/cva6/core/include/cv64a6_imafdc_sv39_config_pkg.sv",
    "cpu_cluster/cva6/core/include/std_cache_pkg.sv",
    "cpu_cluster/cva6/core/include/wt_cache_pkg.sv",
    "cpu_cluster/cva6/core/include/build_config_pkg.sv",
    "cpu_cluster/cva6/core/include/aes_pkg.sv",
    "cpu_cluster/cva6/core/include/triggers_pkg.sv",
    "cpu_cluster/cva6/vendor/pulp-platform/axi/src/axi_pkg.sv",

    # ── Clock & reset ──────────────────────────────────────────────
    "clock/clock_reset_controller.sv",

    # ── Boot ROM ───────────────────────────────────────────────────
    "boot/boot_rom.sv",

    # ── Memory subsystem ───────────────────────────────────────────
    "memory/sram_bank_array.sv",
    "cpu_cluster/cva6/common/local/util/sram.sv",
    "cpu_cluster/cva6/common/local/util/sram_cache.sv",

    # ── Interconnect ───────────────────────────────────────────────
    "interconnect/async_fifo.sv",
    "interconnect/axi_crossbar.sv",
    "interconnect/axi_cdc_bridge.sv",

    # ── Peripherals ────────────────────────────────────────────────
    "peripherals/uart.sv",
    "peripherals/gpio.sv",
    "peripherals/timer.sv",

    # ── Interrupt controller ───────────────────────────────────────
    "interrupt/interrupt_controller.sv",

    # ── DMA ────────────────────────────────────────────────────────
    "dma/dma_engine_complete.sv",

    # ── Tensor cluster ─────────────────────────────────────────────
    "tensor_cluster/mac_unit.sv",
    "tensor_cluster/tensor_local_buffer.sv",
    "tensor_cluster/systolic_array_16x16.sv",
    "tensor_cluster/tensor_core.sv",
    "tensor_cluster/tensor_cluster_top.sv",

    # ── CVA6 AXI vendor cells ──────────────────────────────────────
    "cpu_cluster/cva6/vendor/pulp-platform/common_cells/src/fifo_v3.sv",
    "cpu_cluster/cva6/vendor/pulp-platform/common_cells/src/lzc.sv",
    "cpu_cluster/cva6/vendor/pulp-platform/common_cells/src/rr_arb_tree.sv",
    "cpu_cluster/cva6/vendor/pulp-platform/common_cells/src/spill_register.sv",
    "cpu_cluster/cva6/vendor/pulp-platform/axi/src/axi_cut.sv",
    "cpu_cluster/cva6/vendor/pulp-platform/axi/src/axi_multicut.sv",
    "cpu_cluster/cva6/vendor/pulp-platform/axi/src/axi_demux.sv",
    "cpu_cluster/cva6/vendor/pulp-platform/axi/src/axi_mux.sv",
    "cpu_cluster/cva6/vendor/pulp-platform/axi/src/axi_xbar.sv",
    "cpu_cluster/cva6/vendor/pulp-platform/axi/src/axi_err_slv.sv",
    "cpu_cluster/cva6/vendor/pulp-platform/axi/src/axi_id_prepend.sv",
    "cpu_cluster/cva6/vendor/pulp-platform/axi_riscv_atomics/src/axi_riscv_atomics.sv",
    "cpu_cluster/cva6/vendor/pulp-platform/axi_riscv_atomics/src/axi_riscv_amos.sv",
    "cpu_cluster/cva6/vendor/pulp-platform/axi_riscv_atomics/src/axi_riscv_lrsc.sv",

    # ── CVA6 core (leaf → top) ─────────────────────────────────────
    "cpu_cluster/cva6/core/compressed_decoder.sv",
    "cpu_cluster/cva6/core/decoder.sv",
    "cpu_cluster/cva6/core/scoreboard.sv",
    "cpu_cluster/cva6/core/alu.sv",
    "cpu_cluster/cva6/core/multiplier.sv",
    "cpu_cluster/cva6/core/mult.sv",
    "cpu_cluster/cva6/core/serdiv.sv",
    "cpu_cluster/cva6/core/branch_unit.sv",
    "cpu_cluster/cva6/core/load_unit.sv",
    "cpu_cluster/cva6/core/store_unit.sv",
    "cpu_cluster/cva6/core/store_buffer.sv",
    "cpu_cluster/cva6/core/load_store_unit.sv",
    "cpu_cluster/cva6/core/csr_regfile.sv",
    "cpu_cluster/cva6/core/commit_stage.sv",
    "cpu_cluster/cva6/core/controller.sv",
    "cpu_cluster/cva6/core/ex_stage.sv",
    "cpu_cluster/cva6/core/id_stage.sv",
    "cpu_cluster/cva6/core/issue_stage.sv",
    "cpu_cluster/cva6/core/issue_read_operands.sv",
    "cpu_cluster/cva6/core/lsu_bypass.sv",
    "cpu_cluster/cva6/core/instr_realign.sv",
    "cpu_cluster/cva6/core/frontend/btb.sv",
    "cpu_cluster/cva6/core/frontend/bht.sv",
    "cpu_cluster/cva6/core/frontend/ras.sv",
    "cpu_cluster/cva6/core/frontend/instr_scan.sv",
    "cpu_cluster/cva6/core/frontend/instr_queue.sv",
    "cpu_cluster/cva6/core/frontend/frontend.sv",
    "cpu_cluster/cva6/core/cva6_mmu/cva6_tlb.sv",
    "cpu_cluster/cva6/core/cva6_mmu/cva6_ptw.sv",
    "cpu_cluster/cva6/core/cva6_mmu/cva6_shared_tlb.sv",
    "cpu_cluster/cva6/core/cva6_mmu/cva6_mmu.sv",
    "cpu_cluster/cva6/core/pmp/src/pmp_entry.sv",
    "cpu_cluster/cva6/core/pmp/src/pmp.sv",
    "cpu_cluster/cva6/core/cache_subsystem/wt_dcache_ctrl.sv",
    "cpu_cluster/cva6/core/cache_subsystem/wt_dcache_mem.sv",
    "cpu_cluster/cva6/core/cache_subsystem/wt_dcache_missunit.sv",
    "cpu_cluster/cva6/core/cache_subsystem/wt_dcache_wbuffer.sv",
    "cpu_cluster/cva6/core/cache_subsystem/wt_dcache.sv",
    "cpu_cluster/cva6/core/cache_subsystem/cva6_icache.sv",
    "cpu_cluster/cva6/core/cache_subsystem/wt_cache_subsystem.sv",
    "cpu_cluster/cva6/core/cache_subsystem/axi_adapter.sv",
    "cpu_cluster/cva6/core/axi_shim.sv",
    "cpu_cluster/cva6/core/perf_counters.sv",
    "cpu_cluster/cva6/core/cva6_fifo_v3.sv",
    "cpu_cluster/cva6/core/cva6.sv",

    # ── CPU cluster wrapper ────────────────────────────────────────
    "cpu_cluster/cva6_axi_wrapper.sv",
    "cpu_cluster/cpu_mem_bridge.sv",
    "cpu_cluster/cpu_cluster_top.sv",

    # ── Top-level SoC ──────────────────────────────────────────────
    "top/aurora_soc_top.sv",
]

def generate():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    missing = []
    lines = []

    for rel in ORDERED_FILES:
        abs_path = RTL_ROOT / rel
        if abs_path.exists():
            lines.append(str(abs_path))
        else:
            missing.append(rel)

    with open(OUTPUT, "w") as f:
        f.write("# Aurora SoC filelist — auto-generated\n")
        f.write("# Generated by generate_filelist.py\n\n")
        for line in lines:
            f.write(line + "\n")

    print(f"[OK] Wrote {len(lines)} files to {OUTPUT}")
    if missing:
        print(f"\n[WARN] {len(missing)} files not found (may need path adjustments):")
        for m in missing:
            print(f"  MISSING: {m}")
        print("\nThese files won't block Yosys if the modules are defined elsewhere.")

if __name__ == "__main__":
    generate()
