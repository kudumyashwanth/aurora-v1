# Aurora v1 — Debug Playbook (methods, errors, and how we solved them)

A reusable reference of problems hit during RTL→GDSII, how we diagnosed them, the exact fix, and
*why* it worked. Format per entry: **Symptom → Diagnosis method → Fix → Why it worked**.
Newest/most-important first. See also docs/PROGRESS.md (chronological log).

Tools used throughout: Verilator 5.046, Icarus, Yosys 0.62, OpenLane 1.0.2 via Docker
(image ghcr.io/the-openroad-project/openlane:ff5509f65b17bfa4068d5336495ab1718987ff69-amd64,
bundles OpenROAD/Magic/netgen/klayout), sv2v 0.0.12, mill 0.11.7 + firtool 1.62.1 (rocket-chip
Chisel→Verilog), riscv64-unknown-elf-gcc. PDK sky130B.

---

## 0. HOST FREEZE / OOM (the #1 hazard on this 23 GB machine)

**Symptom:** laptop hard-freezes (had to power-cycle) during heavy OpenLane steps — synthesis (Yosys
ABC), the multi-corner placement timing resizer, or detailed routing.

**Diagnosis:** machine has 23 GB RAM + only 2 GB swap. Big steps blow past physical RAM → the kernel
thrashes the *host* to death (not just the job). Confirmed: 3-corner repair_timing on 332k cells
needs >18 GB; Rocket-subsystem Yosys ABC run uncapped took the host down at ~15:27 (2026-06-22).

**Fix (ALWAYS do this):**
1. Launch every OpenLane Docker run with a memory cap so a blow-up OOM-kills the *container*, not the
   host: `docker run --memory=18g --memory-swap=20g ...`. The generic launcher
   `openlane/tensor/run_tensor.sh <abs-driver.tcl>` already has this — reuse it for ANY design
   (it just runs `./flow.tcl -interactive < driver`).
2. `RSZ_MULTICORNER_LIB 0` for the *placement* timing resizer on big designs (single-corner ~5.5 GB
   vs >18 GB multi-corner; multi-corner is still verified later at signoff STA).
3. `ROUTING_CORES 4` (not 8) to keep detailed-route peak memory under the cap.

**Why it works:** the cap converts a host-killing OOM into a recoverable container kill. You lose the
run, not the machine.

**Driver path gotcha:** the container cwd is `/openlane`, so the driver `.tcl` path passed to
run_tensor.sh MUST be absolute (`/home/yashwanth/aurora_v1/...`).

### Watching a long run without polling by hand
Launch a background poll-loop (Bash `run_in_background: true`) that `sleep`s 30s and `break`s on a
state change (next `[STEP n]`, `AXI5_DONE`, an error regex, or `docker ps` empty). The harness
re-invokes you when it exits — so you get woken on real events, not on a timer. (Foreground `sleep`
is blocked; it only works in a backgrounded command.)

---

## 1. ROCKET WON'T BOOT — the multi-session wall (SOLVED 2026-06-22)

This looked like an intractable rocket-chip PMA problem for several sessions. It was actually **two
ordinary bugs**. Debugged entirely in a LIGHT isolation sim (no OpenLane, no freeze risk).

### Method: the isolation sim (the right debug tool)
`sim/tb/tb_rocket_iso.sv` instantiates the macro (`RocketAXITileTop`) on simple AXI4 BFMs:
ROM @0x80000000 (boot hex via `$readmemh`), SRAM @0x10000000, MMIO sink that prints UART writes.
Probes the tile trace port (`...trace_source_out_insns_0_{valid,iaddr,exception,cause}`) to see
exactly what the core retires and any trap cause. Build: `verilator --cc --exe --build -j4 --trace
--no-timing -Wno-fatal -o Vtb_rocket_iso --Mdir build_iso --top-module tb_rocket_iso <netlist.v>
sim/models/rocket_sram_behav.v sim/tb/tb_rocket_iso.sv sim/main_iso.cpp` (~20 s, ~600 MB). Run:
`./build_iso/Vtb_rocket_iso +cycles=4000000`.
KEY: the bare tile boots from an EXTERNAL BFM ROM, so it CAN be sim-verified. A rocket-chip
*subsystem* can't (its internal bootrom code is stripped by the -DSYNTHESIS/sv2v netlist) — that's
why we use the bare tile, not a subsystem.

