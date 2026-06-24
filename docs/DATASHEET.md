# Aurora v1 — AI SoC Datasheet (preliminary)

**Device:** `aurora_soc_top_chip` · **Process:** SkyWater Sky130B (`sky130_fd_sc_hd`)
**Status:** signed-off GDSII (routed, multi-corner timing MET, DRC=1 waiver, LVS device-match)
**Class:** bare-metal AI accelerator SoC (not a Linux-class applications processor — see §8)

---

## 1. Overview

Aurora v1 is a multi-clock System-on-Chip that pairs a 64-bit RISC-V control core with a
hardware matrix-multiply accelerator over a coherent-terminated AXI4 fabric, with a standard
peripheral set. It is a demonstration / IP-evaluation device taken through the full RTL→GDSII
flow on open-source tools.

**Top-level features**
- Rocket **RV64IMAC** CPU tile (rocket-chip), hardened macro, dual AXI4 masters
- **4×4 systolic** matrix engine (int16 MACs), hardened macro, AXI4-Lite slave
- 8×8 AXI4 crossbar with round-robin arbitration and locked grants
- Dual asynchronous clock-domain-crossing bridges (CPU↔fabric)
- UART, GPIO, timer, interrupt controller, boot ROM, on-chip SRAM
- Multi-clock: CPU 33 MHz / fabric + accelerator 50 MHz

---

## 2. Block diagram

```
            33 MHz                    │  CDC  │              50 MHz
  ┌─────────────────────┐            ╞═══════╡
  │  Rocket RV64IMAC     │ mem_axi4 ──┤  AXI  ├──┐
  │  (hardened macro)    │ mmio_axi4 ─┤  CDC  ├──┤        ┌──────────────┐
  └─────────────────────┘            ╞═══════╡  ├──S0──── │  Boot ROM    │
                                                 │  ├──S1──── │  SRAM        │
                              ┌──────────────────┤  ├──S2──── │  UART        │
                              │  8×8 AXI4         │  ├──S3──── │  GPIO        │
                              │  Crossbar         ├──┼──S4──── │  Timer       │
                              │  (round-robin)    │  ├──S5──── │  Tensor 4×4  │
                              └──────────────────┘  └──S6──── │  (macro)     │
                                                              └──────────────┘
```

---

## 3. Physical characteristics

| Parameter | Value |
|---|---|
| Die area | **7500 × 5500 µm = 41.25 mm²** |
| Rocket CPU macro | 7000 × 2600 µm = **18.2 mm²** |
| Tensor accelerator macro | 1800 × 1800 µm = **3.24 mm²** |
| Hard macros (total) | **21.4 mm² (~52 % of die)** |
| Std-cell glue logic | ~130,500 cells (fabric, CDC, peripherals, clock tree) |
| Placed design area | 23.37 mm² @ ~59 % core utilization |
| Total instances (incl. fill/decap/tap) | ~1.97 M |
| Routing layers | met1–met5 (5-layer Sky130 stack) |
| Std-cell library | `sky130_fd_sc_hd` (high-density) |

---

## 4. Power (preliminary)

Estimated by OpenSTA `report_power` on the post-route, SPEF-annotated netlist at the nominal
(TT, 1.8 V, 25 °C) corner:

| Group | Internal | Switching | Leakage | Total | Share |
|---|---|---|---|---|---|
| Sequential | 68.5 mW | 10.7 mW | 7.3 µW | **79.2 mW** | 30.1 % |
| Combinational | 84.9 mW | 98.5 mW | 1.9 µW | **183 mW** | 69.9 % |
| **Total (fabric/glue)** | 153 mW | 109 mW | 9.1 µW | **≈ 263 mW** | 100 % |

> **Scope note (honest):** this figure covers the **std-cell fabric, peripherals, CDC, and clock
> tree only**. The Rocket CPU and tensor macros report **0 W** here because their abstract
> (LEF/lib) views carry no power models — their internal switching power is **not** included.
> Whole-chip power requires characterizing the two macros separately; treat **263 mW as the
> integration/fabric power**, not the full device.

---

## 5. Clocking & reset

| Domain | Frequency | Period | Contents |
|---|---|---|---|
| CPU | **33 MHz** | 30 ns | Rocket RV64IMAC tile |
| Fabric + accelerator | **50 MHz** | 20 ns | AXI crossbar, tensor core, peripherals, memory |

Domains are bridged by asynchronous FIFO CDC on the Rocket AXI ports. Active-low reset.
Post-route multi-corner static timing **MET at all three corners (ss / tt / ff)**, WNS/TNS = 0.00.

---

