# Resume driver: routing (global resizers -> global route -> fill -> detailed route)
# Starts from the resized post-CTS checkpoint in resume_cts. RAM-disciplined:
#   RSZ_MULTICORNER_LIB 0 -> single-corner routing resizers (avoids >18 GB blow-up)
#   ROUTING_CORES 8       -> bounds TritonRoute peak memory while staying parallel
package require openlane

set R /home/yashwanth/aurora_v1/openlane/aurora_soc/runs/resume_cts

prep -design /home/yashwanth/aurora_v1/openlane/aurora_soc -tag resume_route -overwrite

# Start from the resized post-CTS output (setup already closed to +5.02 ns).
set ::env(CURRENT_DEF)             $R/tmp/cts/1-aurora_soc_top.resized.def
set ::env(CURRENT_ODB)             $R/tmp/cts/1-aurora_soc_top.resized.odb
set ::env(CURRENT_SDC)             $R/tmp/cts/1-aurora_soc_top.resized.sdc
set ::env(CURRENT_NETLIST)         $R/tmp/cts/1-aurora_soc_top.resized.nl.v
set ::env(CURRENT_POWERED_NETLIST) $R/tmp/cts/1-aurora_soc_top.resized.pnl.v

# RAM safety net (see header).
set ::env(RSZ_MULTICORNER_LIB) 0
set ::env(ROUTING_CORES) 8

run_routing

puts "=== RESUME_ROUTE_DONE ==="
exit 0
