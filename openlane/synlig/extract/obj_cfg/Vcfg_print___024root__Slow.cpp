// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vcfg_print.h for the primary calling header

#include "Vcfg_print__pch.h"

void Vcfg_print___024root___ctor_var_reset(Vcfg_print___024root* vlSelf);

Vcfg_print___024root::Vcfg_print___024root(Vcfg_print__Syms* symsp, const char* namep)
 {
    vlSymsp = symsp;
    vlNamep = strdup(namep);
    // Reset structure values
    Vcfg_print___024root___ctor_var_reset(this);
}

void Vcfg_print___024root::__Vconfigure(bool first) {
    (void)first;  // Prevent unused variable warning
}

Vcfg_print___024root::~Vcfg_print___024root() {
    VL_DO_DANGLING(std::free(const_cast<char*>(vlNamep)), vlNamep);
}
