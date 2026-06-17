# Routing retry: global route crashed in FastRoute overflow-removal (congestion).
# Give the router more resources + allow residual congestion so it cannot enter
# the buggy "hard benchmark" overflow path. Same RAM discipline as before.
package require openlane

set R /home/yashwanth/aurora_v1/openlane/aurora_soc/runs/resume_cts

prep -design /home/yashwanth/aurora_v1/openlane/aurora_soc -tag resume_route2 -overwrite

set ::env(CURRENT_DEF)             $R/tmp/cts/1-aurora_soc_top.resized.def
set ::env(CURRENT_ODB)             $R/tmp/cts/1-aurora_soc_top.resized.odb
set ::env(CURRENT_SDC)             $R/tmp/cts/1-aurora_soc_top.resized.sdc
set ::env(CURRENT_NETLIST)         $R/tmp/cts/1-aurora_soc_top.resized.nl.v
set ::env(CURRENT_POWERED_NETLIST) $R/tmp/cts/1-aurora_soc_top.resized.pnl.v

# RAM safety
set ::env(RSZ_MULTICORNER_LIB) 0
set ::env(ROUTING_CORES) 8

# Congestion relief: more routing tracks (lower reserve) + tolerate residual
# overflow instead of the FastRoute overflow-removal path that segfaulted.
set ::env(GRT_ADJUSTMENT) 0.15
set ::env(GRT_ALLOW_CONGESTION) 1

run_routing

puts "=== RESUME_ROUTE2_DONE ==="
exit 0
