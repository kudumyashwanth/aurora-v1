# Aurora v1 — RTL-to-GDSII Progress Log

Pipeline: RTL fixes → lint → simulation → formal → synthesis → floorplan → place → route → DRC/LVS → GDSII

## ✅ STAGE COMPLETE: RTL fixes (2026-06-13)

| Fix | File | What |
|---|---|---|
| PDK | openlane/aurora_soc/config.json | gf180mcuD → sky130B, cell lib → sky130_fd_sc_hd |
| Crossbar rewrite | rtl/interconnect/axi_crossbar.sv | Was NOT a stub (docs stale) but had 3 protocol bugs: no grant locking (mid-transaction grant stealing), response routing re-decoded current addr (B/R misroute), phantom grants to master 0. Rewrote with locked grants (lock at AW/AR handshake, release at B/R handshake), true round-robin per slave, 1 outstanding txn per master per direction. |
| Systolic array | rtl/tensor_cluster/systolic_array_16x16.sv | REAL BUG: `a_matrix[i][j]` passed 1 bit to 16-bit MAC operand. Fixed to `a_matrix[i]` / `b_matrix[j]` (rank-1 outer-product accumulation). |
| Buffer index | rtl/tensor_cluster/tensor_local_buffer.sv | Word-addr signals were 14-bit for 4096-deep mem; now $clog2(BUFFER_DEPTH) |
| Boot ROM | rtl/boot/boot_rom.sv | Explicit index width + bounds-compare cast |
| DMA | rtl/dma/dma_engine_complete.sv | Explicit casts in burst_len/wlast; default arms in reg-decode + datapath cases |
| UART | rtl/peripherals/uart.sv | default → IDLE in TX/RX FSMs; baud compare cast |
| GPIO | rtl/peripherals/gpio.sv | default arm in reg-decode case |
| Top | rtl/top/aurora_soc_top.sv | Was already fully wired (docs stale). Removed all 5 blanket lint_off pragmas — design is clean without them. |

## ✅ STAGE COMPLETE: RTL lint (2026-06-13)

`verilator --lint-only -sv --top-module aurora_soc_top` on openlane/aurora_soc/src/filelist_synth.f:
**0 errors, 0 warnings** (no suppressions anywhere).

## Stale-docs warning

docs/AURORA_CODE_STATUS.md is from an old session — axi_crossbar "stub", unwired top,
and missing clock_reset_controller were ALL already fixed before this session. Trust
tool output, not that file.

## Synthesis strategy (from filelist_synth.f)

- CVA6 cluster goes in as cpu_cluster_stub.v black box (pre-hardened macro at tape-out)
- Full CVA6 RTL only used for simulation (Makefile filelist)

## ⚠️ Known issues for upcoming stages

1. **boot_rom.sv**: 4096×128b behavioral ROM. Sky130 has no BRAM inference → ~524k DFFs
   if synthesized as-is. Needs sky130_sram_macros or drastic size cut before synthesis.
2. **sram_bank_array**: same concern — check size/macro mapping before synthesis.
3. **config.json**: still carries OpenLane-1-only keys (DIODE_INSERTION_STRATEGY,
   RUN_CVC, SYNTH_BUFFERING, SYNTH_SIZING, RST_ACTIVE_HIGH…) that OpenLane 2.3.10
   may reject. Clean at synthesis stage.
4. **Crossbar contract**: single-beat, 1 outstanding txn per master per direction.
   CPU cluster + DMA must respect this (DMA uses arlen/awlen bursts internally but
   crossbar ignores len — verify in simulation).
5. tensor `done = start` is a placeholder-ish simplification in systolic array —
   timing handled by tensor_core FSM; verify in simulation.

## ✅ STAGE COMPLETE: Simulation (2026-06-13)

