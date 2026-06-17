# Resume driver: re-run the interrupted post-CTS timing resizer (run1 "step 14")
# Reads run1's post-CTS checkpoint READ-ONLY; writes into a fresh tag "resume_cts".
package require openlane

set R /home/yashwanth/aurora_v1/openlane/aurora_soc/runs/run1

# Fresh run dir; -overwrite is harmless because the tag does not exist yet.
prep -design /home/yashwanth/aurora_v1/openlane/aurora_soc -tag resume_cts -overwrite

# Feed the post-CTS checkpoint produced by run1 (clock tree already built).
set ::env(CURRENT_DEF)     $R/results/cts/aurora_soc_top.def
set ::env(CURRENT_ODB)     $R/results/cts/aurora_soc_top.odb
set ::env(CURRENT_SDC)     $R/results/cts/aurora_soc_top.sdc
set ::env(CURRENT_NETLIST) $R/results/placement/aurora_soc_top.nl.v

# RAM FIX: single-corner (typical) resizer. The 3-corner repair_timing needs
# >18 GB on 332k cells and thrashed/froze. Typical-corner setup repair still
# closes the -1.59 ns WNS; multi-corner is re-verified at signoff STA.
set ::env(RSZ_MULTICORNER_LIB) 0

# The step that was killed by the freeze: post-CTS placement timing resizer.
run_resizer_timing

# Authoritative multi-corner STA to confirm WNS/TNS close before routing.
run_sta -multi_corner -log $::env(LOGS_DIR)/cts/resume_resizer_sta.log

puts "=== RESUME_CTS_DONE ==="
exit 0
