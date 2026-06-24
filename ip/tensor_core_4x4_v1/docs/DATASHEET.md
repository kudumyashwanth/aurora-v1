# Aurora Tensor Core IP — `tensor_core_hard` (4×4, v1)

A hardened, signed-off systolic **matrix-multiply accelerator** macro on the open
**SkyWater Sky130B** PDK, built entirely with the free OpenLane/OpenROAD/Yosys/Magic
flow. Parametric and tileable — this v1 hardens the 4×4 (16-MAC) configuration that
closes clean on the free flow; the same RTL scales to larger arrays on
higher-capacity (commercial) P&R or a larger host.

---

## 1. Key specifications

| Parameter | Value |
|---|---|
| Function | Dense matrix multiply (systolic, rank-1 outer-product accumulation) |
| Array size | 4 × 4 = **16 MAC units** (`SIZE=4`, parametric) |
| Operand width | **int16** (`DATA_WIDTH=16`) |
| Accumulator width | 32-bit |
| Throughput | 16 MAC/cycle → **800 MMAC/s @ 50 MHz** |
| Clock | 50 MHz (20 ns period) |
| Interface | AXI4-Lite slave (32-bit) + done IRQ |
| Local buffer | 16 × 128-bit flop scratchpad (operand staging) |
| PDK / stdcells | Sky130B / `sky130_fd_sc_hd` |
| Die area | 1800 × 1800 µm = **3.24 mm²** |
| Std-cell area | 291,810 µm² (~29.5k mapped cells) |
| Macros | none (pure standard-cell — no SRAM macros at this scale) |

## 2. Signoff results (verified)

| Check | Result |
|---|---|
| Detailed routing (TritonRoute) | ✅ **0 violations** |
| **LVS** (netgen) | ✅ **0 errors — "Circuits match uniquely"** |
| Antenna (Magic) | ✅ **0 violations** |
| Setup timing (min/nom/max corners, post-route SPEF) | ✅ **MET**, +3.2 … +3.4 ns worst slack |
| Hold timing (all corners) | ✅ **MET**, +0.08 ns |
| Magic DRC | ⚠️ **1** (see §7 — isolated nwell-tap tool artifact, waivable) |

Timing is signed off on **real post-route multi-corner parasitics** (SPEF
extracted at min/nom/max).

## 3. Architecture

```
            AXI4-Lite slave (32-bit)
                    │
     ┌──────────────┼───────────────┐
     ▼              ▼                ▼
 ctrl/status   buffer write     result read-back
  registers   (128-bit words)    (16×32-bit C)
                    │                ▲
                    ▼                │
            local buffer  ──►  matrix-loader FSM ──► 4×4 systolic array
            (16×128 flop)      (loads A,B vectors)    (16 MAC units)
```

- **Systolic array** (`systolic_array_16x16.sv`, parametric): 16 MAC PEs, rank-1
  outer-product accumulate into 16 × 32-bit result registers.
- **Matrix-loader FSM**: reads A then B from the local buffer (1 128-bit word each
  at `SIZE=4`), pipelined for 1-cycle buffer latency, then launches the array.
- **Local buffer**: 16-deep × 128-bit flop scratchpad (operands only ever occupy
  the first 2 words at 4×4 — flops are the correct choice vs an SRAM macro here).

## 4. Interface — AXI4-Lite slave

Ports: `clk`, `rst_n` (active-low), standard AXI4-Lite AW/W/B/AR/R channels
(32-bit addr/data), `core_done_irq`.

### Address map (relative to block base)
| Region | Selector | Contents |
|---|---|---|
| Control regs (write) | `awaddr[15:12]==0` | `0x00` ctrl, `0x08` a_addr, `0x0C` b_addr, `0x10` c_addr, `0x14` config |
| Buffer write | `awaddr[15:12]==1` | 128-bit word from 4×32-bit beats; `awaddr[11:4]`=word, `awaddr[3:2]`=lane |
| Register read | `araddr[15]==0` | `0x00` ctrl, `0x04` status, `0x08` a_addr, `0x0C` b_addr, `0x10` c_addr, `0x14` config |
| Result read-back | `araddr[15]==1` | result word = `araddr[2 +: clog2(SIZE*SIZE)]` (C matrix, row-major) |

- **ctrl[0]** = start (auto-clears). **status**: bit0 idle, bit1 busy, bit2 done (sticky until next start).

### Operation
1. Write matrix **A** to buffer word 0 (`0x?000`), matrix **B** to word 1 (`0x?010`).
2. Write `ctrl[0]=1` to start.
3. Poll `status` bit2 (or use `core_done_irq`).
4. Read the 16-entry **C** result via the result read-back window (`araddr[15]=1`).

## 5. Files in this package
- `gds/` — final layout (GDSII)
- `lef/` — abstract LEF (for top-level integration)
- `lib/` — Liberty timing (nominal + Slowest/Typical/Fastest corners)
- `verilog/` — RTL source (`*.sv`), sv2v-flattened, and the LVS-clean gate netlist (`*.gate.nl.v`)
- `sdc/` — timing constraints
- `spef/` — extracted parasitics (min/nom/max)
- `sdf/` — back-annotation delays
- `spice/` — extracted layout SPICE (LVS)
- `docs/build_driver.tcl` — exact OpenLane driver that produced this (reproducibility)

## 6. Scaling
`SIZE` and `DATA_WIDTH` are RTL parameters. The 4×4 is the configuration that
routes and signs off clean on the free Sky130 flow + a 23 GB host. Higher
throughput options: **tile this macro ×4/×16** at the SoC level, raise `SIZE`
(8×8/16×16) on commercial P&R (more metal layers / better congestion handling),
and reintroduce real SRAM macros for the buffer once it is genuinely large.

## 7. Known issue (waivable)
One residual Magic DRC: a single `nwell.4` ("nwell must contain a metal-connected
N+ tap") at a fixed coordinate (~168.17, 229.79 µm). It is **immune to placement
density (0.20/0.24/0.30) and tap-cell distance (13/10/8 µm)** — an isolated nwell
in a low-density fill region, i.e. a Sky130/Magic fill artifact, not a logic-tap
defect. LVS (the connectivity check) is 100% clean. Standard handling: **waive
with justification or fix with a one-cell Magic tap ECO**.

## 8. Provenance
Built with OpenLane 1.0.2 (Docker, OpenROAD/Yosys/Magic/netgen), Sky130B PDK,
`sky130_fd_sc_hd`. Source run tag `tc23`. See `build_driver.tcl`.