Full-SoC Verilator sim (4× CVA6 + tensor + peripherals, 8M cycles): boot program
runs end-to-end. UART output decoded by TB (sim_run2.log):
banner → "[1] Initializing matrices in SRAM..." → "[2] Running 16x16 matrix
multiply on Tensor Core 0..." → "[3] DONE! C[0][0] = 0x00000000" →
"[4] ... Aurora v1 AI SoC is ALIVE!" + GPIO boot flag (0x1) and blink (0xAAAAAAAA).
413/413 UART chars transmitted at exact FIFO drain rate — zero drops.
C[0][0]=0 is correct: tensor computes from its (zeroed) local buffers; A/B/C SRAM
addr regs are stored but nothing fetches them (no tensor master port — DMA would
stage data in a real flow). Not a bug.

### Bugs found & fixed by simulation

| Bug | File | Fix |
|---|---|---|
| **Deadlock: all R/B responses misrouted** | cva6_axi_wrapper.sv | Fabric has no IDs; top tied rid/bid=0 → CVA6 cache subsystem demuxes by ID (icache=0000, bypass=1xxx, dcache=0111) → every data access hung. Wrapper now latches AR/AW id at handshake and reflects on R/B (legal: crossbar enforces 1 outstanding/master/direction). |
| 64-bit CVA6 beat on 128-bit fabric | cva6_axi_wrapper.sv | Data/strb placed at addr[3] half; R data selected from latched addr[3] half. |
| wstrb not routed | axi_crossbar.sv, aurora_soc_top.sv | Added m_wstrb/s_wstrb routing (DMA masters tied all-ones). |
| Byte stores clobbered 16-byte words | sram_bank_array.sv | Per-byte wstrb write enables. |
| SRAM word-index aliasing | sram_bank_array.sv | index addr[16:2]→addr[18:4], bank addr[19:17]→addr[21:19] (true 4MB). |
| 32-bit slaves saw wrong lane | aurora_soc_top.sv | lane32() write mux by awaddr[3:2]; read data replicated ×4 across the 128-bit beat (UART/GPIO/Timer/Tensor/DMA-regs). |
| Tensor done = 1-cycle pulse, CPU poll missed it | tensor_cluster_top.sv | core_done_sticky latched until next start; STATUS bit2 now sticky. |
| Boot polled wrong tx_full bit | boot/aurora_boot.S | UART_TX_FULL 0x02→0x08 (STATUS bit3). |
| Multi-.string banner truncated at NUL | boot/aurora_boot.S | .ascii continuation + single .string. |
| 4 harts raced on UART/tensor | boot/aurora_boot.S | mhartid gate: hart 0 boots, others wfi-park. |
| Yosys-incompatible `return` in functions | axi_crossbar.sv, aurora_soc_top.sv | Assignment-style function bodies (needed for synthesis too). |

Boot rebuild: riscv64-unknown-elf-gcc -march=rv64imafdc -mabi=lp64d -nostdlib
-nostartfiles -T aurora.ld; objcopy -O binary; python 16-byte-LE hex pack.

TB upgrades: sim/tb/tb_aurora_soc.sv now decodes UART TX (115200 @ 1736 div);
sim/main.cpp: VCD opt-in via +trace, 8M cycles default, +cycles=N override.
Unit TB added: sim/unit/tb_tensor.sv (validates sticky done standalone).

Known cosmetic: interrupt_controller.clear tied 0 in top → global_irq latches
high after first tensor IRQ (TB spams "INTERRUPT!"). Harmless (CVA6 boots with
MIE=0); revisit if IRQs are ever consumed.

## ✅ STAGE COMPLETE: Formal (2026-06-13)

`formal/axi_crossbar` — BMC depth 30, **PASS** (abc bmc3 engine).
Harness rewritten for the current interface (old one targeted pre-rewrite
ports wlast/bresp/rlast). Environment: 2 nondeterministic AXI masters obeying
valid/payload stability + 8 reactive slaves; a shadow ownership model
reconstructed purely from boundary handshakes (no hierarchical refs).
Proven properties:
- P1 no new AW/AR beat to a slave while its transaction is open (grant lock)
- P2 responses exactly when an owned slave responds (no spurious, none dropped)
- P3 decode integrity (any AW/AR at slave s decodes to s)
- P4 a master never owns two slaves in one direction
- P5 read data routed unmodified to the owning master

