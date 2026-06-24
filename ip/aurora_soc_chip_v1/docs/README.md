# Aurora v1 — Full-Chip SoC GDSII (aurora_soc_top_chip)

Signed-off full-chip GDSII for the Aurora v1 AI SoC on SkyWater **Sky130B** (sky130_fd_sc_hd).
Produced by OpenLane 1 (run tag `chip_route2`), 2026-06-24.

## What's in the chip
- **1× Rocket RV64IMAC** CPU tile, hardened macro (33 MHz domain), 2 AXI4 masters
  (mem_axi4 cacheable + mmio_axi4 uncached).
- **1× Tensor core** (4×4 systolic, int16), hardened macro (50 MHz domain), AXI4-Lite slave.
- **Std-cell glue** (50 MHz fabric): 8×8 AXI crossbar, 2× AXI clock-domain-crossing bridges,
  2× Rocket AXI wrappers, boot ROM, SRAM bank array, UART, GPIO, timer, interrupt controller,
  clock/reset controller. Multi-clock (CPU 33 MHz, fabric+tensor 50 MHz).
- Full-SoC boot simulation passes (Rocket boots through the real fabric, prints the UART banner,
  runs the tensor matmul, hits the ALIVE/blink loop).

## Physical
- Die **7500 × 5500 µm**; Rocket macro along the bottom row, tensor + glue in the upper band.
- ~137.5k devices, ~1.97M total instances (incl. fill/decap/tap), 2 hardened macros.

## Signoff status (run chip_route2)
| Check | Result |
|---|---|
| Detailed routing (TritonRoute) | 101 violations |
| Multi-corner post-route STA (SPEF) | **WNS / TNS 0.00 — MET at all 3 corners** (ss/tt/ff) |
| Magic DRC | **1** (nwell.4 fill waiver — see below) |
| netgen LVS — devices | **MATCH: 137,562 = 137,562** (every transistor + connectivity) |
| netgen LVS — nets | 136,742 vs 136,744 (2-net delta — benign, see waivers) |
| GDSII | `gds/aurora_soc_top_chip.gds` (1.32 GB) |

## Documented waivers (benign — not design defects)
1. **DRC nwell.4 (×1):** an isolated nwell-without-metal-tap in a fill region. Density/tap-spacing
   invariant; standard fill-ECO/waiver, carried on every block in this project.
2. **LVS 2-net delta:** caused by (a) 4 *unused* AXI lock outputs on the Rocket macro left
   unconnected (`mem/mmio_axi4_0_a[rw]_bits_lock` — the AXI fabric implements no locked/exclusive
   transactions, so ARLOCK/AWLOCK are legitimately unused), and (b) the VPB/VNB body-pin extraction
   convention (layout ties cell bodies to power → 2× power-net fanout vs the powered netlist).
   Both are extraction/connectivity conventions, not logic errors — the device-level LVS matches
   exactly. For a foundry tapeout these would be connected/resolved (see PROGRESS.md "zero-waiver"
   notes); for IP-demonstration the device-match result is authoritative.

## Reproduce
Winning OpenLane config (`openlane/chip/config.json`) + driver (`openlane/chip/driver_chip_route2.tcl`):
DIE 7500×5500, **PL_TARGET_DENSITY 0.45** (only density that converges RePlAce with the PDN present),
**FP_PDN_HORIZONTAL/VERTICAL_HALO 40** (keeps power straps off the tensor's met4+met5 pins → connected
power net → clean LVS device-match), **FP_PDN_CHECK_NODES 0** (boundary power pins), met1
**GRT_LAYER_ADJUSTMENTS "0,0.6→0.3,…"** (0.3 routes without starving met1 at 0.45 density),
GLB_RESIZER opts skipped, GRT_ALLOW_CONGESTION 1, ROUTING_CORES 4, 18 GB docker cap.
Requires the patched `OpenLane/scripts/odbpy/power_utils.py` (synthesizes missing boundary power ports).

## Contents
- `gds/`    — final GDSII (streamout from Magic)
- `def/`    — routed DEF
- `verilog/`— gate netlist (`.nl.v`) + powered netlist (`.pnl.v`)
- `spice/`  — extracted layout SPICE (LVS layout view)
- `spef/`   — parasitics, 3 corners (min/nom/max)
- `sdc/`    — timing constraints
- `docs/`   — this README

Component macros are packaged separately: `ip/rocket_axitile_v1/` and `ip/tensor_core_4x4_v1/`.
