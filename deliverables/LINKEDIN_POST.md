# LinkedIn post — Aurora v1

> Copy-paste the text below. Attach the 4 images in this order:
> 1. `assets/chip_floorplan.png`  (hero — the layout)
> 2. `assets/results_dashboard.png`
> 3. `assets/architecture.png`
> 4. `assets/boot_terminal.png`

---

I took an AI chip from RTL all the way to a signed-off GDSII layout — on a single 23 GB laptop, using only open-source tools. 🚀

Meet **Aurora v1**: a RISC-V + tensor-accelerator System-on-Chip on the SkyWater Sky130 process.

What's inside:
🔹 A **Rocket RV64IMAC** CPU core (hardened as a macro)
🔹 A **4×4 systolic tensor engine** for matrix multiply
🔹 An **8×8 AXI4 crossbar** fabric with clock-domain crossing
🔹 UART, GPIO, timer, boot ROM, SRAM — a real, multi-clock SoC

And it went through the *entire* physical-design flow:
RTL → lint → simulation → formal → synthesis → floorplan → placement → clock-tree → routing → timing → DRC → LVS → **GDSII**.

The sign-off numbers I'm proud of:
✅ **Timing MET** — at all three process corners (slow/typical/fast)
✅ **DRC = 1** (a single fill waiver)
✅ **LVS device-match** — 137,562 = 137,562 devices
✅ A full **41.25 mm²** chip, ~1.97 M instances, streamed to GDSII

The honest part — because credibility matters: the two remaining sign-off items are documented waivers (a fill tap and an unused-signal extraction convention), exactly the kind real tape-outs ship with. Not defects.

What made it hard wasn't writing the RTL — it was the *physical* battles: a metal-1 routing-congestion wall on the systolic array, hardening a TileLink RISC-V tile into a clean AXI macro, a full-chip power-grid fragmentation that blocked LVS, and doing all of it inside an 18 GB memory cap so the laptop wouldn't die mid-run. Each one was a root-cause-and-fix grind.

The whole thing is open and documented — RTL, the winning physical-design recipe, the full engineering log, and a datasheet:
🔗 github.com/kudumyashwanth/aurora-v1

If you're into open-source silicon, RISC-V, or AI accelerators, I'd love to hear your thoughts. And the IP is available for licensing if anyone's building in this space.

#chipdesign #semiconductors #riscv #vlsi #ai #opensourcesilicon #asic #engineering #sky130 #aihardware #technology #hardwareengineering

---

## Hashtag strategy (LinkedIn — quality over quantity)

LinkedIn favors ~5–12 tags mixing broad reach + niche relevance. Use the set above in the post body,
then drop these extra niche tags in your FIRST COMMENT (keeps the post clean, still indexes):

    #openlane #openroad #tinytapeout #rtltogdsii #tensoraccelerator #computerarchitecture #icdesign

Tactics:
- Lead with the floorplan image (visual posts ≈ 2× reach).
- Mention communities in the text to escape your network: OpenROAD · RISC-V International · Efabless.
- Reply fast to early comments — engagement velocity in the first ~2 hours drives the algorithm.

### Full bank to rotate from
Broad:   #technology #engineering #innovation #artificialintelligence #electronics #stem #hardware
Domain:  #soc #semiconductor #microelectronics #physicaldesign #digitaldesign #eda #fpga
Open Si: #chipsalliance #siliconengineering #semiconductordesign
AI HW:   #aichips #edgeai #mlhardware #accelerators
Career:  #embeddedsystems #engineeringportfolio
