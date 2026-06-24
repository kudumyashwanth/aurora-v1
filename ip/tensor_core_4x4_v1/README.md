# Aurora Tensor Core IP v1 (4×4, Sky130B)

Signed-off systolic matrix-multiply accelerator macro. **See `docs/DATASHEET.md`** for
full specs, interface, and signoff results.

**Status:** route 0 · LVS clean · antenna 0 · setup+hold timing MET (all corners) ·
GDS delivered · 1 waivable nwell-tap DRC artifact.

**Headline:** 16 MAC/cycle (int16), 50 MHz, 3.24 mm², pure standard-cell, parametric
(`SIZE`/`DATA_WIDTH`), tileable. Produced entirely with free tools (OpenLane/Sky130B).

| Dir | Contents |
|---|---|
| `gds/` | final layout (GDSII) |
| `lef/` `lib/` | abstract + Liberty timing (nom + 3 corners) — for integration |
| `verilog/` | RTL source + LVS-clean gate netlist |
| `sdc/` `spef/` `sdf/` `spice/` | constraints, parasitics, delays, LVS spice |
| `docs/` | datasheet + exact build driver |