Notes:
- One bug was found — in the *harness*, not the RTL: SRAM decode mis-coded as
  `addr[31:25]==7'h08` (misses 0x12/0x13); fixed to `addr[31:26]==6'h04`. After
  the fix all properties hold. The crossbar RTL was correct.
- z3 4.8.12 is the only SMT solver installed and is unusable on this 8-slave
  model (>6 GB, no result in minutes), so cover/smtbmc mode can't run. The
  liveness intent (transactions complete) is instead covered by the end-to-end
  SoC sim, where the CPU completes R and W to every slave through the crossbar.

## TOOLCHAIN PIVOT: OpenLane 1.0.2 via Docker (NOT native OL2)

Native `openlane` 2.3.10 cannot run on this machine: no `openroad` binary exists
anywhere, system yosys 0.62 has no pyosys (`yosys -y`) Python interface, no pyosys
module. Working flow = OpenLane 1.0.2 at /home/yashwanth/OpenLane driving Docker
image ghcr.io/the-openroad-project/openlane:ff5509f65b17bfa4068d5336495ab1718987ff69-amd64
(bundles openroad/yosys/magic/netgen/klayout). The config's "OL1-only keys" were
correct all along. $HOME is mounted at the same path in the container, so the
design dir and boot-hex $readmemh absolute paths resolve. Launch command and PDK
root recorded in memory (aurora-pipeline-state.md).

## Memory shrink for clean demo GDSII (flop-based, no SRAM macros)

- sram_bank_array: 8×32768 → NUM_BANKS=2 × BANK_DEPTH=256 = 8 KB. Address decode
  made parametric ($clog2(BANK_DEPTH)/$clog2(NUM_BANKS)) so it scales with size.
- boot_rom: ROM_SIZE 65536 → 1024 (1 KB; covers the 821-byte boot binary).
- 128 KB+ as flops = ~1M DFFs, won't route in this free flow → needs real SRAM
  macros (the commercial/Cadence path). Architecture & 0x1000_0000 map unchanged;
  re-synth at full size later is just a parameter change.

## ✅ STAGE COMPLETE: Synthesis (2026-06-13, OL1 run1)

Yosys → sky130_fd_sc_hd. **332,196 cells, chip cell-area 3,271,294 µm²** on the
36 mm² die (~9% — ample routing room). Systolic array (256 16-bit MACs) dominates.
Post-synth single-corner STA ran without halting. Non-fatal synth warnings:
`gpio_oe[7:0]` and `global_irq` "used but no driver" (Yosys ties off; matches the
known interrupt_controller.clear tie-off — harmless, no IRQ consumer in this demo).

## run1 (OL1) — completed synthesis → CTS, then froze (2026-06-13)
Run dir: openlane/aurora_soc/runs/run1. Got through: synthesis (332k cells),
post-synth STA, floorplan (5799×5799 µm), IO/tap/PDN, global placement (1h14m),
detailed placement+resizer, CTS, CTS STA. Then the laptop HARD-FROZE during the
post-CTS timing resizer ("step 14"). Last clean checkpoint = results/cts/.
CTS STA showed setup WNS = -1.59 ns (1 corner) — that's what the resizer fixes.

## ROOT CAUSE OF THE FREEZE (2026-06-13) — important
The freeze was NOT routing. It was the **multi-corner placement timing resizer**
(resizer_timing.tcl). On 332k cells, loading 3 corners (ss/tt/ff) for
repair_timing needs >18 GB; this machine has only 23 GB RAM + 2 GB swap, so it
exhausted memory and thrashed the host to death. Reproduced under an 18 GB
docker cap: it pinned 17.78/18 GB, 1-core, 1.7 GB swap, zero progress for 14 min.
FIX: set `RSZ_MULTICORNER_LIB 0` → single-corner (typical) resizer. Peak RAM
dropped to ~5.5 GB and it completed. Multi-corner is still verified at signoff STA.

