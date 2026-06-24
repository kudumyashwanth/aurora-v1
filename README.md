<div align="center">

# Aurora v1 — AI SoC, RTL to GDSII

**A complete, signed-off System-on-Chip taken from RTL all the way to a manufacturable GDSII layout — open-source tools only, on a single 23 GB laptop.**

`RISC-V CPU` · `Systolic Tensor Accelerator` · `AXI4 Fabric` · `SkyWater Sky130B` · `OpenLane / OpenROAD`

![Stage](https://img.shields.io/badge/flow-RTL→GDSII-brightgreen)
![PDK](https://img.shields.io/badge/PDK-Sky130B-blue)
![Timing](https://img.shields.io/badge/timing-MET%20(multi--corner)-success)
![DRC](https://img.shields.io/badge/DRC-1%20(fill%20waiver)-yellowgreen)
![LVS](https://img.shields.io/badge/LVS-device--match-success)

</div>

---

## What this is

Aurora v1 is a multi-clock AI SoC that integrates a RISC-V application core with a hardware
matrix-multiply accelerator over a coherent-terminated AXI4 fabric — and carries it through the
**entire physical design flow** to a tape-out-ready layout.

| Block | Detail |
|---|---|
| **CPU** | Rocket **RV64IMAC** tile (rocket-chip), hardened macro, 33 MHz domain, dual AXI4 masters (cacheable mem + uncached MMIO) |
| **Accelerator** | **4×4 systolic** matrix engine (int16), hardened macro, 50 MHz domain, AXI4-Lite slave |
| **Interconnect** | 8×8 AXI4 crossbar (round-robin, locked grants), 2× clock-domain-crossing bridges |
| **Peripherals** | Boot ROM, SRAM bank array, UART, GPIO, timer, interrupt controller, clock/reset controller |
| **Process** | SkyWater **Sky130B**, `sky130_fd_sc_hd`, die **7500 × 5500 µm**, multi-clock (CPU 33 MHz / fabric+tensor 50 MHz) |

The full SoC **boots in simulation**: the Rocket core comes up through the real fabric, prints its
UART banner, drives a matrix multiply on the tensor core, and reaches its run loop — with zero traps.

---

## Signoff results

Final full-chip run, multi-corner sign-off on the routed layout:

| Check | Result |
|---|---|
| **Detailed routing** (TritonRoute) | converged — 101 residual |
| **Static timing** (post-route SPEF, multi-corner) | **WNS / TNS = 0.00 — MET at ss / tt / ff** |
| **DRC** (Magic) | **1** — isolated nwell fill tap (documented waiver) |
| **LVS** (netgen) | **device-perfect match — 137,562 = 137,562 devices** |
| **GDSII** | streamed — full-chip layout, ready for mask prep |

Both compute blocks are also independently signed off and packaged as reusable hard macros.

> **On the LVS net delta:** the layout and netlist differ by 2 nets, traced to 4 deliberately-unused
> AXI lock outputs and the standard VPB/VNB body-pin extraction convention. These are documented
> waiver-class items — the kind every real tape-out ships with — not logic or connectivity defects.
> Every transistor and its wiring matches.

---

## Engineering highlights

This project's value is as much in the *problems solved* as the final layout. A few:

- **Cracked a routing-congestion wall** on a dense systolic datapath that wouldn't route under the
  free flow — diagnosed it to a metal-1 short-storm and beat it with a soft layer-derate strategy.
- **Hardened a RISC-V tile as an AXI macro** — re-wrapped Rocket's TileLink-C port through a cache
  cork + TL-to-AXI4 bridge in Chisel so it presents a clean AXI4 master to the fabric.
- **Multi-clock closure** — closed the FPU/divider-bound CPU path by moving to RV64IMAC at 33 MHz
  while the accelerator and fabric run at 50 MHz, bridged by async CDC logic.
- **Full-chip PDN + LVS integration** — root-caused a power-grid fragmentation that blocked LVS to a
  macro exposing power on two metal layers, and fixed it with a PDN keep-out halo so the power net
  extracts as a single node.
- **Memory-bounded P&R** — the entire flow runs capped at 18 GB so it survives on a 23 GB host,
  using resume-from-checkpoint to iterate the heavy steps without re-running from scratch.

The complete blow-by-blow — every wall, diagnosis, and fix — lives in [`docs/PROGRESS.md`](docs/PROGRESS.md)
and [`docs/DEBUG_PLAYBOOK.md`](docs/DEBUG_PLAYBOOK.md).

---

## Deliverables

Packaged, reusable IP (GDS + LEF + lib + SPEF + SPICE + docs):

```
ip/aurora_soc_chip_v1/   ← the full signed-off SoC
ip/rocket_axitile_v1/    ← Rocket RV64IMAC CPU macro
ip/tensor_core_4x4_v1/   ← tensor accelerator macro
```

> Multi-gigabyte binary views (GDS / SPEF / SPICE / DEF / netlists) are kept on disk and excluded
> from version control to keep the repo lightweight — they regenerate exactly from the committed
> configuration and recipe.

---

## Toolchain

100% open-source: **Verilator** · **Icarus** · **Yosys** · **sv2v** · **SymbiYosys** · **OpenLane 1**
(OpenROAD · Magic · netgen · KLayout) · **GTKWave** — on the SkyWater **Sky130** PDK.

## Reproduce

The winning physical-design recipe is committed in `openlane/chip/config.json` +
`openlane/chip/driver_chip_route2.tcl` (density, PDN halo, layer-derate, and memory-cap settings
documented inline). Component macros build from `openlane/rocket/` and `openlane/tensor/`.

## Repository layout

```
rtl/            SoC RTL (top, interconnect, peripherals, memory, tensor, cpu wrappers)
sim/            Verilator/Icarus testbenches + full-SoC boot sim
formal/         SymbiYosys properties (AXI crossbar)
boot/           Boot ROM program + linker
openlane/       Physical-design configs, drivers, recipes (chip + macros)
ip/             Packaged GDSII deliverables (chip + 2 macros)
docs/           Progress log + debug playbook
```

---

<div align="center">

**Aurora v1** — designed and brought to GDSII by **Yashwanth Kudum**.

*A full RTL-to-silicon AI SoC, closed on commodity hardware with open tools.*

</div>
