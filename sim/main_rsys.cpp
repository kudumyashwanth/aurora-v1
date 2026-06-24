#include "Vtb_rocketsys_iso.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

vluint64_t main_time = 0;

double sc_time_stamp() {
    return (double)main_time;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vtb_rocketsys_iso* top = new Vtb_rocketsys_iso;

    // Waveform tracing is opt-in (+trace): 8M cycles of full-SoC VCD is
    // multiple GB, so only pay for it when debugging.
    VerilatedVcdC* tfp = nullptr;
    if (Verilated::commandArgsPlusMatch("trace")[0]) {
        Verilated::traceEverOn(true);
        tfp = new VerilatedVcdC;
        top->trace(tfp, 99);
        tfp->open("aurora_wave.vcd");
        printf("Tracing enabled -> aurora_wave.vcd\n");
    }

    // Simulation length: 80M time units = 8M cycles @ 10 units/cycle.
    // Long enough for the boot banner + matrix init + tensor run over
    // 115200-baud UART (~17k cycles per character).
    vluint64_t max_time = 80000000;
    const char* arg = Verilated::commandArgsPlusMatch("cycles=");
    if (arg && arg[0])
        max_time = 10ull * strtoull(arg + 8, nullptr, 10);

    printf("========================================\n");
    printf("    AURORA v1 SoC SIMULATION\n");
    printf("========================================\n");

    top->clk   = 0;
    top->rst_n = 0;

    while (main_time < max_time) {

        if ((main_time % 5) == 0)
            top->clk = !top->clk;

        if (main_time == 10000) {   // long reset for subsystem (debug + clock domains)
            top->rst_n = 1;
            printf("[t=%lu] Reset released\n", (unsigned long)main_time);
        }

        top->eval();
        if (tfp) tfp->dump(main_time);
        main_time++;
    }

    top->eval();
    if (tfp) tfp->dump(main_time);

    printf("\n========================================\n");
    printf("  SIMULATION COMPLETE @ t=%lu\n", (unsigned long)main_time);
    printf("========================================\n");

    if (tfp) {
        tfp->close();
        delete tfp;
    }
    delete top;

    return 0;
}
