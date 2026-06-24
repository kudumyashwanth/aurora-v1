create_clock [get_ports clock] -name core_clock -period 30.000
set_clock_uncertainty 0.25 [get_clocks core_clock]
set_clock_transition 0.15 [get_clocks core_clock]
set_propagated_clock [all_clocks]