## 6. Interconnect bandwidth (peak, theoretical)

| Path | Width × clock | Peak |
|---|---|---|
| AXI4 fabric (per direction) | 128 b @ 50 MHz | **6.4 Gb/s ≈ 0.8 GB/s** |
| Rocket master (mem / mmio, each) | 64 b @ 33 MHz | **2.1 Gb/s ≈ 264 MB/s** (widened to 128 b on fabric) |
| Tensor compute (4×4, int16) | 16 MACs @ 50 MHz | **0.8 G MAC/s ≈ 1.6 GOP/s** |

> Peak figures. The crossbar contract is single-beat, 1 outstanding transaction per master per
> direction, so sustained fabric throughput is below peak. The systolic array is parametric
> (`SIZE`): scaling to 16×16 raises tensor throughput 16× (256 MACs) at proportional area.

---

## 7. Memory map

| Region | Base address | Slave | Notes |
|---|---|---|---|
| Boot ROM | `0x0000_0000` / `0x8000_0000` | S0 | Rocket resets at `0x8000_0000` |
| SRAM | `0x1000_0000` | S1 | On-chip scratch (see §8 for size) |
| UART | `0x2000_0000` | S2 | TX/RX + status |
| GPIO | `0x3000_0000` | S3 | Boot flag / blink |
| Timer | `0x4000_0000` | S4 | |
| **Tensor accelerator** | `0x5000_0000` | S5 | control + buffer + result (see §7.1) |
| DMA registers | `0x6000_0000` | S6 | |

### 7.1 Tensor accelerator register map (base `0x5000_0000`)

| Offset | Reg | Access | Description |
|---|---|---|---|
| `0x00` | `CTRL` | R/W | bit 0 = **START** (write 1 to launch; auto-clears) |
| `0x04` | `STATUS` | R | **DONE** + busy status (sticky done until next start) |
| `0x08` | `A_ADDR` | R/W | source address of matrix A |
| `0x0C` | `B_ADDR` | R/W | source address of matrix B |
| `0x10` | `C_ADDR` | R/W | destination address of result C |
| `0x14` | `CONFIG` | R/W | operation config |
| buffer write | `awaddr[15:12]=1` | W | local-buffer write: `word=awaddr[11:4]`, `lane=awaddr[3:2]` (128-b word from 4×32-b beats) |
| result read | `araddr[15]=1` | R | result read-back: word = `araddr[2 +: log2(SIZE²)]` |

### 7.2 Programming model (bare-metal)

```
1. Load operand matrices A and B into the tensor local buffer
   (AXI writes with araddr[15:12]=1), or set A_ADDR/B_ADDR to source from SRAM.
2. (optional) configure CONFIG.
3. Write CTRL.START = 1   → core_launch pulses, FSM streams operands and runs the
   systolic array (LS_STREAM → LS_RUN → LS_DONE).
4. Poll STATUS.DONE until set (also drives core_done_irq to the interrupt controller).
5. Read the result matrix C via result read-back (araddr[15]=1), word by word.
```

This is the flow exercised end-to-end by the on-chip boot program (`boot/aurora_boot.S`):
the Rocket core initializes matrices, launches the tensor core, polls done, reads `C[0][0]`,
and reports over UART.

---

## 8. Scope, limitations & roadmap

**This is a bare-metal accelerator SoC, by design.** On-chip memory in the taped-out
configuration is **~1 KB boot ROM + ~2 KB SRAM**, and there is no DRAM controller — sufficient
for the boot/accelerator demo, **not** for a Linux-class OS (which needs tens of MB). Software
is bare-metal C/assembly driving the register map in §7. The memory was deliberately shrunk
for a flop-based, macro-free fabric that routes cleanly on the free Sky130 flow; full-size SRAM
returns as compiled macros in a production build.

**Known sign-off waivers (benign, documented):**
- DRC = 1: an isolated nwell fill-tap (`nwell.4`), density/tap-spacing invariant — standard fill ECO.
- LVS: device-perfect match; a 2-net delta from 4 deliberately-unused AXI lock outputs and the
  VPB/VNB body-pin extraction convention — connectivity conventions, not logic defects.

**Roadmap to a production part:** compiled SRAM macros (MB-scale) + a DRAM/AXI memory controller
→ Linux-capable; scale the systolic array (`SIZE` 4→16) for 16× throughput; characterize macro
power for a true whole-chip power figure; close LVS to zero-waiver on production tooling.

---

*Preliminary datasheet — figures from the `chip_route2` sign-off run, 2026-06-24. Subject to
change. © 2026 Yashwanth Kudum; IP available for commercial licensing (see LICENSE).*