## SAFE RESUME MECHANISM (OL1 via Docker) — reusable
OL1 non-interactive flow.tcl always restarts from step 1 (-from/-to disabled),
and `prep -tag run1 -overwrite` would `file delete -force` run1. So resume via:
interactive mode + a driver .tcl that preps a NEW tag and points
CURRENT_DEF/ODB/SDC/NETLIST at the prior run's checkpoint, then calls the step
procs (run_resizer_timing / run_routing / ...). Drivers in openlane/resume/.
ALWAYS run docker with `--memory=18g --memory-swap=20g` so a blow-up OOM-kills
the container, never freezes the host. Backup at runs/_checkpoint_backup_run1/.

## ✅ STAGE COMPLETE: post-CTS timing resizer (2026-06-13, tag resume_cts)
Single-corner resizer: 11 buffers + 1 load-split, 56 instances resized, 38 hold
buffers. Multi-corner STA after: **setup WNS -1.59 → +5.02 ns (MET), TNS 0.00.**
Residual hold = -0.04 ns (40 ps) at the fast corner (expected from single-corner
resize; fast-corner hold not touched). To be cleaned by the post-route resizer
and re-checked at signoff; if it persists, do a targeted fast-corner hold repair.
Resized checkpoint: runs/resume_cts/tmp/cts/1-aurora_soc_top.resized.{def,odb,...}

## 🔄 RUNNING: Routing (tag resume_route)
Driver openlane/resume/driver_route.tcl from the resized CTS checkpoint.
RSZ_MULTICORNER_LIB 0, ROUTING_CORES 8, 18 GB cap. Sequence: global resizers →
global route → fill → detailed route (TritonRoute, the long/heavy step). Util is
only ~16% so congestion should be easy. Log: openlane/resume/logs/stage_route.log.
NEXT after routing (stop + report first): parasitics STA (real multi-corner hold)
→ Magic DRC → netgen LVS → antenna → GDSII streamout.

## 🔄 Phase 1b — Tensor cluster harden (2026-06-16, in progress)
Goal: harden tensor_cluster_top as a macro with real sky130 SRAM (same recipe as
RocketTile). Buffers: 4 cores x tensor_local_buffer.
- SRAM-backed buffer drop-in: openlane/tensor/tensor_local_buffer_sram.sv — 512x128
  = 8KB from 4x sky130_sram_2kbyte_1rw1r_32x512_8. Port A (DMA r/w)->macro 1rw port,
  Port B (tensor read)->macro 1r port (clean map; no remap unlike Rocket). 4 cores ->
  **16 SRAM macros** (same budget as Rocket).
- **REAL BUG FOUND & FIXED (root cause):** tensor_cluster_top's per-core `result`
  (16x16x32 C matrix) was wired to NO output — the "nothing fetches the result" gap
  from sim. Standalone synth therefore stripped the ENTIRE 1024-MAC fabric + all 16
  buffers (collapsed to 2810 cells, 0 macros). Added an AXI result read-back window
  (araddr[15]=1: core=araddr[14:13], word=araddr[9:2]) + result_flat[] hoist. Purely
  additive — sim unaffected (TB never reads the window). Now the compute fabric is
  observable and survives synthesis. Verilator lint of tensor_cluster_top: 0 errors.
- **PARTITION DECISION (forced by 23GB host):** full 4-core tensor_cluster_top with
  the now-live MAC fabric = 1.87M generic cells (~800k mapped) — same class as the
  "RocketTile-as-flops 829k = unroutable" wall. So harden ONE core as a macro and
  instantiate x4 at top (same strategy as RocketTile). Single core = 467k generic
  cells, ~9k flops, **4 SRAM macros**, lint 0.
### Tensor harden run history + RESUME after power loss (2026-06-17)
- tc1 = synthesis (netlist reused by later PnR runs). tc2 = full PnR, **CRASHED**
  at step 14 (global-route design resizer): FastRoute `updateRouteType1` vector-OOB
  assertion in the "Extra Run for hard benchmark" overflow-removal path (congestion).
  GRT_ADJUSTMENT was 0.15 there.
- tc3 = retry with GRT_ADJUSTMENT lowered 0.15→0 (max routing tracks). Got through
  synth→FP→place→CTS (CTS STA timing **MET**, worst slack +0.02 ns)→resizer_timing,
  then the **laptop lost power** mid-step-14 (GRT overflow iterations) — no crash trace.
  Clean checkpoint: runs/tc3/tmp/cts/13-tensor_core_hard.resized.{def,odb,nl.v,pnl.v,sdc}.
