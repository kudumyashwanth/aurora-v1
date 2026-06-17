// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vcfg_print.h for the primary calling header

#ifndef VERILATED_VCFG_PRINT___024ROOT_H_
#define VERILATED_VCFG_PRINT___024ROOT_H_  // guard

#include "verilated.h"


class Vcfg_print__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vcfg_print___024root final {
  public:

    // INTERNAL VARIABLES
    Vcfg_print__Syms* vlSymsp;
    const char* vlNamep;

    // CONSTRUCTORS
    Vcfg_print___024root(Vcfg_print__Syms* symsp, const char* namep);
    ~Vcfg_print___024root();
    VL_UNCOPYABLE(Vcfg_print___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