### Bug 1A — instruction access fault @ low addresses (cause=1 at PC=0)
**Symptom:** core resets, is clocked, reset-vector correct, but immediately `exc=1 cause=1` (instr
access fault), never fetches.
**Diagnosis:** trace showed the trap at the reset address. rocket-chip bakes DEVICE regions into the
tile PMA at low addresses as **non-executable**: debug @0x0, bootrom @0x10000, CLINT @0x2000000,
PLIC @0xc000000. Booting at 0x0 collides with the debug region.
**Fix:** set the reset vector + executable memory to **0x80000000** (clear of all device regions).
In `RocketAXITileTop.scala`: `outer.resetVectorSource.bundle := "h80000000".U`.
**Why:** 0x80000000 is normal external memory in rocket's default map, so it's executable.

### Bug 1B — coherence termination (cork vs broadcast)
**Symptom:** with a bare `TLCacheCork(unsafe=true)` terminating the L1 master, fetch faults even at
0x80000000 (region presented as UNCACHED; the Rocket frontend can't execute from uncached memory).
**Fix:** replace the cork with **`TLBroadcast(lineBytes=64)`** (the standard coherence manager).
**Why:** `Broadcast.scala` upgrades an UNCACHED downstream region to `RegionType.TRACKED` +
`supportsAcquireB/T` upstream → the L1 sees CACHEABLE memory it can fetch/load from.

### Bug 1C — DATA load access fault (cause=5) at the first banner `lb` ★ the real root cause
**Symptom:** after 1A/1B, the core *executes* instructions from 0x80000000 fine, then `exc=1 cause=5`
(load access fault) at the first `lb` that reads a string from ROM. "Fetch works, data read faults
on the same region" → looked like incomplete PMA (prior sessions mis-blamed the bare tile and pivoted
to a subsystem — WRONG).
**Diagnosis:** disassembled the boot. `la a0, msg_banner` (line 62 of boot/aurora_boot.S) expands in
non-PIC code to `lui+addi` = an **ABSOLUTE** address based on the LINK ORIGIN. The linker script
`boot/aurora.ld` had `ROM ORIGIN = 0x0`, so data refs pointed at **0x0** = the debug device region →
load fault. Instruction fetch is PC-relative so it ran at 0x80000000; only DATA addressing used the
stale 0x0 base.
**Fix:** relink ROM at 0x80000000: `boot/aurora.ld` `ROM : ORIGIN = 0x80000000`. Rebuild +
regenerate the 64-bit ROM hex:
```
riscv64-unknown-elf-gcc -march=rv64imac -mabi=lp64 -nostdlib -nostartfiles -T aurora.ld aurora_boot.S -o aurora_boot.elf
riscv64-unknown-elf-objcopy -O binary aurora_boot.elf aurora_boot.bin
python3 -c "d=open('aurora_boot.bin','rb').read(); d+=b'\x00'*((-len(d))%8); open('aurora_boot_rom64.hex','w').write(''.join(f'{int.from_bytes(d[i:i+8],\"little\"):016x}\n' for i in range(0,len(d),8)))"
```
**Why:** with code AND data at 0x80000000 (clear of all device regions), `la`'s absolute addresses
land in real cacheable memory. cause=5 disappeared; core ran the whole data path. MMIO bases (UART
0x20000000 / GPIO 0x30000000 / tensor 0x50000000 / SRAM 0x10000000) are absolute `.equ` constants →
unaffected by the relink; only ROM (.text/.rodata via `la`) moves.

### Bug 1D — MMIO writes vanish (banner doesn't print) ★ second real root cause
**Symptom:** after 1C, the core runs and reaches the UART, but only ~1 of ~150 banner chars appears
on the bus (instrumented the tb to count UART writes).
**Diagnosis:** the wrapper declared the WHOLE 0–4 GB as ONE region; `TLBroadcast` makes ALL of it
cacheable. So UART stores were absorbed by the write-back L1 dcache and never reached the bus.
**Fix:** split the address map in `RocketAXITileTop.scala` — a `TLXbar` after the tile master fans
out by address into TWO AXI masters:
- **mem_axi4** (cacheable): ROM 0x80000000 + SRAM 0x10000000, through `TLBroadcast`.
- **mmio_axi4** (uncached): UART/GPIO/tensor (0x20000000/0x30000000/0x50000000), NO broadcast.
**Why:** memory must be cacheable (else fetch/load fault, per 1B/1C); MMIO must be uncached (else
stores get cached and never reach the device). They're mutually exclusive → two regions. After this,
the FULL UART banner printed in the iso-sim. (This is exactly what a rocket-chip subsystem's
mbus/mmio split gives for free — but the bare tile is lighter and sim-verifiable.)