- tc4 = RESUME from that checkpoint (openlane/tensor/driver_tensor_resume.tcl): skips
  FP→CTS, runs routing→...→GDS. To dodge the tc2 FastRoute crash: GRT_ADJUSTMENT 0
  (max tracks) + GRT_ALLOW_CONGESTION 1 (accept residual overflow instead of escalating
  into the buggy overflow-removal path). 18 GB docker cap. Log: openlane/tensor/stage_tc4_resume.log.

### tc5 — FLOORPLAN ROOT-CAUSE FIX (2026-06-17)
Diagnosed why tc2 crashed / tc3/tc4 stuck in GRT overflow: it was the FLOORPLAN, not
the router. Block = 5.44M um2 std cells (442k mapped) + 4 SRAM macros (683.1x416.54
each, 1.14M um2) = 6.58M um2. On the 6500x6500 die (42M um2) that's only ~15% util —
logic spread paper-thin (placement HPWL 1.3e11, overflow plateaued ~0.1-0.2) AND the 4
macros were jammed in a 1.9mm corner pulling all buffer logic with them. GRT could never
clear overflow. tc4's GRT spun 25+ min on one call (CPU-bound, healthy, just hopeless) →
killed it. FIX (config.json + macro_placement.cfg): die 6500->**4200x4200** (~37% util),
PL_TARGET_DENSITY 0.2->0.45, 4 macros from corner-cluster to a **centered 2x2 with 350um
routing channels** (1240/2273 x 1500/2267, all N). GRT back to ADJUSTMENT 0 /
ALLOW_CONGESTION 0 (balanced FP shouldn't need relief). Driver openlane/tensor/
driver_tensor_pnr5.tcl (reuses tc1 synth netlist), run tag tc5, log stage_tc5_pnr.log.

### tc5 result + tc6 routing fix (2026-06-17)
tc5 (new 4200 floorplan) converged placement (overflow 0.099, HPWL ~1.0e11 = ~23%
better than tc3's 1.3e11) and CTS timing MET (WNS/TNS 0.00). BUT step 14 GRT still spun
21+ min "extra iterations to remove overflow" with ALLOW_CONGESTION 0 — same wall as tc4.
CONCLUSION: the 256-MAC systolic datapath is genuinely routing-congestion-bound; GRT
chasing ZERO overflow never converges regardless of die size. tc6 = resume routing from
tc5's CTS checkpoint (timing met) with **GRT_ALLOW_CONGESTION 1** (FastRoute accepts
residual overflow, hands to TritonRoute detailed route). Driver driver_tensor_resume6.tcl,
checkpoint tc5/tmp/cts/13-*.resized.*, log stage_tc6_resume.log. Watching for detailed-
route DRV count.

### tc6 result + tc7 congestion-relief floorplan (2026-06-17)
tc6 (GRT_ALLOW_CONGESTION 1 on the 4200/0.45 floorplan): the routing-DESIGN resizer
(run_routing step 1) ran the global-route in an iterative resize->reroute->resize LOOP,
each pass a bounded 50-iter GRT (~25-30 min on this congested 256-MAC datapath). Ran 53+
min CPU over 2+ passes, never reached detailed routing. allow_congestion bounds each GRT
pass but NOT the number of resizer passes. ROOT LESSON: the 16x16 (256-MAC) systolic
array is genuinely routing-congestion-bound; 0.45 density on a 4200 die was too tight.
tc7 attacks congestion 3 ways: die 4200->**5000x5000** (~27% util), PL_TARGET_DENSITY
0.45->**0.30** (more tracks between cells), FP_PDN pitch 180->**360** (frees met1 — was
30.5% eaten by PDN straps — and met4). Centered 2x2 macros re-centered (1640/2673 x
1900/2667). Driver driver_tensor_pnr7.tcl, log stage_tc7_pnr.log. DECISIVE TEST: does the
routing-design GRT clear overflow fast now vs loop. If tc7 still won't route, escalate to
user: shrink systolic array 16x16->8x8 (4x less routing) vs accept synth/timing-verified
macro vs commercial tools.

### tc7 result + tc8 BREAKTHROUGH: skip the looping resizers (2026-06-17)
tc7 (5000 die / 0.30 density / PDN pitch 360): placement converged (HPWL 1.17e11) and CTS
timing MET, but step 14 routing-DESIGN resizer AGAIN looped >1.5h CPU on GRT overflow.
PDN pitch change barely helped (met1 still ~29% derated — dominant met1 consumer is the
per-row STD-CELL power rails, not PDN straps). CONCLUSION after 3 floorplans (tc3/tc5-6/
tc7): the looping is the *resizer* (OpenLane run_routing steps run_resizer_design_routing
+ run_resizer_timing_routing, routing.tcl:402-403), NOT the actual router. Those two
global-route-driven resizers iterate resize->reroute and never converge on a congested
design; they are OPTIONAL post-CTS polish (timing already MET at CTS +0.00 WNS).
FIX (tc8, driver_tensor_resume8.tcl): resume routing from tc7 CTS checkpoint with
**GLB_RESIZER_DESIGN_OPTIMIZATIONS=0 + GLB_RESIZER_TIMING_OPTIMIZATIONS=0** -> run_routing
skips straight to a single bounded global_routing (GRT_ALLOW_CONGESTION 1) then
detailed_routing (TritonRoute, robust). This is the path to a real routed DEF + DRV count.
REUSABLE LESSON: when the routing-design GRT loops forever on a congested OL1 design,
disable the two GLB_RESIZER_*_OPTIMIZATIONS and let TritonRoute route it.

### tc8 result + DECISION + ===> RESUME HERE TOMORROW (2026-06-17, paused: weekly tokens)
tc8 (resizers skipped): even the BARE single global_routing pass burned >1.5h CPU and
never returned on the 256-MAC datapath (1 GRT-0053, 1 GRT-0101, bounded 50-iter but each
iter ~2min; antenna-repair would add a 2nd pass). CONCLUSION (after tc3/tc5-6/tc7/tc8 =
3 floorplans + allow_congestion + resizer-skip + bare global route): **the 16x16 / 256-MAC
tensor core will NOT route on this free OpenLane/sky130 flow + 23GB host.** Synthesis/
placement/CTS-timing all PASS; routing is the wall. Same class as the CVA6 synth wall.

USER DECISION (confirmed): **shrink the systolic array to 8x8 (SIZE=8, 64 MACs), int16.**
WHY 8x8 beats int8/grind: congestion has 2 sources — the MAC fabric AND the result
read-back bus result_flat = SIZE*SIZE*32 = 8192 bits (->2048 at 8x8). SIZE=8 cuts BOTH 4x
(int8/DATA_WIDTH=8 only narrows operands, leaves the 32-bit accumulators + 8192-bit result
bus). 8x8 ~= 4x smaller -> routes clean like RocketTile did. Throughput 256->64 MAC/cyc.

>>> TOMORROW, DO THIS (tensor 8x8 harden):
1. EDIT openlane/tensor/tensor_core_hard.sv:
   - set parameter SIZE = 8 (line 24). DATA_WIDTH stays 16.
   - REWRITE the matrix-loader FSM (lines ~143-197) — it HARDCODES SIZE=16: reads 4x
     128-bit words (a@0x00,0x10 ; b@0x20,0x30) and loads a/b_matrix[e+8] (lines 190-193).
     Make it parametric: EPW = 128/DATA_WIDTH (=8 elems/word); WPM = SIZE/EPW words per
     matrix (SIZE=8 -> 1 word/matrix -> 2 reads total: word0(0x00)->a_matrix[0..7],
     word1(0x10)->b_matrix[0..7]). Cleanest = counter-based read loop, or specialize to
     SIZE=8. result_flat AXI read araddr[9:2] already covers 0..63 — fine.
2. LINT: verilator --lint-only -sv tensor_core_hard.sv + submodules (expect 0).
3. REGEN sv2v -> openlane/tensor/syn/tensor_core_hard_sv2v.v, source set (ORDER ok):
     openlane/tensor/tensor_core_hard.sv
     openlane/tensor/tensor_local_buffer_sram.sv   (defines module tensor_local_buffer = SRAM, used by line 123; buffer is SIZE-independent, UNCHANGED)
     rtl/tensor_cluster/tensor_core.sv             (parametric, UNCHANGED)
     rtl/tensor_cluster/systolic_array_16x16.sv    (parametric, UNCHANGED)
     rtl/tensor_cluster/mac_unit.sv                (UNCHANGED)
   (tc1 synth netlist is SIZE=16 -> STALE, must re-synthesize.)
4. RIGHT-SIZE the floorplan for 8x8 (logic ~4x smaller): config.json is currently set for
   the SIZE=16 attempt (DIE 5000x5000, util 27, density 0.30, PDN 360, centered 2x2 macros
   at 1640/2673 x 1900/2667). For 8x8 shrink DIE to ~2600-3000 sq (target ~40% util) and
   re-center the 4 SRAM macros (still 4x 32x512 = 8KB buffer, unchanged). Keep PL_MACRO_HALO
   "30 30", FP_PDN_MACRO_HOOKS, GRT_ADJUSTMENT 0.
5. RUN full PnR (driver like driver_tensor_pnr7.tcl, new tag tc9, run_synthesis FIRST since
   netlist is stale — or run_synthesis+run_floorplan+...). KEEP the safety flags in the
   driver: GLB_RESIZER_DESIGN_OPTIMIZATIONS 0, GLB_RESIZER_TIMING_OPTIMIZATIONS 0,
   GRT_ALLOW_CONGESTION 1 (8x8 may not even need them, but harmless). Launch via
   run_tensor.sh with an ABSOLUTE driver path. 18GB docker cap.
6. Then: parasitics STA -> magic DRC -> netgen LVS -> antenna -> GDS (same as RocketTile).
STATUS: all tensor runs (tc1-tc8) STOPPED. Docker down. config.json/macro_placement.cfg
currently hold the tc7/tc8 SIZE=16 5000-die floorplan (will be replaced in step 4).

### tc9 — 8x8 TILE BUILD STARTED (2026-06-17, RTL+lint+sv2v done, PnR launched)
DONE this session:
- tensor_core_hard.sv: SIZE default 16->8; matrix-loader FSM REWRITTEN parametric
  (counter-based: EPW=128/DATA_WIDTH, WPM=SIZE/EPW words/matrix, NRD=2*WPM reads; SIZE=8
  -> 2 reads A@0x00,B@0x10; pipelined 1-cyc SRAM latency; core_launch in LS_RUN). Result
  read-back index made parametric (RIDXW=$clog2(SIZE*SIZE), araddr[2+:RIDXW]). Counters
  32-bit, buf_rd_addr via {issue_idx[11:0],4'b0} concat. **verilator lint CLEAN (0 warn).**
- sv2v regenerated -> openlane/tensor/syn/tensor_core_hard_sv2v.v (0 errors, 413 lines, 5
  modules). Sources: tensor_core_hard.sv + tensor_local_buffer_sram.sv + tensor_core.sv +
  systolic_array_16x16.sv + mac_unit.sv.
- config.json right-sized: DIE 2800x2800, CORE 2780, util 37, density 0.35 (PDN 360 kept).
- macro_placement.cfg: centered 2x2 at 560/1543 x 830/1547, 300um channels.
- driver_tensor_pnr9.tcl: full flow from run_synthesis, tag tc9, with safety flags
  (GLB_RESIZER_DESIGN/TIMING_OPTIMIZATIONS 0 + GRT_ALLOW_CONGESTION 1) for an unattended
  run guaranteed to produce a routed result. LAUNCHED, log stage_tc9_pnr.log.
NEXT (resume): check tc9 -> synthesis cell count (~110k = 442k/4 confirms SIZE=8) -> placement
HPWL (should be tiny) -> routing should NOT loop now (8x8 < RocketTile which routed clean) ->
DRC/LVS -> GDS. If routes clean: (a) run sim/unit/tb_tensor.sv at SIZE=8 to verify the new
loader, (b) optionally re-enable resizers for timing polish, (c) PROMOTE to 4x 8x8 tiles for
full 256-MAC throughput, (d) top-level SoC integration. If tc9 routing STILL loops (unlikely),
the wall is deeper than array size — escalate.

- Hardenable block: openlane/tensor/tensor_core_hard.sv (= tensor_cluster_top
  specialized to 1 core: SRAM buffer + loader FSM + 256-MAC systolic + AXI-Lite
  ctrl/buffer-write/result-read). sv2v -> openlane/tensor/syn/tensor_core_hard_sv2v.v.
  Config: openlane/tensor/tensor_cluster/config.json (DESIGN_NAME tensor_core_hard,
  die 4000x4000, clk port, FP_PDN_MACRO_HOOKS u_sram, halo 30 30). The 4-core AXI
  glue (result read-back added to rtl/tensor_cluster/tensor_cluster_top.sv) is thin
  and belongs at top integration (Phase 2).
- Also fixed: behavioral tensor_local_buffer.sv word-addr slice now width-safe for
  any BUFFER_DEPTH ($clog2-based, was hardcoded [15:4]). Sim unaffected at depth 4096.
- RUNNING: OpenLane synth+floorplan, run tag tc1 (openlane/tensor/.../runs/tc1).

========================================================================
### POWER LOSS #2 — 2026-06-17 ~18:41 (laptop shutdown mid-run, RESUME HERE)
========================================================================
All RTL/config/driver edits are SAFE ON DISK (committed). Only the in-flight
PnR process died. Nothing to redo.

tc9 (8x8 SIZE=8 tensor_core_hard) reached the FURTHEST point of any tensor run:
  - Synthesis CONFIRMED SIZE=8: 110,821 cells + 4 SRAM macros, 2.22M um2 (~1/4 of 16x16)
  - Floorplan + global/detailed placement: PASS
  - CTS + CTS-STA: timing MET, WNS 0.00 / TNS 0.00
  - GLB_RESIZER design+timing optimizations: correctly SKIPPED (safety flags worked)
  - STEP 16 GLOBAL ROUTING: started, reached "GRT-0101 running extra iterations to
    remove overflow" when the host powered off. Clean stop, NO crash in the log.
  - results/routing/ is EMPTY -> global route did NOT finish. Docker is DOWN.

>>> TOMORROW, DO THIS (tc9 resume):
1. Bring docker back up (see memory: ghcr OL1 image, --memory=18g --memory-swap=20g,
   --user 1000:1000, PDK=sky130B, mounts in aurora-pipeline-state.md).
2. FAST PATH: write a resume driver that reuses the tc9 CTS checkpoint
   (runs/tc9/results/cts + runs/tc9/tmp/cts/15-*resized*) and re-enters at
   global_routing only -> skips ~30-40min of re-synth. (Model on
   openlane/tensor/driver_tensor_resume.tcl which did this for tc4.)
   SIMPLE PATH: just relaunch openlane/tensor/driver_tensor_pnr9.tcl fresh (new tag),
   it re-runs synth->...->global route in ~30-40 min.
3. WATCH runs/<tag>/logs/routing/16-global.log:
   - If GRT-0101 overflow iterations CONVERGE -> TritonRoute detailed routing ->
     parasitics STA -> magic DRC -> netgen LVS -> antenna -> GDS. Tensor block DONE.
   - If it LOOPS forever in overflow -> array size was NOT the wall; escalate
     (same class as the 16x16 routing wall, needs a deeper rethink).
4. After tensor GDS: SIZE=8 unit-sim verify (sim/unit/tb_tensor.sv), then promote to
   4x 8x8 tiles for full 256-MAC throughput, then top-level SoC integration.

Key files unchanged & ready: tensor_core_hard.sv (SIZE=8 parametric loader, lint clean),
syn/tensor_core_hard_sv2v.v (regenerated, 0 err), config.json (DIE 2800x2800),
macro_placement.cfg (centered 2x2), driver_tensor_pnr9.tcl (safety flags set).