### RESULT
Bare-tile `RocketAXITileTop` with reset-vector 0x80000000 + TLBroadcast + 2-port mem/mmio split
BOOTS and prints the banner in the iso-sim. Re-elaborate: `cd tools/rocket-chip; PATH=tools/bin:$PATH
mill "emulator[freechips.rocketchip.system.RocketAXITileTop,freechips.rocketchip.system.AuroraIMACConfig].mfccompiler.compile"`.

---

## 2. ROCKET 2-PORT RE-HARDEN RECIPE (run axi5)

**Method:** wrapper changed → axi1 netlist stale → FULL re-synth + PnR. Driver
`openlane/rocket/driver_rocket_axi5.tcl` (full flow run_synthesis…save_final_views). Recipe = the
proven imac33/axi2 floorplan: DIE 7000x2600, 2-row macro layout, 30 ns (33.3 MHz), PL_TARGET_DENSITY
0.35, FP_TAPCELL_DIST 10, ROUTING_CORES 4, GRT_ADJUSTMENT 0.1, GRT_ALLOW_CONGESTION 0,
RSZ_MULTICORNER_LIB 1. SDC = the CLEAN clock-only `rocket_clean_33mhz.sdc` (NOT synthesis.sdc — it
has set_driving_cell → STA-0574). Reused `macro_placement_axitile.cfg` unchanged (the master-path
edit doesn't touch the tile-internal SRAM hierarchy `tile_prci_domain.element_reset_domain_rockettile.*`).

**Sv2v for the iso-sim/synth:** `cd <mfccompiler compile.dest>; sv2v -DSYNTHESIS *.sv plusarg_reader.v
> openlane/rocket/syn/rocket_axitile_mem_clean.v`. The SRAM `_ext` modules are extern (defined by
`rocket_sram_ext.v` for synth / `sim/models/rocket_sram_behav.v` for sim).

**Result (axi5):** route 0 violations; SPEF extracted clean (203,847 nets); multi-corner post-route
STA WNS 0.00 MET @30 ns. (DRC/LVS/GDS = tail end.)

---

## 3. DETAILED ROUTE — don't panic on a high INITIAL violation count

**Symptom:** TritonRoute opened detailed routing with ~178k violations (axi5, the 2-port macro added a
second MMIO bus + ~100 pins on a floorplan sized for the leaner 1-port version).
**Diagnosis:** watch the **per-iteration DRT-0199 "Number of violations"** trend, not the absolute
count. axi5: 178k → 170k → 136k → … → 14 → 3 → 1 → 0. Monotonic DECREASE = converging.
**Key distinction:** the tensor-16×16 routing wall FAILED because violations GREW/plateaued
(1.1M → 1.3M → diverging). A high but monotonically falling count just means the router is grinding
through congestion; let it run. Only if it PLATEAUS/GROWS do you intervene (roomier floorplan: bigger
die or lower PL_TARGET_DENSITY to give signals room).

---

## 4. RECURRING OPENLANE / SKY130 GOTCHAS (from earlier blocks, kept handy)

- **OpenRCX "RCX-0107 Nothing extracted"** at large instance counts (~1.3M fill cells, e.g. the 8×8
  tensor at 0.15 density): a SCALE artifact, not the design. Mid-density floorplans (~350k insts,
  e.g. 4×4 tensor, or the Rocket 7000x2600) extract fine. If a missing SPEF aborts the flow, the
  patch in `OpenLane/scripts/openroad/common/io.tcl:196` guards `read_spef` with `[file exists ...]`.
- **Congested systolic-datapath routing recipe** (8×8 tensor breakthrough, tc16): pure std-cell (no
  SRAM macros at tile scale) + big die + very low PL_TARGET_DENSITY (max spread) + full met1 +
  GRT_ALLOW_CONGESTION 1 + skip both GLB_RESIZER_*_OPTIMIZATIONS + ROUTING_CORES 4.
- **GLB_RESIZER loops forever** on congested designs: set GLB_RESIZER_DESIGN_OPTIMIZATIONS 0 +
  GLB_RESIZER_TIMING_OPTIMIZATIONS 0 → run_routing goes straight to a single bounded global_routing
  → TritonRoute. Timing is already met at CTS for these.
- **nwell.4 DRC** (~9.3–9.5k on Rocket, 1 on tensor): decap-fill wells without a metal-connected tap;
  INVARIANT to density/tap-distance; LVS-clean. Documented benign WAIVER (needs a fill-strategy ECO
  or commercial tooling to zero — not worth reflow time here).
- **OL1 safe-resume** (avoid `prep -overwrite` deleting a run): interactive driver that preps a NEW
  tag and sets CURRENT_DEF/ODB/SDC/NETLIST to a prior checkpoint, then calls the run_* step procs.
- **QUIT_ON_SYNTH_CHECKS 0 / QUIT_ON_UNMAPPED_CELLS 0** for Rocket (benign undriven gpa[] bits).
- **Magic antenna_check + save_final_views can HANG ~2 h** AFTER results (GDS/DRC/LVS) are written —
  capture results, then kill the container.

---

## 5. CVA6 → Rocket pivot (why)
Full RV64GC CVA6 OOMs Yosys via sv2v (435 MB bloat) and Surelog SIGSEGVs in Synlig. Rocket's
firtool-lowered Verilog reads cleanly through sv2v→Yosys. Then RV64GC→RV64IMAC (drop FPU, kills the
-14 ns FPU critical path) + 33 MHz CPU domain (clears the ~25 ns single-cycle integer divider path).

## 6. CHIP SoC INTEGRATION — Rocket master path through the real fabric (2026-06-23)
Full-chip boot sim (aurora_soc_top_chip: behavioral 2-port Rocket + tensor RTL + REAL
crossbar/CDC/wrapper/sram/peripherals). The Rocket AXI master path had NEVER been simulated through
the real fabric (flat sim = CVA6 direct, no CDC; iso sim = direct BFM). Three bugs, all in chip-level
std-cell GLUE (not in the hardened macros), surfaced in order. Build: sim/build_chip.sh (needs
-fno-gate: Verilator V3Gate ICE on async_fifo in the full design — tool bug, lints clean standalone).

### 6a. rocket_axi_wrapper — single lane/id latch breaks with >1 outstanding (store-access-fault)
SYMPTOM: Rocket boots, fetches @0x80000000 OK, then store-access-fault (cause=7) on the FIRST mmio
store; reads showed wrong/duplicated R data (rom[1]HIGH where rom[1]LOW expected). DIAGNOSIS: the
wrapper latched ONE {lane=addr[3], id} to half-select the 64<->128 bus and reflect the id (crossbar
drops IDs). The downstream axi_cdc_bridge's depth-16 async FIFOs let the macro pipeline many AR/AW, so
the single latch got overwritten -> wrong lane/id on returning R -> corrupted cache fill -> fault.
WRONG FIRST FIX: gate AR/AW ready to 1-outstanding -> DEADLOCK: gating AW on B-completion desyncs
Rocket TLToAXI4's independent AW/W channels and it withholds a W. FIX: per-transaction lane/id FIFOs
(depth 32 > max in-flight = CDC depth 16 + 1), NO backpressure to the macro. WHY: the fabric returns
in-order, so a FIFO head always matches the current R/B.

### 6b. axi_cdc_bridge — separate AW & W FIFOs let W race ahead of AW (write deadlock)
SYMPTOM: after 6a, hang on the first dcache line-writeback; counts showed 8 W reached the crossbar vs
only 5 AW. DIAGNOSIS: AW and W crossed in INDEPENDENT async FIFOs draining at different rates -> W got
ahead of its AW -> crossbar/slave AW/W correlation broke. FIX: ONE combined write-request FIFO —
gather AW+W on the CPU side into a single entry, present both from one entry on the fabric side, pop
when BOTH accepted. WHY: keeps AW and W atomic across the crossing, which the crossbar (formally
verified) and single-beat slaves assume.

### 6c. sram_bank_array — unconditional awready/wready collapses back-to-back writes (THE root deadlock)
SYMPTOM: even after 6a/6b, hang at the next load after a writeback; SRAM produced 1 B for many writes.
DIAGNOSIS: awready=wready=1'b1 always, and bvalid set on (awvalid&&wvalid). On a rapid 8-beat
writeback the crossbar forwards a W while still grant-locked on the prior write; the SRAM's wready=1
consumes that W with NO matching AW (lost), and multiple writes collapse into one B -> the crossbar's
per-slave write grant never releases -> deadlock. CVA6's slow one-at-a-time writes never exposed it.
FIX: proper single-outstanding handshake: wr_accept = awvalid && wvalid && !bvalid; awready = wready =
wr_accept; exactly one B per accepted write (held to bready). WHY: AW and W must be consumed together
for single-beat writes, and one slave can hold only one in-flight write at a time.

LESSON: a slave that ties *ready high and pulses bvalid on (awvalid&&wvalid) "works" only when the
master sends one write at a time with B consumed before the next. Any back-to-back / pipelined writer
(a dcache writeback) needs a real single-outstanding handshake. Check UART/GPIO/timer if ever driven
back-to-back (boot paces them via TX-full polling, so they're not yet exposed).
